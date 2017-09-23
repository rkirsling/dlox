import 'dart:collection';
import 'dart:io';

import 'package:yaml/yaml.dart';

void main() {
  final input = _getFile('../lib/src/ast.yaml').readAsStringSync();
  final output = _generateAstModel(loadYaml(input) as Map<String, Map>);
  _getFile('../lib/src/ast.dart').writeAsStringSync(output);
}

File _getFile(String path) => new File.fromUri(Platform.script.resolve(path));

String _generateAstModel(Map<String, Map> inputMap) {
  final preamble = new StringBuffer()
    ..writeln('// DO NOT EDIT -- This file is generated from ast.yaml.')
    ..writeln('import \'token.dart\';');

  final visitor = new StringBuffer()
    ..writeln()
    ..writeln('abstract class AstVisitor<R> {');

  final nodes = new StringBuffer()
    ..writeln()
    ..writeln('abstract class AstNode {')
    ..writeln('  R accept<R>(AstVisitor<R> visitor);')
    ..writeln('}');

  inputMap.forEach((baseName, classes) {
    nodes
      ..writeln()
      ..writeln('abstract class $baseName extends AstNode {}');

    // Sort class names.
    new SplayTreeMap<String, List<String>>.from(classes).forEach((className, fields) {
      visitor.writeln('  R visit$className($className node);');

      nodes
        ..writeln()
        ..writeln('class $className extends $baseName {');

      if (fields.isNotEmpty) {
        for (final field in fields) nodes.writeln('  final $field;');

        final parameterList = fields.map((field) => 'this.' + field.split(' ')[1]).join(', ');
        nodes
          ..writeln()
          ..writeln('  $className($parameterList);')
          ..writeln();
      }

      nodes
        ..writeln('  @override')
        ..writeln('  R accept<R>(AstVisitor<R> visitor) => visitor.visit$className(this);')
        ..writeln('}');
    });
  });

  visitor.writeln('}');

  return '$preamble$visitor$nodes';
}

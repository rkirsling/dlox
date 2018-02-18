import 'dart:io';

import 'package:dlox/src/error_reporter.dart';
import 'package:dlox/src/interpreter.dart';
import 'package:dlox/src/parser.dart';
import 'package:dlox/src/resolver.dart';
import 'package:dlox/src/scanner.dart';

const _successCode = 0;
const _staticErrorCode = 65;
const _dynamicErrorCode = 70;

final _errorReporter = new ErrorReporter(stderr.writeln);
final _resolver = new Resolver(_errorReporter);
final _interpreter = new Interpreter(stdout.writeln, _errorReporter);

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln('Usage: dlox [<path>]');
  } else if (args.length == 1) {
    _runFile(args[0]);
  } else {
    _runPrompt();
  }
}

void _runFile(String path) {
  try {
    exitCode = _run(new File(path).readAsStringSync());
    if (exitCode == _staticErrorCode) _errorReporter.displayErrorCount();
  } on FileSystemException {
    stderr.writeln('Could not open file: $path');
  }
}

void _runPrompt() {
  stdout
    ..writeln('This is a minimal Lox REPL for debug use.')
    ..writeln('* Statements may not include line breaks.')
    ..writeln('* Standalone expressions are not allowed.')
    ..writeln();

  for (var line = 1; ; line++) {
    stdout.write('dlox:$line> ');

    _resolver.saveGlobals();
    final code = _run(stdin.readLineSync(), line);
    if (code != _successCode) _resolver.restoreGlobals();

    _errorReporter.reset();
  }
}

int _run(String source, [int line = 1]) {
  final tokens = new Scanner(source, _errorReporter, line).scanTokens();
  final statements = new Parser(tokens, _errorReporter).parse();
  if (_errorReporter.errorCount > 0) return _staticErrorCode;

  _resolver.resolve(statements);
  if (_errorReporter.errorCount > 0) return _staticErrorCode;

  _interpreter.interpret(statements);
  return _errorReporter.errorCount > 0 ? _dynamicErrorCode : _successCode;
}

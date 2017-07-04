import 'dart:io';

import 'package:dlox/src/error_reporter.dart';
import 'package:dlox/src/interpreter.dart';
import 'package:dlox/src/parser.dart';
import 'package:dlox/src/scanner.dart';

final _errorReporter = new ErrorReporter(stderr.writeln);
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
  } on FileSystemException {
    stderr.writeln('Could not open file: $path');
  }
}

void _runPrompt() {
  for (;;) {
    stdout.write('dlox> ');
    _run(stdin.readLineSync());
    _errorReporter.reset();
  }
}

int _run(String source) {
  final tokens = new Scanner(source, _errorReporter).scanTokens();
  final statements = new Parser(tokens, _errorReporter).parse();
  if (_errorReporter.hadError) return 65;

  _interpreter.interpret(statements);
  return _errorReporter.hadError ? 70 : 0;
}

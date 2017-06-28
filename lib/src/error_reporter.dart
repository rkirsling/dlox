import 'dart:io';

import 'token.dart';

class LoxError implements Exception {
  final Token token;
  final String message;

  LoxError(this.token, this.message);
}

class ErrorReporter {
  static const _redText = '\u{1B}[31m';
  static const _greyText = '\u{1B}[90m';
  static const _resetText = '\u{1B}[0m';

  bool hadStaticError = false;
  bool hadDynamicError = false;

  ErrorReporter();

  void report(LoxError error, {bool isDynamic = false}) {
    if (isDynamic) {
      reportDynamic(error.token.line, error.token.column, error.message);
    } else {
      reportStatic(error.token.line, error.token.column, error.message);
    }
  }

  void reportStatic(int line, int column, String message) {
    stderr.writeln('$_redText  syntax error$_resetText : $message $_greyText($line:$column)$_resetText');
    hadStaticError = true;
  }

  void reportDynamic(int line, int column, String message) {
    stderr.writeln('$_redText runtime error$_resetText : $message $_greyText($line:$column)$_resetText');
    hadDynamicError = true;
  }
}

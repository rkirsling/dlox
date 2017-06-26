import 'dart:io';

class ErrorReporter {
  static const _redText = '\u{1B}[31m';
  static const _greyText = '\u{1B}[90m';
  static const _resetText = '\u{1B}[0m';

  bool hadStaticError = false;
  bool hadDynamicError = false;

  ErrorReporter();

  void reportStatic(int line, int column, String message) {
    stderr.writeln(' $_redText error $_resetText $message $_greyText($line:$column)$_resetText');
    hadStaticError = true;
  }

  void reportDynamic(int line, int column, String message) {
    stderr.writeln(' $_redText error $_resetText $message $_greyText($line:$column)$_resetText');
    hadDynamicError = true;
  }
}

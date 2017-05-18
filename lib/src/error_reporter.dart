import 'dart:io';

class ErrorReporter {
  static final _redText = '\u{1B}[31m';
  static final _greyText = '\u{1B}[90m';
  static final _resetText = '\u{1B}[0m';

  bool hadError = false;

  ErrorReporter();

  void report(int line, int column, String message) {
    stderr.writeln(' $_redText error $_resetText $message $_greyText($line:$column)$_resetText');
    hadError = true;
  }
}

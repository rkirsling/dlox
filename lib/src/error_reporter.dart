import 'token.dart';

const _redText = '\u{1B}[31m';
const _greyText = '\u{1B}[90m';
const _resetText = '\u{1B}[0m';

class LoxError implements Exception {
  final Token token;
  final String message;

  LoxError(this.token, this.message);
}

class ErrorReporter {
  final void Function(String) _print;
  int _errorCount = 0;

  ErrorReporter(this._print);

  int get errorCount => _errorCount;

  void report(LoxError error, {bool isDynamic = false}) {
    reportAtPosition(error.token.line, error.token.column, error.message, isDynamic: isDynamic);
  }

  void reportAtPosition(int line, int column, String message, {bool isDynamic = false}) {
    final stage = (isDynamic ? 'runtime' : 'syntax').padLeft(8);
    _print('$_redText$stage error $_resetText $message $_greyText($line:$column)$_resetText');
    _errorCount++;
  }

  void displayErrorCount() {
    final suffix = _errorCount == 1 ? '' : 's';
    _print('$_errorCount error$suffix identified.');
  }

  void reset() {
    _errorCount = 0;
  }
}

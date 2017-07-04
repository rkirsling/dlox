import 'token.dart';

const _redText = '\u{1B}[31m';
const _greyText = '\u{1B}[90m';
const _resetText = '\u{1B}[0m';

typedef void PrintFunction(String string);

class LoxError implements Exception {
  final Token token;
  final String message;

  LoxError(this.token, this.message);
}

class ErrorReporter {
  final PrintFunction _print;
  bool _hadError = false;

  ErrorReporter(this._print);

  bool get hadError => _hadError;

  void report(LoxError error, {bool isDynamic = false}) {
    reportAtPosition(error.token.line, error.token.column, error.message, isDynamic: isDynamic);
  }

  void reportAtPosition(int line, int column, String message, {bool isDynamic = false}) {
    final stage = isDynamic ? 'runtime' : ' syntax';
    _print('$_redText $stage error $_resetText: $message $_greyText($line:$column)$_resetText');
    _hadError = true;
  }

  void reset() {
    _hadError = false;
  }
}

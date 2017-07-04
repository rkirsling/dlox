import 'error_reporter.dart';
import 'token.dart';

class Environment {
  final Map<String, Object> _values = {};

  Environment();

  void define(Token identifier, Object value) {
    final name = identifier.lexeme;
    if (_values.containsKey(name)) throw new LoxError(identifier, 'Identifier \'$name\' is already defined.');

    _values[name] = value;
  }

  Object operator [](Token identifier) {
    final name = identifier.lexeme;
    if (!_values.containsKey(name)) throw new LoxError(identifier, 'Identifier \'$name\' is undefined.');

    return _values[name];
  }
}

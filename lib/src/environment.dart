import 'error_reporter.dart';
import 'token.dart';

class Environment {
  final List<Map<String, Object>> _scopeStack = [{}];

  void push() {
    _scopeStack.add({});
  }

  void pop() {
    if (_scopeStack.length <= 1) throw new RangeError('Cannot pop from global scope.');

    _scopeStack.removeLast();
  }

  void define(Token identifier, Object value) {
    final name = identifier.lexeme;

    if (_scopeStack.last.containsKey(name)) {
      throw new LoxError(identifier, 'Identifier \'$name\' is already defined.');
    }

    _scopeStack.last[name] = value;
  }

  void operator []=(Token identifier, Object value) {
    final name = identifier.lexeme;

    for (final scope in _scopeStack.reversed) {
      if (scope.containsKey(name)) {
        scope[name] = value;
        return;
      }
    }

    throw new LoxError(identifier, 'Identifier \'$name\' is undefined.');
  }

  Object operator [](Token identifier) {
    final name = identifier.lexeme;

    for (final scope in _scopeStack.reversed) {
      if (scope.containsKey(name)) return scope[name];
    }

    throw new LoxError(identifier, 'Identifier \'$name\' is undefined.');
  }
}

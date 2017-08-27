import 'error_reporter.dart';
import 'token.dart';

class Environment {
  final Environment _parent;
  final Map<String, Object> _scope;

  Environment.root(this._scope) : _parent = null;

  Environment.child(this._parent) : _scope = {};

  void define(Token identifier, Object value) {
    final name = identifier.lexeme;

    if (_scope.containsKey(name)) {
      throw new LoxError(identifier, 'Identifier \'$name\' is already defined.');
    }

    _scope[name] = value;
  }

  void operator []=(Token identifier, Object value) {
    final name = identifier.lexeme;

    if (_scope.containsKey(name)) {
      _scope[name] = value;
    } else if (_parent != null) {
      _parent[identifier] = value;
    } else {
      throw new LoxError(identifier, 'Identifier \'$name\' is undefined.');
    }
  }

  Object operator [](Token identifier) {
    final name = identifier.lexeme;

    if (_scope.containsKey(name)) return _scope[name];

    if (_parent != null) return _parent[identifier];

    throw new LoxError(identifier, 'Identifier \'$name\' is undefined.');
  }
}

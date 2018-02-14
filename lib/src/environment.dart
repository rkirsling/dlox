import 'error_reporter.dart';
import 'token.dart';

class Environment {
  final Environment _parent;
  final Map<String, Object> _scope;

  Environment.root(this._scope) : _parent = null;

  Environment.child(this._parent) : _scope = {};

  Environment ancestor(int depth) {
    var environment = this;

    for (var i = 0; i < depth; i++) {
      assert(environment._parent != null);
      environment = environment._parent;
    }

    return environment;
  }

  void define(String name, [Object value]) {
    assert(!_scope.containsKey(name));
    _scope[name] = value;
  }

  void operator []=(Token identifier, Object value) {
    final name = identifier.lexeme;
    if (!_scope.containsKey(name)) throw new LoxError(identifier, 'Identifier \'$name\' is undefined.');

    _scope[name] = value;
  }

  Object operator [](Token identifier) {
    final name = identifier.lexeme;
    if (!_scope.containsKey(name)) throw new LoxError(identifier, 'Identifier \'$name\' is undefined.');

    return _scope[name];
  }
}

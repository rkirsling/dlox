import 'ast.dart';
import 'environment.dart';
import 'error_reporter.dart';
import 'token.dart';

const Token $this = const Token(TokenType.$this, 'this', null, null);

typedef InterpretFunction = void Function(List<Statement>, Environment);

class Return implements Exception {
  final Object value;

  Return(this.value);
}

abstract class Callable {
  int get arity;

  Object call(InterpretFunction interpret, List arguments);
}

class LoxFunction implements Callable {
  final FunctionStatement _declaration;
  final Environment _closure;

  LoxFunction(this._declaration, this._closure);

  @override
  int get arity => _declaration.parameters.length;

  @override
  Object call(InterpretFunction interpret, List arguments) {
    final environment = new Environment.child(_closure);
    for (var i = 0; i < arity; i++) environment.define(_declaration.parameters[i], arguments[i]);

    try {
      interpret(_declaration.statements, environment);
    } on Return catch (returned) {
      return returned.value;
    }

    return null;
  }

  LoxFunction bind(LoxInstance context) {
    final environment = new Environment.child(_closure)..define($this, context);
    return new LoxFunction(_declaration, environment);
  }

  @override
  String toString() => '<function ${_declaration.identifier.lexeme}>';
}

class LoxClass implements Callable {
  final String name;
  final Map<String, LoxFunction> _methods;

  LoxClass(this.name, this._methods);

  @override
  int get arity => _methods['init']?.arity ?? 0;

  @override
  Object call(InterpretFunction interpret, List arguments) {
    final instance = new LoxInstance(this);

    final initializer = _methods['init']?.bind(instance);
    if (initializer != null) initializer.call(interpret, arguments);

    return instance;
  }

  LoxFunction findMethod(LoxInstance instance, String name) => _methods[name]?.bind(instance);

  @override
  String toString() => '<class $name>';
}

class LoxInstance {
  final LoxClass _class;
  final Map<String, Object> _fields = {};

  LoxInstance(this._class);

  void operator []=(Token identifier, Object value) {
    final name = identifier.lexeme;
    if (name == 'init') throw new LoxError(identifier, 'Cannot overwrite class initializer.');

    _fields[name] = value;
  }

  Object operator [](Token identifier) {
    final name = identifier.lexeme;
    if (name == 'init') throw new LoxError(identifier, 'Cannot access class initializer.');

    final value = _fields[name] ?? _class.findMethod(this, name);
    if (value == null) throw new LoxError(identifier, 'Property \'$name\' is undefined.');

    return value;
  }

  @override
  String toString() => '<instance of ${_class.name}>';
}

import 'ast.dart';
import 'environment.dart';
import 'error_reporter.dart';
import 'token.dart';

const Token $this = Token(TokenType.$this, 'this', null, null);
const Token $super = Token(TokenType.$super, 'super', null, null);

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
  final LoxClass _class;

  LoxFunction(this._declaration, this._closure, [this._class]);

  @override
  int get arity => _declaration.parameters.length;

  @override
  Object call(InterpretFunction interpret, List arguments) {
    final environment = Environment.child(_closure);
    for (var i = 0; i < arity; i++) environment.define(_declaration.parameters[i], arguments[i]);

    try {
      interpret(_declaration.statements, environment);
    } on Return catch (returned) {
      return returned.value;
    }

    return null;
  }

  LoxFunction bind(LoxInstance context) {
    assert(_class != null);

    final environment = Environment.child(_closure)..define($this, context);
    if (_class.superclass != null) environment.define($super, _class.superclass);

    return LoxFunction(_declaration, environment);
  }

  @override
  String toString() => '<function ${_declaration.identifier.lexeme}>';
}

class LoxClass implements Callable {
  final String name;
  final LoxClass superclass;
  final Map<String, LoxFunction> _methods = {};

  LoxClass(this.name, this.superclass, List<FunctionStatement> methods, Environment environment) {
    for (final method in methods) _methods[method.identifier.lexeme] = LoxFunction(method, environment, this);
  }

  @override
  int get arity => _methods['init']?.arity ?? 0;

  @override
  Object call(InterpretFunction interpret, List arguments) {
    final instance = LoxInstance(this);

    final initializer = _methods['init']?.bind(instance);
    if (initializer != null) initializer.call(interpret, arguments);

    return instance;
  }

  LoxFunction findMethod(LoxInstance context, String name) =>
    _methods[name]?.bind(context) ?? superclass?.findMethod(context, name);

  @override
  String toString() => '<class $name>';
}

class LoxInstance {
  final LoxClass _class;
  final Map<String, Object> _fields = {};

  LoxInstance(this._class);

  void operator []=(Token identifier, Object value) {
    final name = identifier.lexeme;
    if (name == 'init') throw LoxError(identifier, 'Cannot overwrite class initializer.');

    _fields[name] = value;
  }

  Object operator [](Token identifier) {
    final name = identifier.lexeme;
    if (name == 'init') throw LoxError(identifier, 'Cannot access class initializer.');

    final value = _fields[name] ?? _class.findMethod(this, name);
    if (value == null) throw LoxError(identifier, 'Property \'$name\' is undefined.');

    return value;
  }

  LoxFunction getSuperMethod(Token identifier) {
    final name = identifier.lexeme;
    assert(_class.superclass != null);

    final method = _class.superclass.findMethod(this, name);
    if (method == null) throw LoxError(identifier, 'Superclass has no method \'$name\'.');

    return method;
  }

  @override
  String toString() => '<instance of ${_class.name}>';
}

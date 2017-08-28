import 'ast.dart';
import 'environment.dart';

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

  @override
  String toString() => '<function ${_declaration.identifier.lexeme}>';
}

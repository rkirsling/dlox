import 'callable.dart';

class _NativeFunction implements Callable {
  final int _arity;
  final Function _function;

  _NativeFunction(this._arity, this._function);

  @override
  int get arity => _arity;

  @override
  Object call(InterpretFunction interpret, List arguments) => Function.apply(_function, arguments);

  @override
  String toString() => '<native function>';
}

final Map<String, Object> prelude = {
  'clock': new _NativeFunction(0, () => new DateTime.now().millisecondsSinceEpoch.toDouble())
};

import 'ast.dart';
import 'callable.dart';
import 'environment.dart';
import 'error_reporter.dart';
import 'prelude.dart';
import 'token.dart';

bool _isTruthy(Object value) => (value is bool) ? value : value != null;

bool _canShortCircuit(TokenType type, Object value) =>
  type == TokenType.$or && _isTruthy(value) ||
  type == TokenType.$and && !_isTruthy(value);

String _stringify(Object value) =>
  (value == null) ? 'nil' :
  (value is double && value.toInt() == value) ? '${value.toInt()}' : '$value';

String _typeOf(Object value) =>
  (value == null) ? 'nil' :
  (value is bool) ? 'boolean' :
  (value is double) ? 'number' :
  (value is String) ? 'string' :
  (value is LoxClass) ? 'class' :
  (value is LoxInstance) ? 'instance' : 'function';

// TODO: Genericize once Dart 2 is available.
double _castDouble(Object value, Token token, String message) =>
  value is double ? value : throw new LoxError(token, message);

String _castString(Object value, Token token, String message) =>
  value is String ? value : throw new LoxError(token, message);

LoxInstance _castLoxInstance(Object value, Token token, String message) =>
  value is LoxInstance ? value : throw new LoxError(token, message);

Callable _castCallable(Object value, Token token, String message) =>
  value is Callable ? value : throw new LoxError(token, message);

class Break implements Exception {}

class Interpreter implements AstVisitor<Object> {
  final void Function(String) _print;
  final ErrorReporter _errorReporter;
  Environment _environment = new Environment.root(prelude);

  Interpreter(this._print, this._errorReporter);

  void interpret(List<Statement> statements) {
    try {
      statements.forEach(_evaluate);
    } on LoxError catch (error) {
      _errorReporter.report(error, isDynamic: true);
    }
  }

  void interpretBlock(List<Statement> statements, Environment environment) {
    final previous = _environment;
    _environment = environment;
    try {
      statements.forEach(_evaluate);
    } finally {
      _environment = previous;
    }
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    _evaluate(node.expression);
  }

  @override
  void visitPrintStatement(PrintStatement node) {
    _print(_stringify(_evaluate(node.expression)));
  }

  @override
  void visitBlockStatement(BlockStatement node) {
    interpretBlock(node.statements, new Environment.child(_environment));
  }

  @override
  void visitIfStatement(IfStatement node) {
    if (_isTruthy(_evaluate(node.condition))) {
      _evaluate(node.consequent);
      return;
    }

    _evaluateOptional(node.alternative);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    while (_isTruthy(_evaluate(node.condition))) {
      try {
        _evaluate(node.body);
      } on Break {
        break;
      }
    }
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    throw new Break();
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    throw new Return(_evaluateOptional(node.expression));
  }

  @override
  void visitVariableStatement(VariableStatement node) {
    _environment.define(node.identifier, _evaluateOptional(node.initializer));
  }

  @override
  void visitFunctionStatement(FunctionStatement node) {
    _environment.define(node.identifier, new LoxFunction(node, _environment));
  }

  @override
  void visitClassStatement(ClassStatement node) {
    _environment.define(node.identifier, null);

    final methods = <String, LoxFunction>{};
    for (final method in node.methods) methods[method.identifier.lexeme] = new LoxFunction(method, _environment);

    _environment[node.identifier] = new LoxClass(node.identifier.lexeme, methods);
  }

  @override
  Object visitLiteralExpression(LiteralExpression node) =>
    node.value;

  @override
  Object visitThisExpression(ThisExpression node) =>
    _environment.ancestor(node.depth)[node.keyword];

  @override
  Object visitIdentifierExpression(IdentifierExpression node) =>
    _environment.ancestor(node.depth)[node.identifier];

  @override
  Object visitParenthesizedExpression(ParenthesizedExpression node) =>
    _evaluate(node.expression);

  @override
  Object visitPropertyExpression(PropertyExpression node) {
    final context = _evaluateToLoxInstance(node.context, node.identifier, (type) => 'Cannot get property of $type.');
    return context[node.identifier];
  }

  @override
  Object visitCallExpression(CallExpression node) {
    final callee = _evaluateToCallable(node.callee, node.parenthesis, (type) => 'Cannot call $type.');
    if (node.arguments.length != callee.arity) {
      throw new LoxError(node.parenthesis, 'Expected ${callee.arity} arguments but found ${node.arguments.length}.');
    }

    final arguments = node.arguments.map(_evaluate).toList();
    return callee.call(interpretBlock, arguments);
  }

  @override
  Object visitUnaryExpression(UnaryExpression node) {
    final operand = _evaluate(node.operand);

    final op = node.operator.lexeme;
    double asNumber(Object value) => _castDouble(value, node.operator, 'Cannot apply \'$op\' to ${_typeOf(value)}.');

    switch (node.operator.type) {
      case TokenType.bang:
        return !_isTruthy(operand);
      case TokenType.minus:
        return -asNumber(operand);
      default:
        assert(false);
        return null;
    }
  }

  @override
  Object visitBinaryExpression(BinaryExpression node) {
    final leftOperand = _evaluate(node.leftOperand);
    if (_canShortCircuit(node.operator.type, leftOperand)) return leftOperand;

    final rightOperand = _evaluate(node.rightOperand);

    final op = node.operator.lexeme;
    double asNumber(Object value) => _castDouble(value, node.operator, 'Cannot apply \'$op\' to ${_typeOf(value)}.');
    String asString(Object value) => _castString(value, node.operator, 'Cannot apply \'$op\' to ${_typeOf(value)}.');

    switch (node.operator.type) {
      case TokenType.$or:
      case TokenType.$and:
        // Since we couldn't short circuit...
        return rightOperand;
      case TokenType.slash:
        if (rightOperand == 0) {
          throw new LoxError(node.operator, 'Cannot divide by zero.');
        }
        return asNumber(leftOperand) / asNumber(rightOperand);
      case TokenType.star:
        return asNumber(leftOperand) * asNumber(rightOperand);
      case TokenType.minus:
        return asNumber(leftOperand) - asNumber(rightOperand);
      case TokenType.plus:
        return (leftOperand is String || rightOperand is String)
          ? _stringify(leftOperand) + _stringify(rightOperand)
          : asNumber(leftOperand) + asNumber(rightOperand);
      case TokenType.greater:
        return (leftOperand is double)
          ? leftOperand > asNumber(rightOperand)
          : asString(leftOperand).compareTo(asString(rightOperand)) > 0;
      case TokenType.greaterEqual:
        return (leftOperand is double)
          ? leftOperand >= asNumber(rightOperand)
          : asString(leftOperand).compareTo(asString(rightOperand)) >= 0;
      case TokenType.less:
        return (leftOperand is double)
          ? leftOperand < asNumber(rightOperand)
          : asString(leftOperand).compareTo(asString(rightOperand)) < 0;
      case TokenType.lessEqual:
        return (leftOperand is double)
          ? leftOperand <= asNumber(rightOperand)
          : asString(leftOperand).compareTo(asString(rightOperand)) <= 0;
      case TokenType.equalEqual:
        return leftOperand == rightOperand;
      case TokenType.bangEqual:
        return leftOperand != rightOperand;
      default:
        assert(false);
        return null;
    }
  }

  @override
  Object visitTernaryExpression(TernaryExpression node) =>
    _isTruthy(_evaluate(node.condition)) ? _evaluate(node.consequent) : _evaluate(node.alternative);

  @override
  Object visitAssignmentExpression(AssignmentExpression node) {
    final rhs = _evaluate(node.rhs);

    final lhs = node.lhs;
    if (lhs is IdentifierExpression) {
      _environment.ancestor(lhs.depth)[lhs.identifier] = rhs;
    } else if (lhs is PropertyExpression) {
      final context = _evaluateToLoxInstance(lhs.context, lhs.identifier, (type) => 'Cannot set property of $type.');
      context[lhs.identifier] = rhs;
    } else {
      assert(false);
    }

    return rhs;
  }

  Object _evaluate(AstNode node) => node.accept(this);

  Object _evaluateOptional(AstNode node) => node == null ? null : _evaluate(node);

  // TODO: Genericize once Dart 2 is available.
  LoxInstance _evaluateToLoxInstance(AstNode node, Token token, String Function(String) typedMessage) {
    final value = _evaluate(node);
    return _castLoxInstance(value, token, typedMessage(_typeOf(value)));
  }

  Callable _evaluateToCallable(AstNode node, Token token, String Function(String) typedMessage) {
    final value = _evaluate(node);
    return _castCallable(value, token, typedMessage(_typeOf(value)));
  }
}

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
  (value is double) ? 'number' : 'string';

double _castNumberOperand(Object value, Token token) {
  if (value is double) return value;

  throw new LoxError(token, 'Expected operand to be a number.');
}

String _castStringOperand(Object value, Token token) {
  if (value is String) return value;

  throw new LoxError(token, 'Expected operand to be a string.');
}

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
    } else if (node.alternative != null) {
      _evaluate(node.alternative);
    }
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
    throw new Return(node.expression == null ? null : _evaluate(node.expression));
  }

  @override
  void visitVariableStatement(VariableStatement node) {
    final value = (node.initializer == null) ? null : _evaluate(node.initializer);
    _environment.define(node.identifier, value);
  }

  @override
  void visitFunctionStatement(FunctionStatement node) {
    final function = new LoxFunction(node, _environment);
    _environment.define(node.identifier, function);
  }

  @override
  Object visitLiteralExpression(LiteralExpression node) =>
    node.value;

  @override
  Object visitIdentifierExpression(IdentifierExpression node) =>
    _environment[node.identifier];

  @override
  Object visitParenthesizedExpression(ParenthesizedExpression node) =>
    _evaluate(node.expression);

  @override
  Object visitCallExpression(CallExpression node) {
    final callee = _evaluate(node.callee);

    if (callee is Callable) {
      if (node.arguments.length != callee.arity) {
        throw new LoxError(node.parenthesis, 'Expected ${callee.arity} arguments but found ${node.arguments.length}.');
      }

      final arguments = node.arguments.map(_evaluate).toList();
      return callee.call(interpretBlock, arguments);
    }

    throw new LoxError(node.parenthesis, 'Cannot call ${_typeOf(callee)} object.');
  }

  @override
  Object visitUnaryExpression(UnaryExpression node) {
    final operand = _evaluate(node.operand);

    double asNumber(Object value) => _castNumberOperand(value, node.operator);

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

    double asNumber(Object value) => _castNumberOperand(value, node.operator);
    String asString(Object value) => _castStringOperand(value, node.operator);

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
    final value = _evaluate(node.rhs);
    _environment[node.identifier] = value;
    return value;
  }

  Object _evaluate(AstNode node) => node.accept(this);
}

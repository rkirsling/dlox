import 'ast.dart';
import 'environment.dart';
import 'error_reporter.dart';
import 'token.dart';

bool _isTruthy(Object value) => (value is bool) ? value : value != null;

bool _canShortCircuit(TokenType type, Object value) =>
  type == TokenType.$or && _isTruthy(value) ||
  type == TokenType.$and && !_isTruthy(value);

String _stringify(Object value) =>
  (value == null) ? 'nil' :
  (value is double && value.toInt() == value) ? '${value.toInt()}' : '$value';

double _castNumberOperand(Object value, Token token) {
  if (value is double) return value;

  throw new LoxError(token, 'Expected operand to be a number.');
}

String _castStringOperand(Object value, Token token) {
  if (value is String) return value;

  throw new LoxError(token, 'Expected operand to be a string.');
}

class Interpreter implements AstVisitor<Object> {
  final PrintFunction _print;
  final ErrorReporter _errorReporter;
  final Environment _environment = new Environment();

  Interpreter(this._print, this._errorReporter);

  void interpret(List<Statement> statements) {
    try {
      statements.forEach(_evaluate);
    } on LoxError catch (error) {
      _errorReporter.report(error, isDynamic: true);
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
  void visitIfStatement(IfStatement node) {
    if (_isTruthy(_evaluate(node.condition))) {
      _evaluate(node.consequent);
    } else if (node.alternative != null) {
      _evaluate(node.alternative);
    }
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    while (_isTruthy(_evaluate(node.condition))) _evaluate(node.body);
  }

  @override
  void visitBlockStatement(BlockStatement node) {
    _environment.push();
    try {
      node.statements.forEach(_evaluate);
    } finally {
      _environment.pop();
    }
  }

  @override
  void visitVarStatement(VarStatement node) {
    final value = (node.initializer == null) ? null : _evaluate(node.initializer);
    _environment.define(node.identifier, value);
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
        return (leftOperand is double)
          ? leftOperand + asNumber(rightOperand)
          : asString(leftOperand) + asString(rightOperand);
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

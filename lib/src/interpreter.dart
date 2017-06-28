import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

bool _isTruthy(Object value) => (value is bool) ? value : value != null;

String _stringify(Object value) =>
  (value == null) ? 'nil' :
  (value is double && value.toInt() == value) ? '${value.toInt()}' : '$value';

double _castNumberOperand(Object value, Token token) {
  if (value is! double) throw new LoxError(token, 'Expected operand to be a number.');

  return value;
}

String _castStringOperand(Object value, Token token) {
  if (value is! String) throw new LoxError(token, 'Expected operand to be a string.');

  return value;
}

class Interpreter implements AstVisitor<Object> {
  final ErrorReporter _errorReporter;

  Interpreter(this._errorReporter);

  String interpret(AstNode node) {
    try {
      return _stringify(_evaluate(node));
    } on LoxError catch (error) {
      _errorReporter.report(error, isDynamic: true);
      return null;
    }
  }

  @override
  Object visitLiteralExpression(LiteralExpression node) =>
    node.value;

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
    final rightOperand = _evaluate(node.rightOperand);

    double asNumber(Object value) => _castNumberOperand(value, node.operator);
    String asString(Object value) => _castStringOperand(value, node.operator);

    switch (node.operator.type) {
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

  Object _evaluate(AstNode node) => node.accept(this);
}

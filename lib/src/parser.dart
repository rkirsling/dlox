import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

bool _hasTypeIn(Token token, List<TokenType> types) => types.contains(token.type);

class Parser {
  final List<Token> _tokens;
  final ErrorReporter _errorReporter;
  int _offset = 0;

  Parser(this._tokens, this._errorReporter);

  Expression parse() => _parseExpression();

  Expression _parseExpression() => _parseTernary();

  Expression _parseTernary() {
    final expression = _parseEquality();
    if (_peek().type != TokenType.question) return expression;

    _advance();
    final consequent = _parseExpression();
    _expect(TokenType.colon, 'Missing colon for ternary operator.');
    final alternative = _parseExpression();
    return new TernaryExpression(expression, consequent, alternative);
  }

  Expression _parseEquality() =>
    _parseBinary(_parseComparison, [TokenType.equalEqual, TokenType.bangEqual]);

  Expression _parseComparison() =>
    _parseBinary(_parseTerm, [TokenType.greater, TokenType.greaterEqual, TokenType.less, TokenType.lessEqual]);

  Expression _parseTerm() =>
    _parseBinary(_parseFactor, [TokenType.minus, TokenType.plus]);

  Expression _parseFactor() =>
    _parseBinary(_parseUnary, [TokenType.star, TokenType.slash]);

  Expression _parseBinary(Expression parseOperand(), List<TokenType> operators) {
    var expression = parseOperand();

    while (_hasTypeIn(_peek(), operators)) {
      final operator = _advance();
      final rightOperand = parseOperand();
      expression = new BinaryExpression(expression, operator, rightOperand);
    }

    return expression;
  }

  Expression _parseUnary() {
    if (!_hasTypeIn(_peek(), [TokenType.bang, TokenType.minus])) return _parsePrimary();

    final operator = _advance();
    final operand = _parseUnary();
    return new UnaryExpression(operator, operand);
  }

  Expression _parsePrimary() {
    final next = _advance();
    switch (next.type) {
      case TokenType.$nil:
        return new LiteralExpression(null);
      case TokenType.$true:
        return new LiteralExpression(true);
      case TokenType.$false:
        return new LiteralExpression(false);
      case TokenType.string:
        return new LiteralExpression(next.lexeme.substring(1, next.lexeme.length - 1));
      case TokenType.number:
        return new LiteralExpression(double.parse(next.lexeme));
      case TokenType.leftParen:
        final expression = _parseExpression();
        _expect(TokenType.rightParen, 'Missing closing parenthesis.');
        return new ParenthesizedExpression(expression);
      case TokenType.eof:
        _error(next, 'Unexpected end of input.');
        break;
      default:
        _error(next, 'Unexpected token \'${next.lexeme}\'.');
        break;
    }

    return null;
  }

  Token _peek() => _tokens[_offset];

  Token _advance() => _tokens[_offset].type != TokenType.eof ? _tokens[_offset++] : _tokens[_offset];

  void _expect(TokenType type, String errorMessage) {
    final token = _advance();
    if (token.type != type) _error(token, errorMessage);
  }

  void _error(Token token, String message) {
    _errorReporter.reportStatic(token.line, token.column, message);
  }
}

import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

class Parser {
  final List<Token> _tokens;
  final ErrorReporter _errorReporter;
  final List<Statement> _statements = [];
  int _index = 0;
  int _loopDepth = 0;

  Parser(this._tokens, this._errorReporter);

  List<Statement> parse() {
    while (!_isAtEnd()) _statements.add(_parseStatement());

    return _statements;
  }

  Statement _parseStatement() {
    try {
      return _advanceIf(TokenType.$var) ? _parseVariable() : _parseNonDeclaration();
    } on LoxError catch (error) {
      _errorReporter.report(error, isDynamic: false);
      _synchronize();
      return null;
    }
  }

  VariableStatement _parseVariable() {
    final identifier = _expect(TokenType.identifier, 'Expected variable name.');
    final initializer = _advanceIf(TokenType.equal) ? _parseExpression() : null;
    _expectSemicolon();
    return new VariableStatement(identifier, initializer);
  }

  Statement _parseNonDeclaration() =>
    _peekIs(TokenType.$break) ? _parseBreak() :
    _advanceIf(TokenType.$for) ? _parseFor() :
    _advanceIf(TokenType.$while) ? _parseWhile() :
    _advanceIf(TokenType.$if) ? _parseIf() :
    _advanceIf(TokenType.leftBrace) ? _parseBlock() :
    _advanceIf(TokenType.$print) ? _parsePrint() : _parseExpressionStatement();

  BreakStatement _parseBreak() {
    final token = _advance();
    if (_loopDepth < 1) throw new LoxError(token, '\'break\' used outside of loop.');

    _expectSemicolon();
    return new BreakStatement();
  }

  /// Desugars `for` into `while`.
  Statement _parseFor() {
    _expect(TokenType.leftParen, 'Expected \'(\' before \'for\' loop header.');
    final initializer =
      _advanceIf(TokenType.semicolon) ? null :
      _advanceIf(TokenType.$var) ? _parseVariable() : _parseExpressionStatement();

    final condition = _peekIs(TokenType.semicolon) ? new LiteralExpression(true) : _parseExpression();
    _expectSemicolon();

    final increment = _peekIs(TokenType.rightParen) ? null : new ExpressionStatement(_parseExpression());
    _expect(TokenType.rightParen, 'Expected \')\' after \'for\' loop header.');

    _loopDepth++;
    final rawBody = _parseNonDeclaration();
    _loopDepth--;
    final body = (increment == null) ? rawBody : new BlockStatement([rawBody, increment]);

    final rawWhile = new WhileStatement(condition, body);
    return (initializer == null) ? rawWhile : new BlockStatement([initializer, rawWhile]);
  }

  WhileStatement _parseWhile() {
    _expect(TokenType.leftParen, 'Expected \'(\' before \'while\' condition.');
    final condition = _parseExpression();
    _expect(TokenType.rightParen, 'Expected \')\' after \'while\' condition.');

    _loopDepth++;
    final body = _parseNonDeclaration();
    _loopDepth--;
    return new WhileStatement(condition, body);
  }

  IfStatement _parseIf() {
    _expect(TokenType.leftParen, 'Expected \'(\' before \'if\' condition.');
    final condition = _parseExpression();
    _expect(TokenType.rightParen, 'Expected \')\' after \'if\' condition.');

    final consequent = _parseNonDeclaration();
    final alternative = _advanceIf(TokenType.$else) ?  _parseNonDeclaration() : null;
    return new IfStatement(condition, consequent, alternative);
  }

  BlockStatement _parseBlock() {
    final statements = <Statement>[];
    while (!_peekIs(TokenType.rightBrace) && !_isAtEnd()) statements.add(_parseStatement());

    _expect(TokenType.rightBrace, 'Expected \'}\'.');
    return new BlockStatement(statements);
  }

  PrintStatement _parsePrint() {
    final expression = _parseExpression();
    _expectSemicolon();
    return new PrintStatement(expression);
  }

  ExpressionStatement _parseExpressionStatement() {
    final expression = _parseExpression();
    _expectSemicolon();
    return new ExpressionStatement(expression);
  }

  Expression _parseExpression() => _parseAssignment();

  Expression _parseAssignment() {
    final expression = _parseTernary();
    if (!_peekIs(TokenType.equal)) return expression;

    final operator = _advance();
    final rhs = _parseAssignment();
    if (expression is IdentifierExpression) return new AssignmentExpression(expression.identifier, rhs);

    throw new LoxError(operator, 'Invalid left-hand side of assignment.');
  }

  Expression _parseTernary() {
    final expression = _parseOr();
    if (!_advanceIf(TokenType.question)) return expression;

    final consequent = _parseAssignment();
    _expect(TokenType.colon, 'Expected \':\' for ternary operator.');
    final alternative = _parseAssignment();
    return new TernaryExpression(expression, consequent, alternative);
  }

  Expression _parseOr() =>
    _parseBinary(_parseAnd, [TokenType.$or]);

  Expression _parseAnd() =>
    _parseBinary(_parseEquality, [TokenType.$and]);

  Expression _parseEquality() =>
    _parseBinary(_parseComparison, [TokenType.equalEqual, TokenType.bangEqual]);

  Expression _parseComparison() =>
    _parseBinary(_parseAdditive, [TokenType.greater, TokenType.greaterEqual, TokenType.less, TokenType.lessEqual]);

  Expression _parseAdditive() =>
    _parseBinary(_parseMultiplicative, [TokenType.minus, TokenType.plus]);

  Expression _parseMultiplicative() =>
    _parseBinary(_parseUnary, [TokenType.star, TokenType.slash]);

  Expression _parseBinary(Expression parseOperand(), List<TokenType> operators) {
    var expression = parseOperand();

    while (_peekIsIn(operators)) {
      final operator = _advance();
      final rightOperand = parseOperand();
      expression = new BinaryExpression(expression, operator, rightOperand);
    }

    return expression;
  }

  Expression _parseUnary() {
    if (!_peekIsIn([TokenType.bang, TokenType.minus])) return _parsePrimary();

    final operator = _advance();
    final operand = _parseUnary();
    return new UnaryExpression(operator, operand);
  }

  Expression _parsePrimary() {
    final next = _advance();
    switch (next.type) {
      case TokenType.leftParen:
        final expression = _parseExpression();
        _expect(TokenType.rightParen, 'Expected \')\'.');
        return new ParenthesizedExpression(expression);
      case TokenType.identifier:
        return new IdentifierExpression(next);
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
      case TokenType.eof:
        throw new LoxError(next, 'Unexpected end of input.');
      default:
        throw new LoxError(next, 'Unexpected token \'${next.lexeme}\'.');
    }
  }

  bool _isAtEnd() => _tokens[_index].type == TokenType.eof;

  Token _peek() => _tokens[_index];

  bool _peekIs(TokenType type) => _peek().type == type;

  bool _peekIsIn(List<TokenType> types) => types.contains(_peek().type);

  Token _advance() => _isAtEnd() ? _tokens[_index] : _tokens[_index++];

  bool _advanceIf(TokenType type) {
    final isMatch = _peek().type == type;
    if (isMatch) _advance();

    return isMatch;
  }

  Token _expect(TokenType type, String errorMessage) {
    final token = _advance();
    if (token.type != type) throw new LoxError(token, errorMessage);

    return token;
  }

  Token _expectSemicolon() => _expect(TokenType.semicolon, 'Expected \';\'.');

  void _synchronize() {
    while (!_isAtEnd()) {
      switch (_peek().type) {
        case TokenType.semicolon:
          _advance();
          return;
        case TokenType.$break:
        case TokenType.$class:
        case TokenType.$fun:
        case TokenType.$for:
        case TokenType.$if:
        case TokenType.$print:
        case TokenType.$return:
        case TokenType.$var:
        case TokenType.$while:
          return;
        default:
          _advance();
          break;
      }
    }
  }
}

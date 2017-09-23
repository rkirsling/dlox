import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

String _stringParse(String literal) => literal.substring(1, literal.length - 1);

const List<TokenType> _statementOpeners = const [
  TokenType.leftBrace,
  TokenType.$break,
  TokenType.$class,
  TokenType.$fun,
  TokenType.$for,
  TokenType.$if,
  TokenType.$print,
  TokenType.$return,
  TokenType.$var,
  TokenType.$while
];

class Parser {
  final List<Token> _tokens;
  final ErrorReporter _errorReporter;
  final List<Statement> _statements = [];
  int _index = 0;
  int _loopDepth = 0;
  int _functionDepth = 0;

  Parser(this._tokens, this._errorReporter);

  List<Statement> parse() {
    while (!_isAtEnd()) _statements.add(_parseStatement());

    return _statements;
  }

  Statement _parseStatement({bool inBlock = false}) {
    try {
      return
        _advanceIf(TokenType.$fun) ? _parseFunction() :
        _advanceIf(TokenType.$var) ? _parseVariable() : _parseNonDeclaration();
    } on LoxError catch (error) {
      _errorReporter.report(error, isDynamic: false);
      _synchronize(inBlock);
      return null;
    }
  }

  FunctionStatement _parseFunction({bool isMethod = false}) {
    final identifier = _expect(TokenType.identifier, 'Expected ${isMethod ? 'method' : 'function'} name.');

    _expect(TokenType.leftParen, 'Expected \'(\' before parameter list.');
    final parameters = _parseParameterOrArgumentList(() => _expect(TokenType.identifier, 'Expected parameter name.'));
    _expect(TokenType.rightParen, 'Expected \')\' after parameter list.');

    _expect(TokenType.leftBrace, 'Expected \'{\'.');
    _functionDepth++;
    final statements = _parseBlock().statements;
    _functionDepth--;
    return new FunctionStatement(identifier, parameters, statements);
  }

  VariableStatement _parseVariable() {
    final identifier = _expect(TokenType.identifier, 'Expected variable name.');
    final initializer = _advanceIf(TokenType.equal) ? _parseExpression() : null;
    _expectSemicolon();
    return new VariableStatement(identifier, initializer);
  }

  Statement _parseNonDeclaration() =>
    _peekIs(TokenType.$return) ? _parseReturn() :
    _peekIs(TokenType.$break) ? _parseBreak() :
    _advanceIf(TokenType.$for) ? _parseFor() :
    _advanceIf(TokenType.$while) ? _parseWhile() :
    _advanceIf(TokenType.$if) ? _parseIf() :
    _advanceIf(TokenType.leftBrace) ? _parseBlock() :
    _advanceIf(TokenType.$print) ? _parsePrint() : _parseExpressionStatement();

  ReturnStatement _parseReturn() {
    final token = _advance();
    if (_functionDepth < 1) throw new LoxError(token, '\'return\' used outside of function.');

    final expression = _peekIs(TokenType.semicolon) ? null : _parseExpression();
    _expectSemicolon();
    return new ReturnStatement(expression);
  }

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
    final alternative = _advanceIf(TokenType.$else) ? _parseNonDeclaration() : null;
    return new IfStatement(condition, consequent, alternative);
  }

  BlockStatement _parseBlock() {
    final statements = <Statement>[];
    while (!_peekIs(TokenType.rightBrace) && !_isAtEnd()) statements.add(_parseStatement(inBlock: true));

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
    if (expression is IdentifierExpression) {
      final rhs = _parseAssignment();
      return new AssignmentExpression(expression.identifier, rhs);
    }

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
    if (!_peekIsIn([TokenType.bang, TokenType.minus])) return _parseCall();

    final operator = _advance();
    final operand = _parseUnary();
    return new UnaryExpression(operator, operand);
  }

  Expression _parseCall() {
    var expression = _parsePrimary();

    while (_peekIs(TokenType.leftParen)) {
      final parenthesis = _advance();
      final arguments = _parseParameterOrArgumentList(_parseExpression);
      _expect(TokenType.rightParen, 'Expected \')\' after argument list.');
      expression = new CallExpression(expression, parenthesis, arguments);
    }

    return expression;
  }

  Expression _parsePrimary() {
    final token = _peek();

    return
      _advanceIf(TokenType.leftParen) ? _parseParenthesized() :
      _advanceIf(TokenType.identifier) ? new IdentifierExpression(token) :
      _advanceIf(TokenType.$nil) ? new LiteralExpression(null) :
      _advanceIf(TokenType.$true) ? new LiteralExpression(true) :
      _advanceIf(TokenType.$false) ? new LiteralExpression(false) :
      _advanceIf(TokenType.string) ? new LiteralExpression(_stringParse(token.lexeme)) :
      _advanceIf(TokenType.number) ? new LiteralExpression(double.parse(token.lexeme)) :
        throw new LoxError(token, _isAtEnd() ? 'Unexpected end of input.' : 'Unexpected token \'${token.lexeme}\'.');
  }

  ParenthesizedExpression _parseParenthesized() {
    final expression = _parseExpression();
    _expect(TokenType.rightParen, 'Expected \')\'.');
    return new ParenthesizedExpression(expression);
  }

  List<T> _parseParameterOrArgumentList<T>(T Function() parseItem) {
    final list = <T>[];

    if (!_peekIs(TokenType.rightParen)) {
      do {
        list.add(parseItem());
      } while (_advanceIf(TokenType.comma));
    }

    return list;
  }

  bool _isAtEnd() => _peekIs(TokenType.eof);

  Token _peek() => _tokens[_index];

  bool _peekIs(TokenType type) => _peek().type == type;

  bool _peekIsIn(List<TokenType> types) => types.contains(_peek().type);

  Token _advance() => _isAtEnd() ? _tokens[_index] : _tokens[_index++];

  bool _advanceIf(TokenType type) {
    final isMatch = _peekIs(type);
    if (isMatch) _advance();

    return isMatch;
  }

  Token _expect(TokenType type, String errorMessage) {
    if (!_peekIs(type)) throw new LoxError(_peek(), errorMessage);

    return _advance();
  }

  void _expectSemicolon() {
    if (!_peekIs(TokenType.semicolon)) {
      _error('Expected \';\'.');
      return;
    }

    _advance();
  }

  void _synchronize(bool inBlock) {
    while (!_isAtEnd()) {
      if (_advanceIf(TokenType.semicolon)) return;

      if (_peekIs(TokenType.rightBrace) && inBlock) return;

      if (_peekIsIn(_statementOpeners)) return;

      _advance();
    }
  }

  void _error(String message) {
    final token = _peek();
    _errorReporter.reportAtPosition(token.line, token.column, message);
  }
}

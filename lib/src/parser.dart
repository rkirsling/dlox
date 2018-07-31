import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

String _stringParse(String literal) => literal.substring(1, literal.length - 1);

const List<TokenType> _statementOpeners = [
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

  Parser(this._tokens, this._errorReporter);

  List<Statement> parse() {
    while (!_isAtEnd()) _statements.add(_parseStatement());

    return _statements;
  }

  Statement _parseStatement({bool inBlock = false}) {
    try {
      return
        _advanceIf(TokenType.$class) ? _parseClass() :
        _advanceIf(TokenType.$fun) ? _parseFunction() :
        _advanceIf(TokenType.$var) ? _parseVariable() : _parseNonDeclaration();
    } on LoxError catch (error) {
      _errorReporter.report(error, isDynamic: false);
      _synchronizeStatement(inBlock: inBlock);
      return null;
    }
  }

  ClassStatement _parseClass() {
    final identifier = _expectIdentifier('class');
    final superclass = _advanceIf(TokenType.less) ? IdentifierExpression(_expectIdentifier('superclass')) : null;
    _expect(TokenType.leftBrace, 'Expected \'{\' before class body.');

    final methods = <FunctionStatement>[];
    while (!_peekIs(TokenType.rightBrace) && !_isAtEnd()) methods.add(_parseMethod());

    _expect(TokenType.rightBrace, 'Expected \'}\' after class body.');
    return ClassStatement(identifier, superclass, methods);
  }

  FunctionStatement _parseMethod() {
    try {
      return _parseFunction(isMethod: true);
    } on LoxError catch (error) {
      _errorReporter.report(error, isDynamic: false);
      _synchronizeMethod();
      return null;
    }
  }

  FunctionStatement _parseFunction({bool isMethod = false}) {
    final identifier = _expectIdentifier(isMethod ? 'method' : 'function');

    _expect(TokenType.leftParen, 'Expected \'(\' before parameter list.');
    final parameters = _parseParameterOrArgumentList(() => _expectIdentifier('parameter'));
    _expect(TokenType.rightParen, 'Expected \')\' after parameter list.');

    _expect(TokenType.leftBrace, 'Expected \'{\'.');
    final statements = _parseBlock().statements;
    return FunctionStatement(identifier, parameters, statements);
  }

  VariableStatement _parseVariable() {
    final identifier = _expectIdentifier('variable');
    final initializer = _advanceIf(TokenType.equal) ? _parseExpression() : null;
    _expectSemicolon();
    return VariableStatement(identifier, initializer);
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
    final keyword = _advance();
    final expression = _peekIs(TokenType.semicolon) ? null : _parseExpression();
    _expectSemicolon();
    return ReturnStatement(keyword, expression);
  }

  BreakStatement _parseBreak() {
    final keyword = _advance();
    _expectSemicolon();
    return BreakStatement(keyword);
  }

  /// Desugars `for` into `while`.
  Statement _parseFor() {
    _expect(TokenType.leftParen, 'Expected \'(\' before \'for\' loop header.');
    final initializer =
      _advanceIf(TokenType.semicolon) ? null :
      _advanceIf(TokenType.$var) ? _parseVariable() : _parseExpressionStatement();

    final condition = _peekIs(TokenType.semicolon) ? LiteralExpression(true) : _parseExpression();
    _expectSemicolon();

    final increment = _peekIs(TokenType.rightParen) ? null : ExpressionStatement(_parseExpression());
    _expect(TokenType.rightParen, 'Expected \')\' after \'for\' loop header.');

    final rawBody = _parseNonDeclaration();
    final body = (increment == null) ? rawBody : BlockStatement([rawBody, increment]);

    final rawWhile = WhileStatement(condition, body);
    return (initializer == null) ? rawWhile : BlockStatement([initializer, rawWhile]);
  }

  WhileStatement _parseWhile() {
    _expect(TokenType.leftParen, 'Expected \'(\' before \'while\' condition.');
    final condition = _parseExpression();
    _expect(TokenType.rightParen, 'Expected \')\' after \'while\' condition.');

    final body = _parseNonDeclaration();
    return WhileStatement(condition, body);
  }

  IfStatement _parseIf() {
    _expect(TokenType.leftParen, 'Expected \'(\' before \'if\' condition.');
    final condition = _parseExpression();
    _expect(TokenType.rightParen, 'Expected \')\' after \'if\' condition.');

    final consequent = _parseNonDeclaration();
    final alternative = _advanceIf(TokenType.$else) ? _parseNonDeclaration() : null;
    return IfStatement(condition, consequent, alternative);
  }

  BlockStatement _parseBlock() {
    final statements = <Statement>[];
    while (!_peekIs(TokenType.rightBrace) && !_isAtEnd()) statements.add(_parseStatement(inBlock: true));

    _expect(TokenType.rightBrace, 'Expected \'}\'.');
    return BlockStatement(statements);
  }

  PrintStatement _parsePrint() {
    final expression = _parseExpression();
    _expectSemicolon();
    return PrintStatement(expression);
  }

  ExpressionStatement _parseExpressionStatement() {
    final expression = _parseExpression();
    _expectSemicolon();
    return ExpressionStatement(expression);
  }

  Expression _parseExpression() => _parseAssignment();

  Expression _parseAssignment() {
    final expression = _parseTernary();
    if (!_peekIs(TokenType.equal)) return expression;

    final operator = _advance();
    if (expression is! PropertyExpression && expression is! IdentifierExpression) {
      throw LoxError(operator, 'Invalid left-hand side of assignment.');
    }

    final rhs = _parseAssignment();
    return AssignmentExpression(expression, rhs);
  }

  Expression _parseTernary() {
    final expression = _parseOr();
    if (!_advanceIf(TokenType.question)) return expression;

    final consequent = _parseAssignment();
    _expect(TokenType.colon, 'Expected \':\' for ternary operator.');
    final alternative = _parseAssignment();
    return TernaryExpression(expression, consequent, alternative);
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
      expression = BinaryExpression(expression, operator, rightOperand);
    }

    return expression;
  }

  Expression _parseUnary() {
    if (!_peekIsIn([TokenType.bang, TokenType.minus])) return _parseCallOrProperty();

    final operator = _advance();
    final operand = _parseUnary();
    return UnaryExpression(operator, operand);
  }

  Expression _parseCallOrProperty() {
    var expression = _parsePrimary();

    while (_peekIsIn([TokenType.leftParen, TokenType.dot])) {
      final operator = _advance();

      if (operator.type == TokenType.leftParen) {
        final arguments = _parseParameterOrArgumentList(_parseExpression);
        _expect(TokenType.rightParen, 'Expected \')\' after argument list.');
        expression = CallExpression(expression, operator, arguments);
        continue;
      }

      final identifier = _expectIdentifier('property');
      expression = PropertyExpression(expression, identifier);
    }

    return expression;
  }

  Expression _parsePrimary() {
    final token = _peek();

    return
      _peekIs(TokenType.$super) ? _parseSuper() :
      _advanceIf(TokenType.leftParen) ? _parseParenthesized() :
      _advanceIf(TokenType.identifier) ? IdentifierExpression(token) :
      _advanceIf(TokenType.$this) ? ThisExpression(token) :
      _advanceIf(TokenType.$nil) ? LiteralExpression(null) :
      _advanceIf(TokenType.$true) ? LiteralExpression(true) :
      _advanceIf(TokenType.$false) ? LiteralExpression(false) :
      _advanceIf(TokenType.string) ? LiteralExpression(_stringParse(token.lexeme)) :
      _advanceIf(TokenType.number) ? LiteralExpression(double.parse(token.lexeme)) :
        throw LoxError(token, _isAtEnd() ? 'Unexpected end of input.' : 'Unexpected token \'${token.lexeme}\'.');
  }

  SuperExpression _parseSuper() {
    final keyword = _advance();
    _expect(TokenType.dot, 'Expected \'.\' after \'super\'.');
    final identifier = _expectIdentifier('superclass method');
    return SuperExpression(keyword, identifier);
  }

  ParenthesizedExpression _parseParenthesized() {
    final expression = _parseExpression();
    _expect(TokenType.rightParen, 'Expected \')\'.');
    return ParenthesizedExpression(expression);
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

  void _expect(TokenType type, String errorMessage) {
    if (!_peekIs(type)) throw LoxError(_peek(), errorMessage);

    _advance();
  }

  void _expectSemicolon() {
    if (!_peekIs(TokenType.semicolon)) {
      _error('Expected \';\'.');
      return;
    }

    _advance();
  }

  Token _expectIdentifier(String kind) {
    if (!_peekIs(TokenType.identifier)) throw LoxError(_peek(), 'Expected $kind name.');

    return _advance();
  }

  void _synchronizeStatement({bool inBlock = false}) {
    bool isSynchronized() =>
      _isAtEnd() ||
      _advanceIf(TokenType.semicolon) ||
      _peekIs(TokenType.rightBrace) && inBlock ||
      _peekIsIn(_statementOpeners);

    while (!isSynchronized()) _advance();
  }

  void _synchronizeMethod() {
    bool isSynchronized() =>
      _isAtEnd() ||
      _peekIs(TokenType.rightBrace) ||
      _advanceIf(TokenType.leftBrace) && _parseBlock() != null;

    while (!isSynchronized()) _advance();
  }

  void _error(String message) {
    final token = _peek();
    _errorReporter.reportAtPosition(token.line, token.column, message);
  }
}

import 'package:charcode/ascii.dart';

import 'error_reporter.dart';
import 'token.dart';

bool _isWhitespace(int char) => char == $space || char == $tab || char == $cr || char == $lf;

bool _isDigit(int char) => char >= $0 && char <= $9;

bool _isAlpha(int char) => (char >= $a && char <= $z) || (char >= $A && char <= $Z) || char == $_;

bool _isAlphaNumeric(int char) => _isAlpha(char) || _isDigit(char);

const Map<String, TokenType> _keywordTypes = const {
  'and': TokenType.$and,
  'class': TokenType.$class,
  'else': TokenType.$else,
  'false': TokenType.$false,
  'fun': TokenType.$fun,
  'for': TokenType.$for,
  'if': TokenType.$if,
  'nil': TokenType.$nil,
  'or': TokenType.$or,
  'print': TokenType.$print,
  'return': TokenType.$return,
  'super': TokenType.$super,
  'this': TokenType.$this,
  'true': TokenType.$true,
  'var': TokenType.$var,
  'while': TokenType.$while
};

class Scanner {
  final String _source;
  final ErrorReporter _errorReporter;
  final List<Token> _tokens = [];
  int _offset = 0;
  int _tokenStart = 0;
  int _line = 1;
  int _lineStart = 0;

  Scanner(this._source, this._errorReporter);

  List<Token> scanTokens() {
    while (!_isAtEnd()) _scanToken();

    _addToken(TokenType.eof);
    return _tokens;
  }

  void _scanToken() {
    _tokenStart = _offset;

    final next = _advance();
    switch (next) {
      case $lparen:
        _addToken(TokenType.leftParen);
        break;
      case $rparen:
        _addToken(TokenType.rightParen);
        break;
      case $lbrace:
        _addToken(TokenType.leftBrace);
        break;
      case $rbrace:
        _addToken(TokenType.rightBrace);
        break;
      case $comma:
        _addToken(TokenType.comma);
        break;
      case $dot:
        _addToken(TokenType.dot);
        break;
      case $minus:
        _addToken(TokenType.minus);
        break;
      case $plus:
        _addToken(TokenType.plus);
        break;
      case $semicolon:
        _addToken(TokenType.semicolon);
        break;
      case $slash:
        if (_advanceIf($slash)) {
          _advanceTo($lf);
        } else if (_advanceIf($asterisk)) {
          _skipBlockComment();
        } else {
          _addToken(TokenType.slash);
        }
        break;
      case $asterisk:
        _addToken(TokenType.star);
        break;
      case $exclamation:
        _addToken(_advanceIf($equal) ? TokenType.bangEqual : TokenType.bang);
        break;
      case $equal:
        _addToken(_advanceIf($equal) ? TokenType.equalEqual : TokenType.equal);
        break;
      case $greater_than:
        _addToken(_advanceIf($equal) ? TokenType.greaterEqual : TokenType.greater);
        break;
      case $less_than:
        _addToken(_advanceIf($equal) ? TokenType.lessEqual : TokenType.less);
        break;
      case $quote:
        _scanString();
        break;
      default:
        if (_isWhitespace(next)) {
          _advanceWhile(_isWhitespace);
        } else if (_isDigit(next)) {
          _scanNumber();
        } else if (_isAlpha(next)) {
          _scanIdentifierOrKeyword();
        } else {
          _error('Unexpected character: \'${new String.fromCharCode(next)}\'.');
        }
        break;
    }
  }

  void _addToken(TokenType type, [Object value]) {
    final lexeme = _isAtEnd() ? '' : _source.substring(_tokenStart, _offset);
    _tokens.add(new Token(type, lexeme, value, _line));
  }

  void _skipBlockComment() {
    while (!_isAtEnd()) {
      if (_advance() == $asterisk && _advanceIf($slash)) return;
    }

    _error('Unterminated block comment.');
  }

  void _scanString() {
    // Note: Lox only has multiline strings.
    final foundMatchingQuote = _advanceTo($quote);
    if (!foundMatchingQuote) {
      _error('Unterminated string.');
      return;
    }

    final value = _source.substring(_tokenStart + 1, _offset - 1);
    _addToken(TokenType.string, value);
  }

  void _scanNumber() {
    _advanceWhile(_isDigit);

    if (_peek() == $dot && _isDigit(_peekSecond())) {
      _advance();
      _advance();
      _advanceWhile(_isDigit);
    }

    final value = double.parse(_source.substring(_tokenStart, _offset));
    _addToken(TokenType.number, value);
  }

  void _scanIdentifierOrKeyword() {
    _advanceWhile(_isAlphaNumeric);

    final lexeme = _source.substring(_tokenStart, _offset);
    _addToken(_keywordTypes[lexeme] ?? TokenType.identifier);
  }

  bool _isAtEnd() => _offset >= _source.length;

  int _peek() => _offset >= _source.length ? -1 : _source.codeUnitAt(_offset);

  int _peekSecond() => _offset + 1 >= _source.length ? -1 : _source.codeUnitAt(_offset + 1);

  int _advance() {
    final char = _source.codeUnitAt(_offset++);

    // Update internal line / column information when we hit a (non-final) newline.
    if (char == $lf && !_isAtEnd()) {
      _line++;
      _lineStart = _offset;
    }

    return char;
  }

  bool _advanceIf(int expectedChar) {
    final isMatch = _peek() == expectedChar;
    if (isMatch) _advance();

    return isMatch;
  }

  bool _advanceTo(int lastChar) {
    while (!_isAtEnd()) {
      if (_advance() == lastChar) return true;
    }

    return false;
  }

  void _advanceWhile(bool predicate(int char)) {
    while (predicate(_peek())) _advance();
  }

  void _error(String message) {
    _errorReporter.report(_line, _offset - _lineStart, message);
  }
}

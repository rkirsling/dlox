enum TokenType {
  // single-character tokens
  leftParen,
  rightParen,
  leftBrace,
  rightBrace,
  comma,
  dot,
  minus,
  plus,
  semicolon,
  slash,
  star,
  question,
  colon,

  // single-character tokens which may combine with '='
  bang,
  bangEqual,
  equal,
  equalEqual,
  greater,
  greaterEqual,
  less,
  lessEqual,

  // literals
  identifier,
  string,
  number,

  // keywords
  $and,
  $break,
  $class,
  $else,
  $false,
  $fun,
  $for,
  $if,
  $nil,
  $or,
  $print,
  $return,
  $super,
  $this,
  $true,
  $var,
  $while,

  eof
}

class Token {
  final TokenType type;
  final String lexeme;
  final int line;
  final int column;

  Token(this.type, this.lexeme, this.line, this.column);

  @override
  String toString() => lexeme;
}

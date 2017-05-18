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
  final Object value;
  final int line;

  const Token(this.type, this.lexeme, this.value, this.line);

  @override
  String toString() => '$type ${value ?? lexeme}';
}

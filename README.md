# dlox

A Dart port of the Lox language interpreter (http://www.craftinginterpreters.com/).

Supported language extensions:
- Block comments (`/* ... */`)
- Ternary operator (`x ? y : z`)
- Comparison operators for strings (`"a" < "at"`)
- Error on variable redefinition (`var x = 1; var x = 2;`)
- Break statement (`break;`)

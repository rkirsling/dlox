# dlox

A Dart port of jlox, the Lox language's AST interpreter (http://www.craftinginterpreters.com/).

See also [cclox](https://github.com/rkirsling/cclox) for my C++ port of the bytecode VM.

Supported language extensions:
- Block comments (`/* ... */`)
- Ternary operator (`x ? y : z`)
- Comparison operators for strings (`"a" < "at"`)
- Coercing string concatenation operator (`10 + "ms"`)
- Error on global redefinition (`var x = 1; var x = 2;`)
- Break statement (`break;`)
- Error on method redefinition (`class C { f() {} f() {} }`)
- Error on class initializer access (`instance.init`)

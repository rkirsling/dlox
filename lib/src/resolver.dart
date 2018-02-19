import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

class _Loop {}
class _Function {}
class _Initializer extends _Function {}
class _Class {}
class _DerivedClass extends _Class {}

class Resolver implements AstVisitor<void> {
  final ErrorReporter _errorReporter;
  final List<Set<String>> _scopeStack = [new Set()];
  Set<String> _savedGlobals;
  _Loop _currentLoop;
  _Function _currentFunction;
  _Class _currentClass;
  String _nameToDeclare;

  Resolver(this._errorReporter);

  void resolve(List<Statement> statements) {
    statements.forEach(_resolve);
  }

  void saveGlobals() {
    _savedGlobals = new Set<String>.from(_scopeStack.first);
  }

  void restoreGlobals() {
    _scopeStack.first.retainAll(_savedGlobals);
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    _resolve(node.expression);
  }

  @override
  void visitPrintStatement(PrintStatement node) {
    _resolve(node.expression);
  }

  @override
  void visitBlockStatement(BlockStatement node) {
    _scopeStack.add(new Set());
    node.statements.forEach(_resolve);
    _scopeStack.removeLast();
  }

  @override
  void visitIfStatement(IfStatement node) {
    _resolve(node.condition);
    _resolve(node.consequent);
    _resolveOptional(node.alternative);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _resolve(node.condition);

    final previous = _currentLoop;
    _currentLoop = new _Loop();
    _resolve(node.body);
    _currentLoop = previous;
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    if (_currentLoop == null) _error(node.keyword, '\'break\' used outside of loop.');
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    if (_currentFunction == null) {
      _error(node.keyword, '\'return\' used outside of function.');
    } else if (_currentFunction is _Initializer) {
      _error(node.keyword, '\'return\' used in class initializer.');
    }

    _resolveOptional(node.expression);
  }

  @override
  void visitVariableStatement(VariableStatement node) {
    _declare(node.identifier);

    _nameToDeclare = node.identifier.lexeme;
    _resolveOptional(node.initializer);
    _nameToDeclare = null;
  }

  @override
  void visitFunctionStatement(FunctionStatement node) {
    _declare(node.identifier);
    _resolveFunction(node.parameters, node.statements);
  }

  @override
  void visitClassStatement(ClassStatement node) {
    _resolveOptional(node.superclass);
    _declare(node.identifier);
    _resolveOptional(node.superclass);

    final previous = _currentClass;
    _currentClass = node.superclass != null ? new _DerivedClass() : new _Class();
    _scopeStack.add(new Set());
    _scopeStack.last.add('this');
    if (node.superclass != null) _scopeStack.last.add('super');

    final methodNames = new Set<String>();
    for (final method in node.methods) {
      final name = method.identifier.lexeme;
      if (methodNames.contains(name)) _error(method.identifier, 'Method \'$name\' is already defined for this class.');

      _resolveFunction(method.parameters, method.statements, isInitializer: name == 'init');
      methodNames.add(name);
    }

    _scopeStack.removeLast();
    _currentClass = previous;
  }

  @override
  void visitLiteralExpression(LiteralExpression node) {}

  @override
  void visitThisExpression(ThisExpression node) {
    if (_currentClass == null) _error(node.keyword, '\'this\' used outside of class.');

    _resolveReference(node, 'this');
  }

  @override
  void visitIdentifierExpression(IdentifierExpression node) {
    final name = node.identifier.lexeme;
    if (name == _nameToDeclare) _error(node.identifier, 'Identifier \'$name\' is referenced in its own declaration.');

    _resolveReference(node, name);
  }

  @override
  void visitParenthesizedExpression(ParenthesizedExpression node) {
    _resolve(node.expression);
  }

  @override
  void visitSuperExpression(SuperExpression node) {
    if (_currentClass == null) {
      _error(node.keyword, '\'super\' used outside of class.');
    } else if (_currentClass is! _DerivedClass) {
      _error(node.keyword, '\'super\' used in non-derived class.');
    }

    _resolveReference(node, 'super');
  }

  @override
  void visitPropertyExpression(PropertyExpression node) {
    _resolve(node.context);
  }

  @override
  void visitCallExpression(CallExpression node) {
    _resolve(node.callee);
    node.arguments.forEach(_resolve);
  }

  @override
  void visitUnaryExpression(UnaryExpression node) {
    _resolve(node.operand);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _resolve(node.leftOperand);
    _resolve(node.rightOperand);
  }

  @override
  void visitTernaryExpression(TernaryExpression node) {
    _resolve(node.condition);
    _resolve(node.consequent);
    _resolve(node.alternative);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _resolve(node.rhs);
    _resolve(node.lhs);
  }

  void _resolveFunction(List<Token> parameters, List<Statement> statements, {bool isInitializer = false}) {
    final previous = _currentFunction;
    _currentFunction = isInitializer ? new _Initializer() : new _Function();
    _scopeStack.add(new Set());

    parameters.forEach(_declare);
    statements.forEach(_resolve);

    _scopeStack.removeLast();
    _currentFunction = previous;
  }

  void _resolve(AstNode node) {
    node.accept(this);
  }

  void _resolveOptional(AstNode node) {
    if (node == null) return;

    _resolve(node);
  }

  void _declare(Token identifier) {
    final name = identifier.lexeme;

    if (_scopeStack.last.contains(name)) {
      _error(identifier, 'Identifier \'$name\' is already declared in this scope.');
      return;
    }

    _scopeStack.last.add(name);
  }

  void _resolveReference(Resolvable node, String name) {
    final maxDepth = _scopeStack.length - 1;

    for (var i = maxDepth; i > 0; i--) {
      if (_scopeStack[i].contains(name)) {
        node.depth = maxDepth - i;
        return;
      }
    }

    // Globals must be assumed to exist (statically).
    node.depth = maxDepth;
  }

  void _error(Token token, String message) {
    _errorReporter.reportAtPosition(token.line, token.column, message);
  }
}

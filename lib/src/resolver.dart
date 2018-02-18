import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

class _Loop {}

class _Function {
  final bool isInitializer;

  _Function({this.isInitializer = false});
}

class _Class {}

class Resolver implements AstVisitor<void> {
  final ErrorReporter _errorReporter;
  final List<Set<String>> _scopeStack = [new Set()];
  Set<String> _savedGlobals;
  _Loop _currentLoop;
  _Function _currentFunction;
  _Class _currentClass;
  String _toBeDefined;

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
    if (node.alternative == null) return;

    _resolve(node.alternative);
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
    } else if (_currentFunction.isInitializer) {
      _error(node.keyword, '\'return\' used in class initializer.');
    }

    if (node.expression == null) return;

    _resolve(node.expression);
  }

  @override
  void visitVariableStatement(VariableStatement node) {
    _declare(node.identifier);
    if (node.initializer == null) return;

    _toBeDefined = node.identifier.lexeme;
    _resolve(node.initializer);
    _toBeDefined = null;
  }

  @override
  void visitFunctionStatement(FunctionStatement node) {
    _declare(node.identifier);
    _resolveFunction(node.parameters, node.statements);
  }

  @override
  void visitClassStatement(ClassStatement node) {
    _declare(node.identifier);

    final previous = _currentClass;
    _currentClass = new _Class();
    _scopeStack.add(new Set());
    _scopeStack.last.add('this');

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
    if (name == _toBeDefined) _error(node.identifier, 'Identifier \'$name\' is referenced in its own definition.');

    _resolveReference(node, name);
  }

  @override
  void visitParenthesizedExpression(ParenthesizedExpression node) {
    _resolve(node.expression);
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
    _currentFunction = new _Function(isInitializer: isInitializer);
    _scopeStack.add(new Set());

    parameters.forEach(_declare);
    statements.forEach(_resolve);

    _scopeStack.removeLast();
    _currentFunction = previous;
  }

  void _resolve(AstNode node) {
    node.accept(this);
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

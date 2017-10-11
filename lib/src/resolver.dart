import 'ast.dart';
import 'error_reporter.dart';
import 'token.dart';

class Resolver implements AstVisitor<void> {
  final ErrorReporter _errorReporter;
  final List<Set<String>> _scopeStack = [new Set()];
  String _toBeDefined;

  Resolver(this._errorReporter);

  void resolve(List<Statement> statements) {
    final previousGlobals = new Set<String>.from(_scopeStack.first);

    statements.forEach(_resolve);
    if (_errorReporter.hadError) _scopeStack.first.retainAll(previousGlobals);
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
    _resolve(node.body);
  }

  @override
  void visitBreakStatement(BreakStatement node) {}

  @override
  void visitReturnStatement(ReturnStatement node) {
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

    _scopeStack.add(new Set());
    node.parameters.forEach(_declare);
    node.statements.forEach(_resolve);
    _scopeStack.removeLast();
  }

  @override
  void visitLiteralExpression(LiteralExpression node) {}

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
    _resolveReference(node, node.identifier.lexeme);
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

import 'ast.dart';

String _parenthesize(List<String> parts) => '(' + parts.join(' ') + ')';

class AstPrinter implements AstVisitor<String> {
  String print(AstNode node) => node.accept(this);

  @override
  String visitExpressionStatement(ExpressionStatement node) =>
    _parenthesize([';', print(node.expression)]);

  @override
  String visitPrintStatement(PrintStatement node) =>
    _parenthesize(['print', print(node.expression)]);

  @override
  String visitBlockStatement(BlockStatement node) =>
    _parenthesize(['{}']..addAll(node.statements.map(print)));

  @override
  String visitVarStatement(VarStatement node) => _parenthesize(
    node.initializer == null
      ? ['var', node.identifier.lexeme]
      : ['var', node.identifier.lexeme, print(node.initializer)]
  );

  @override
  String visitLiteralExpression(LiteralExpression node) =>
    node.value.toString();

  @override
  String visitIdentifierExpression(IdentifierExpression node) =>
    node.identifier.lexeme;

  @override
  String visitParenthesizedExpression(ParenthesizedExpression node) =>
    _parenthesize(['', print(node.expression)]);

  @override
  String visitUnaryExpression(UnaryExpression node) =>
    _parenthesize([node.operator.lexeme, print(node.operand)]);

  @override
  String visitBinaryExpression(BinaryExpression node) =>
    _parenthesize([node.operator.lexeme, print(node.leftOperand), print(node.rightOperand)]);

  @override
  String visitTernaryExpression(TernaryExpression node) =>
    _parenthesize(['?:', print(node.condition), print(node.consequent), print(node.alternative)]);

  @override
  String visitAssignmentExpression(AssignmentExpression node) =>
    _parenthesize(['=', node.identifier.lexeme, print(node.rhs)]);
}

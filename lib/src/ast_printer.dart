import 'ast.dart';

String _parenthesize(List<String> parts) => '(' + parts.join(' ') + ')';

class AstPrinter implements AstVisitor<String> {
  String print(AstNode node) => node.accept(this);

  @override
  String visitLiteralExpression(LiteralExpression node) =>
    node.value.toString();

  @override
  String visitUnaryExpression(UnaryExpression node) =>
    _parenthesize([node.operator.lexeme, print(node.operand)]);

  @override
  String visitBinaryExpression(BinaryExpression node) =>
    _parenthesize([node.operator.lexeme, print(node.leftOperand), print(node.rightOperand)]);

  @override
  String visitParenthesizedExpression(ParenthesizedExpression node) =>
    _parenthesize([print(node.expression)]);
}

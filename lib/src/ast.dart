// DO NOT EDIT -- This file is generated from ast.yaml.
import 'token.dart';

abstract class AstVisitor<R> {
  R visitBinaryExpression(BinaryExpression node);
  R visitLiteralExpression(LiteralExpression node);
  R visitParenthesizedExpression(ParenthesizedExpression node);
  R visitTernaryExpression(TernaryExpression node);
  R visitUnaryExpression(UnaryExpression node);
  R visitExpressionStatement(ExpressionStatement node);
  R visitPrintStatement(PrintStatement node);
}

abstract class AstNode {
  R accept<R>(AstVisitor<R> visitor);
}

abstract class Expression extends AstNode {}

class BinaryExpression extends Expression {
  final Expression leftOperand;
  final Token operator;
  final Expression rightOperand;

  BinaryExpression(this.leftOperand, this.operator, this.rightOperand);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitBinaryExpression(this);
}

class LiteralExpression extends Expression {
  final Object value;

  LiteralExpression(this.value);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitLiteralExpression(this);
}

class ParenthesizedExpression extends Expression {
  final Expression expression;

  ParenthesizedExpression(this.expression);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitParenthesizedExpression(this);
}

class TernaryExpression extends Expression {
  final Expression condition;
  final Expression consequent;
  final Expression alternative;

  TernaryExpression(this.condition, this.consequent, this.alternative);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitTernaryExpression(this);
}

class UnaryExpression extends Expression {
  final Token operator;
  final Expression operand;

  UnaryExpression(this.operator, this.operand);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitUnaryExpression(this);
}

abstract class Statement extends AstNode {}

class ExpressionStatement extends Statement {
  final Expression expression;

  ExpressionStatement(this.expression);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitExpressionStatement(this);
}

class PrintStatement extends Statement {
  final Expression expression;

  PrintStatement(this.expression);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitPrintStatement(this);
}

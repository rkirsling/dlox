// DO NOT EDIT -- This file is generated from ast.yaml.
import 'token.dart';

abstract class AstVisitor<R> {
  R visitAssignmentExpression(AssignmentExpression node);
  R visitBinaryExpression(BinaryExpression node);
  R visitIdentifierExpression(IdentifierExpression node);
  R visitLiteralExpression(LiteralExpression node);
  R visitParenthesizedExpression(ParenthesizedExpression node);
  R visitTernaryExpression(TernaryExpression node);
  R visitUnaryExpression(UnaryExpression node);
  R visitBlockStatement(BlockStatement node);
  R visitBreakStatement(BreakStatement node);
  R visitExpressionStatement(ExpressionStatement node);
  R visitIfStatement(IfStatement node);
  R visitPrintStatement(PrintStatement node);
  R visitVarStatement(VarStatement node);
  R visitWhileStatement(WhileStatement node);
}

abstract class AstNode {
  R accept<R>(AstVisitor<R> visitor);
}

abstract class Expression extends AstNode {}

class AssignmentExpression extends Expression {
  final Token identifier;
  final Expression rhs;

  AssignmentExpression(this.identifier, this.rhs);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitAssignmentExpression(this);
}

class BinaryExpression extends Expression {
  final Expression leftOperand;
  final Token operator;
  final Expression rightOperand;

  BinaryExpression(this.leftOperand, this.operator, this.rightOperand);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitBinaryExpression(this);
}

class IdentifierExpression extends Expression {
  final Token identifier;

  IdentifierExpression(this.identifier);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitIdentifierExpression(this);
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

class BlockStatement extends Statement {
  final List<Statement> statements;

  BlockStatement(this.statements);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitBlockStatement(this);
}

class BreakStatement extends Statement {
  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitBreakStatement(this);
}

class ExpressionStatement extends Statement {
  final Expression expression;

  ExpressionStatement(this.expression);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitExpressionStatement(this);
}

class IfStatement extends Statement {
  final Expression condition;
  final Statement consequent;
  final Statement alternative;

  IfStatement(this.condition, this.consequent, this.alternative);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitIfStatement(this);
}

class PrintStatement extends Statement {
  final Expression expression;

  PrintStatement(this.expression);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitPrintStatement(this);
}

class VarStatement extends Statement {
  final Token identifier;
  final Expression initializer;

  VarStatement(this.identifier, this.initializer);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitVarStatement(this);
}

class WhileStatement extends Statement {
  final Expression condition;
  final Statement body;

  WhileStatement(this.condition, this.body);

  @override
  R accept<R>(AstVisitor<R> visitor) =>
    visitor.visitWhileStatement(this);
}

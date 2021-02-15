module ssa::TestSSAIntegration

import analysis::graphs::Graph;

import lang::jimple::decompiler::Decompiler;
import lang::jimple::toolkit::FlowGraph;
import lang::jimple::core::Syntax;

import lang::jimple::toolkit::ssa::DominanceTree;
import lang::jimple::toolkit::ssa::PhiFunctionInsertion;
import lang::jimple::toolkit::ssa::DominanceFrontier;
import lang::jimple::toolkit::ssa::VariableRenaming;

test bool testSimpleExceptionDeclaration() {
	loc simpleExceptionPath = |project://JimpleFramework/target/test-classes/samples/ssa/SimpleException.class|;
	ClassOrInterfaceDeclaration simpleExceptionDeclaration = decompile(simpleExceptionPath);
	return false;
}
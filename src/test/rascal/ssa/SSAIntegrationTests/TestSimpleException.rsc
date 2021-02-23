module ssa::SSAIntegrationTests::TestSimpleException

import List;
import Type;

import analysis::graphs::Graph;

import lang::jimple::decompiler::Decompiler;
import lang::jimple::core::Context;

import lang::jimple::toolkit::FlowGraph;
import lang::jimple::core::Syntax;

import lang::jimple::toolkit::ssa::Generator;

// Enters in infinite loop, since this try/catch flow isn't implemented in the decompiler yet
test bool testRunMethod() {
	loc simpleExceptionPath = |project://JimpleFramework/target/test-classes/samples/ssa/SimpleException.class|;
	ClassOrInterfaceDeclaration simpleExceptionDeclaration = decompile(simpleExceptionPath);
	list[Method] methodList = castMethodList(simpleExceptionDeclaration);
	
	MethodBody methodBody = castMethodBody(methodList[1]);
	FlowGraph result = applySSATransformation(methodBody);
	return result == flowGraph;
}

test bool testRaiseExceptionMethod() {
	loc simpleExceptionPath = |project://JimpleFramework/target/test-classes/samples/ssa/SimpleException.class|;
	ClassOrInterfaceDeclaration simpleExceptionDeclaration = decompile(simpleExceptionPath);
	list[Method] methodList = castMethodList(simpleExceptionDeclaration);
	
	MethodBody methodBody = castMethodBody(methodList[2]);
	
	FlowGraph result = applySSATransformation(methodBody);

	return result == {
	  <entryNode(),
	    stmtNode(assign(localVariable("$r1_version-0"),newInstance(TObject("java.lang.Exception"))))>,
	  
	  <stmtNode(assign(localVariable("$r1_version-0"), newInstance(TObject("java.lang.Exception")))),
	      stmtNode(invokeStmt(specialInvoke("$r1_version-0", methodSignature("java.lang.Exception",TVoid(),"\<init\>",[TObject("java.lang.String")]),[iValue(stringValue("An exception"))])))>,
	        
	  <stmtNode(invokeStmt(specialInvoke("$r1_version-0",methodSignature("java.lang.Exception",TVoid(),"\<init\>",[TObject("java.lang.String")]), [iValue(stringValue("An exception"))]))),
	      stmtNode(throwStmt(local("$r1_version-0")))>,
	
	    <stmtNode(throwStmt(local("$r1_version-0"))), exitNode()>
	};
}

private list[Method] castMethodList(ClassOrInterfaceDeclaration declaration) {
	switch(declaration[5]) {
		case list[Method] methodList : return methodList;
	}
}

private MethodBody castMethodBody(Method method) {
	switch(method[5]) {
		case MethodBody methodBody : return methodBody;
	}
}
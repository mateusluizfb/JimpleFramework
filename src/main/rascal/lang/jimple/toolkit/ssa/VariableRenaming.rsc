module lang::jimple::toolkit::ssa::VariableRenaming

import Set;
import Map;
import Relation;
import Node;
import List;
import Type;
import String;
import util::Math;

import analysis::graphs::Graph;

import lang::jimple::util::Stack;
import lang::jimple::toolkit::FlowGraph;
import lang::jimple::core::Syntax;
import lang::jimple::toolkit::ssa::DominanceTree;

map[str, Stack[int]] S = ();
map[str, int] C = ();
set[Node] REPLACED_NODES = {};
map[Node, Node] LAST_VERSION_REPLACED = ();
map[Node, list[Node]] IDOM_TREE;
map[Node, list[Node]] ADJACENCIES_MATRIX;

public FlowGraph applyVariableRenaming(FlowGraph flowGraph) {
	S = ();
	C = ();
	REPLACED_NODES = {}; // Keep tracking of all nodes replaced in one execution
	LAST_VERSION_REPLACED = (); // Keep tracking of the new version of a given node

	ADJACENCIES_MATRIX = createAdjacenciesMatrix(flowGraph); // Mainly used to rebuild the renamed flow graph
	IDOM_TREE = createIdomTree(createDominanceTree(flowGraph)); // Used to traverse the flow graph

	map[Node, list[Node]] newBlockTree = replace(entryNode()); // Start algorithm

	// Rebuild renamed flowGraph
	FlowGraph newFlowGraph = {};
	for(fatherNode <- newBlockTree) {
		newFlowGraph = newFlowGraph + { <fatherNode, nodeChild> | nodeChild <- ADJACENCIES_MATRIX[fatherNode]};
	};

	return newFlowGraph;
}

public map[Node, list[Node]] replace(Node X) {
	if((X == exitNode())) return ADJACENCIES_MATRIX;

	Node oldNode = X;

	// Deal with all nodes that aren't assigments bug uses a variable in some way
	if(isNonAssignmentStatementToRename(X)) {
		stmtNode(statement) = X;
		Node renamedStatement = stmtNode(replaceImmediateUse(statement));
		renameNodeOcurrecies(X, renamedStatement);
		X = renamedStatement;
	};

	// Deal will all nodes that are an assigment and are not renamed
	if(isOrdinaryAssignment(X) && !isRenamed(X)) {

		// Replace right hand side variables
		list[Immediate] rightHandNodeImmediates = getRightHandSideImmediates(X);
		for(rightHandSideImmediate <- rightHandNodeImmediates) {
			newAssignStmt = replaceRightVariableVersion(ADJACENCIES_MATRIX, rightHandSideImmediate, X);

			renameNodeOcurrecies(X, newAssignStmt);

			X = newAssignStmt;
		};

		// Replace left hand side variables
		if(isLeftHandSideVariable(X)) {
			Variable V = getStmtVariable(X);
			Immediate localVariableImmediate = local(V[0]);

			int assingmentQuantity = returnAssignmentQuantity(localVariableImmediate);
			newAssignStmt = replaceLeftVariableVersion(ADJACENCIES_MATRIX, X, assingmentQuantity);

			renameNodeOcurrecies(X, newAssignStmt);

			stackVariableVersion(localVariableImmediate, assingmentQuantity);
			iterateAssignmentQuantity(localVariableImmediate);
			findAndAddPhiFunctionArgs(oldNode, newAssignStmt); // Search variable uses of replaced variable in phi-function and rename it

			X = newAssignStmt;
		};
	}

	for(child <- IDOM_TREE[X]) {
		// We need to check the last version replaced because the renamed version was not beign reflected in the current `for` statement iteration
		// so we need to check the last version replaced
		nodeToRename = LAST_VERSION_REPLACED[child]? ? LAST_VERSION_REPLACED[child] : child;
		replace(nodeToRename);
	};

	if(!ignoreNode(oldNode) && isVariable(oldNode) && !isRenamed(X))
		popOldNode(oldNode);

	return ADJACENCIES_MATRIX;
}

public void findAndAddPhiFunctionArgs(Node oldNode, Node newNode) {
	Variable variable = getStmtVariable(oldNode);
	variableName = variable[0];
	dfsPhiFunctionLookupAndRename(newNode, newNode, variableName);
}

public void dfsPhiFunctionLookupAndRename(Node originalNode, Node entryNode, str variableName) {
	if(!(entryNode in ADJACENCIES_MATRIX)) return;
	if(size(ADJACENCIES_MATRIX[entryNode]) != 1) return;

	for(child <- ADJACENCIES_MATRIX[entryNode]) {
		if(child == originalNode) return;

		if(matchPhiFunction(child, variableName)) {

			oldPhiFunctionStmt = child;
			newPhiFunctionStmt = replacePhiFunctionVersion(ADJACENCIES_MATRIX, child);
			renameNodeOcurrecies(oldPhiFunctionStmt, newPhiFunctionStmt);

			return;
		};

		dfsPhiFunctionLookupAndRename(originalNode, child, variableName);
	};

	return;
}

public bool matchPhiFunction(Node variableNode, str variableName) {
	switch(variableNode){
		case stmtNode(assign(_, phiFunction(localVariable(name), _))): return name == variableName;
		case stmtNode(assign(_, phiFunction(arrayRef(name, _), _))): return name == variableName;
		default: return false;
	};
}

public void renameNodeOcurrecies(Node oldStmt, Node newStmt) {
	ADJACENCIES_MATRIX = replaceNodeOcurrenciesInTrees(ADJACENCIES_MATRIX, oldStmt, newStmt);
	IDOM_TREE = replaceNodeOcurrenciesInTrees(IDOM_TREE, oldStmt, newStmt);
	LAST_VERSION_REPLACED[oldStmt] = newStmt;
}

public map[Node, list[Node]] replaceNodeOcurrenciesInTrees(map[Node, list[Node]] blockTree, Node oldNode, Node newRenamedNode) {
	for(key <- blockTree) {
		if(oldNode in blockTree[key]) {
			blockTree[key] = blockTree[key] - [oldNode] + [newRenamedNode];
		};
	};

	blockTree[newRenamedNode] = blockTree[oldNode];
	blockTree = delete(blockTree, oldNode);
	REPLACED_NODES = REPLACED_NODES + {newRenamedNode};

	return blockTree;
}

public Statement replaceImmediateUse(Statement statement) {
	return return addEnclosingStmt(statement, replaceImmediateUse(statement[0]));
}

public Statement addEnclosingStmt(Statement statement, Expression expression) {
	statement[0] = expression;
	return statement;
}

public Statement addEnclosingStmt(Statement statement, Immediate immediate) {
	statement[0] = immediate;
	return statement;
}

public Immediate replaceImmediateUse(Immediate immediate) {
	return local(returnLastVariableVersion(immediate[0]));
}

public Expression replaceImmediateUse(Expression expression) {
	int i = 0;

	for(stmtArgument <- expression) {
		if(isSkipableStatement(stmtArgument)) {
			expression[i] = stmtArgument;
		} else {
			expression[i] = replaceImmediateUse(stmtArgument);
		};

		i = i + 1;
	};

	return expression;
}

public Name returnLastVariableVersion(str name) {
	Immediate immediate = local(name);
	variableName = getVariableImmediateName(immediate);

	int versionIndex = getVariableVersionStacked(immediate);
	str newVariableName = buildVersionName(variableName, versionIndex);

	return newVariableName;
}

public bool isReplaced(Node stmtNode) {
	return stmtNode in REPLACED_NODES;
}

public bool isSkipableStatement(stmtArgument) {
	switch(stmtArgument) {
		case str stringArgument: return true;
		case gotoStmt(_): return true;
		case iValue(_): return true;
		case caughtException(): return true;
	};

	return false;
}

public Node replacePhiFunctionVersion(map[Node, list[Node]] blockTree, Node variableNode) {
	stmtNode(assignStatement) = variableNode;
	assign(assignVariable, assignPhiFunction) = assignStatement;
	phiFunction(phiFunctionVariable, variableVersionList) = assignPhiFunction;
	variableName = phiFunctionVariable[0];
	Immediate localVariableImmediate = local(variableName);
	versionIndex = getVariableVersionStacked(localVariableImmediate);

	str newVariableName = buildVersionName(variableName, versionIndex);

	list[Variable] newVariableList = variableVersionList + [localVariable(newVariableName)];
	Node renamedPhiFunction = stmtNode(assign(assignVariable, phiFunction(phiFunctionVariable, newVariableList)));

	return renamedPhiFunction;
}

public Node replaceLeftVariableVersion(map[Node, list[Node]] blockTree, Node variableNode, int versionIndex) {
	switch(variableNode) {
		case stmtNode(assign(localVariable(localName), rhs)):
			return stmtNode(assign(localVariable(buildVersionName(localName, versionIndex)), rhs));
		case stmtNode(assign(arrayRef(arrayName, local(localName)), rhs)):
			return stmtNode(assign(arrayRef(buildVersionName(arrayName, versionIndex), local(returnCurrentVersionName(local(localName)))) , rhs));
		case stmtNode(assign(arrayRef(arrayName, immediate), rhs)):
			return stmtNode(assign(arrayRef(buildVersionName(arrayName, versionIndex), immediate), rhs));
	};
}

public Node replaceRightVariableVersion(map[Node, list[Node]] blockTree, Immediate immediateToRename, Node variableNode) {
	leftHandSide = returnLeftHandSideVariable(variableNode);
	Expression rightHandSide = returnRightHandSideExpression(variableNode);
	rightHandSide = renameExpressionVariables(rightHandSide, immediateToRename);
	return stmtNode(assign(leftHandSide, rightHandSide));
}

public Expression renameExpressionVariables(Expression expression, Immediate immediateToRename) {
	String newVersionName = returnCurrentVersionName(immediateToRename);

	switch(expression) {
		case arraySubscript(arrayName, local(localName)):
			return arraySubscript(newVersionName, local(returnCurrentVersionName(local(localName))));
	};

	list[Immediate] immediates = getExpressionImmediates(expression);
	int index = indexOf(immediates, immediateToRename);
	expression[index] = local(newVersionName);

	return expression;
}

public String returnCurrentVersionName(Immediate immediate) {
	int variableVersion = getVariableVersionStacked(immediate);
	String variableOriginalName = getImmediateName(immediate);
	return buildVersionName(variableOriginalName, variableVersion);
}

public bool isRenamed(Node assignNode) {
	if(ignoreNode(assignNode)) return false;

	stmtNode(assignStmt) = assignNode;

	switch(assignNode) {
		case stmtNode(assign(localVariable(name), _)) : return contains(name, "version");
		case stmtNode(assign(arrayRef(arrayName, _), _)): return contains(arrayName, "version");
	}
}

public str buildVersionName(str variableOriginalName, int versionIndex) {
	return variableOriginalName + "_version-" + toString(versionIndex);
}

public String getVariableName(Variable variable) {
	switch(variable[0]) {
		case String variableName: return variableName;
	}
}

public String getImmediateName(Immediate immediate) {
	switch(immediate[0]) {
		case String immediateName: return immediateName;
	}
}

public bool isLeftHandSideVariable(Node variableNode) {
	switch(variableNode) {
		case stmtNode(assign(localVariable(_), _)): return true;
		case stmtNode(assign(arrayRef(_, _), _)): return true;
		default: return false;
	}
}

public list[Immediate] getRightHandSideImmediates(Node variableNode) {
	rightHandSide = returnRightHandSideExpression(variableNode);
	typeOfVariableArg = typeOf(rightHandSide);

	if(typeOfVariableArg.name != "Expression") return [];

	list[Immediate] immediates = getExpressionImmediates(rightHandSide);
	list[Immediate] localVariableImmediates = [ immediate | immediate <- immediates, getVariableImmediateName(immediate) != ""];
	int variablesCount = size(localVariableImmediates);

	if(variablesCount != 0) return localVariableImmediates;

	return [];
}

public bool ignoreNode(Node variableNode) {
	switch(variableNode) {
		case entryNode(): return true;
		case skipNode(): return true;
		case exitNode(): return true;
		case stmtNode(gotoStmt(_)): return true;
		case stmtNode(identity(_, _, _)):  return true;
		case stmtNode(returnEmptyStmt()): return true;
		case stmtNode(returnStmt(iValue(_))): return true;
		default: return false;
	}
}

public bool isOrdinaryAssignment(Node variableNode) {
	if(ignoreNode(variableNode)) return false;

	stmtNode(statement) = variableNode;
	switch(statement) {
		case assign(_, _): return true;
		default: return false;
	}
}

public bool isPhiFunctionAssigment(Node variableNode) {
	if(ignoreNode(variableNode)) return false;

	stmtNode(assignStatement) = variableNode;
	if(size(assignStatement[..]) != 2) return false;

	possiblePhiFunction = assignStatement[1];
	switch(possiblePhiFunction) {
		case phiFunction(_, _): return true;
		case phiFunction(arrayRef(_, _), _): return false;
		default: return false;
	}
}

public Variable getStmtVariable(Node graphNode) {
	stmtNode(assignStatement) = graphNode;
	variableArg = assignStatement[0];

	switch(variableArg) {
		case Variable variable: return variable;
	}
}

public bool isVariable(Node graphNode) {
	if (size(graphNode[..]) == 0) return false;

	stmtNode(assignStatement) = graphNode;
	variableArg = assignStatement[0];
	typeOfVariableArg = typeOf(variableArg);

	if (size(typeOfVariableArg[..]) == 0) return false;

	return typeOfVariableArg.name == "Variable";
}

public bool isSameVariable(Node graphNode, Variable variable) {
	if (size(graphNode[..]) == 0) return false;

	stmtNode(assignStatement) = graphNode;
	variableArg = assignStatement[0];
	typeOfVariableArg = typeOf(variableArg);

	if (size(typeOfVariableArg[..]) == 0) return false;

	return variableArg == variable;
}

public list[Immediate] getExpressionImmediates(Expression expression) {
	switch(expression) {
	  case newInstance(Type instanceType): return [];
	  case newArray(Type baseType, list[ArrayDescriptor] dims): return [];
	  case cast(Type toType, local(name)): return [];
	  case instanceOf(Type baseType, local(name)): return [local(name)];
	  case invokeExp(_): return [];
	  case arraySubscript(Name arrayName, _): return [local(arrayName)];
	  case stringSubscript(String stringName, local(name)): return [local(stringName)];
	  case localFieldRef(Name local, Name className, Type fieldType, Name fieldName): return [];
	  case fieldRef(Name className, Type fieldType, Name fieldName): return [];
	  case and(lhs, rhs): return [lhs, rhs];
	  case or(lhs, rhs): return [lhs, rhs];
	  case xor(lhs, rhs): return [lhs, rhs];
	  case reminder(lhs, rhs): return [lhs, rhs];
	  case isNull(variable): return [variable];
	  case isNotNull(variable): return [variable];
	  case cmp(lhs, rhs): return [lhs, rhs];
	  case cmpg(lhs, rhs): return [lhs, rhs];
	  case cmpl(lhs, rhs): return [lhs, rhs];
	  case cmpeq(lhs, rhs): return [lhs, rhs];
	  case cmpne(lhs, rhs): return [lhs, rhs];
	  case cmpgt(lhs, rhs): return [lhs, rhs];
	  case cmpge(lhs, rhs): return [lhs, rhs];
	  case cmplt(lhs, rhs): return [lhs, rhs];
	  case cmple(lhs, rhs): return [lhs, rhs];
	  case shl(lhs, rhs): return [lhs, rhs];
	  case shr(lhs, rhs): return [lhs, rhs];
	  case ushr(lhs, rhs): return [lhs, rhs];
	  case plus(lhs, rhs): return [lhs, rhs];
	  case minus(lhs, rhs): return [lhs, rhs];
	  case mult(lhs, rhs): return [lhs, rhs];
	  case div(lhs, rhs): return [lhs, rhs];
	  case lengthOf(local(name)): return [local(name)];
	  case neg(local(name)): return [local(name)];
	  case immediate(local(name)): return [local(name)];
	  default: return [];
	}
}

public Variable returnLeftHandSideVariable(Node stmtNode) {
	switch(stmtNode) {
		case stmtNode(assign(leftHandSide, _)): return leftHandSide;
	}
}

public Expression returnRightHandSideExpression(Node stmtNode) {
	switch(stmtNode) {
		case stmtNode(assign(_, rightHandSide)): return rightHandSide;
	}
}

public bool isNonAssignmentStatementToRename(Node graphNode) {
	return !isReplaced(graphNode) && !isOrdinaryAssignment(graphNode) && !ignoreNode(graphNode) && !isPhiFunctionAssigment(graphNode);
}

public String getVariableImmediateName(Immediate immediate) {
	switch(immediate) {
		case local(String localName): return localName;
		default: return "";
	}
}

public int returnAssignmentQuantity(Immediate immediate) {
	str name = getVariableImmediateName(immediate);

	if(name in C) return C[name];

	C[name] = 0;
	return C[name];
}

public int iterateAssignmentQuantity(Immediate immediate) {
	str name = getVariableImmediateName(immediate);

	C[name] = C[name] + 1;

	return C[name];
}

public str stackVariableVersion(Immediate immediate, int renameIndex) {
	str name = getVariableImmediateName(immediate);

	S[name] = name in S ? push(renameIndex, S[name]) : push(0, emptyStack());

	return name;
}

public int getVariableVersionStacked(Immediate immediate) {
	str name = getVariableImmediateName(immediate);

	if(name in S) return peekIntValue(S[name]);

	S[name] = push(0, emptyStack());
	return 0;
}

public Stack[int] popOldNode(Node oldNode) {
	Variable V = getStmtVariable(oldNode);
	Immediate localVariableImmediate = local(V[0]);

	str name = getVariableImmediateName(localVariableImmediate);
	newStackTuple = pop(S[name])[1];
	S[name] = newStackTuple;

	return newStackTuple;
}

import ceylon.collection {
    MutableList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Functional,
    Unit
}

import java.util {
    List
}
shared interface ParametersCompletion<IdeComponent,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document> {

    shared formal CompletionResult newParametersCompletionProposal(Integer offset,
        String prefix, String desc, String text, List<Type> argTypes, Node node, Unit unit);
    
    // see ParametersCompletionProposal.addParametersProposal(final int offset, Node node, final List<ICompletionProposal> result, CeylonParseController cpc)
    shared void addParametersProposal(Integer offset, String prefix, Tree.Term node, MutableList<CompletionResult> result, IdeComponent cmp) {
        value condition = if (is Tree.StaticMemberOrTypeExpression node)
                          then !(node.declaration is Functional)
                          else true;
        
        if (condition, exists unit = node.unit, exists type = node.typeModel) {
            value cd = unit.callableDeclaration;
            value td = type.declaration;
            
            if (type.classOrInterface, td.equals(cd)) {
                value argTypes = unit.getCallableArgumentTypes(type);
                value paramTypes = cmp.options.parameterTypesInCompletion;
                value desc = StringBuilder().append("(");
                value text = StringBuilder().append("(");
                
                for (i in 0..argTypes.size()-1) {
                    variable value argType = argTypes.get(i);
                    if (desc.size > 1) {
                        desc.append(", ");
                    }
                    if (text.size > 1) {
                        text.append(", ");
                    }
                    if (argType.classOrInterface,
                        argType.declaration == cd) {
                        
                        String anon = 
                                anonFunctionHeader(argType, unit);
                        text.append(anon)
                                .append(" => ");
                        desc.append(anon)
                                .append(" => ");
                        argType = unit.getCallableReturnType(argType);
                        argTypes.set(i, argType);
                    }
                    else if (paramTypes) {
                        desc.append(argType.asString(unit))
                                .append(" ");
                    }
                    String name;
                    if (argType.classOrInterface
                        || argType.typeParameter) {
                        
                        String n = argType.declaration.getName(unit);
                        name = escaping.toInitialLowercase(n);
                    }
                    else {
                        name = "it";
                    }
                    text.append(name);
                    desc.append(name);

                }
                text.append(")");
                desc.append(")");

                result.add(newParametersCompletionProposal(offset, prefix,
                    desc.string, text.string, argTypes, node, unit));
            }
        }
    }
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    IdeCompletionManager,
    getRefinementTextFor,
    overloads
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    TypeParameter,
    Declaration,
    ModelUtil,
    TypeDeclaration
}

import java.util {
    LinkedHashMap,
    ArrayList,
    HashSet,
    Set
}

shared class ObjectClassDefinitionGenerator(shared actual String brokenName,
    shared actual Tree.MemberOrTypeExpression node, shared actual Tree.CompilationUnit rootNode,
    shared actual String description, shared actual Icons image, shared actual Type? returnType,
    shared actual LinkedHashMap<String,Type>? parameters,
    ImportProposals<out Anything,out Anything,out Anything,out Anything,out Anything,out Anything> importProposals,
    Indents<out Anything> indents,
    IdeCompletionManager<out Anything,out Anything,out Anything> completionManager)
        extends DefinitionGenerator() {
    
    shared actual Boolean isFormalSupported => classGenerator;
    
    Boolean isUpperCase => brokenName.first?.uppercase else false;
    
    shared actual String generateShared(String indent, String delim) {
        return "shared " + generateInternal(indent, delim, false);
    }
    shared actual String generate(String indent, String delim) {
        return generateInternal(indent, delim, false);
    }
    shared actual String generateSharedFormal(String indent, String delim) {
        return "shared formal " + generateInternal(indent, delim, true);
    }
    
    String generateInternal(String indent, String delim, Boolean isFormal) {
        value def = StringBuilder();
        value isVoid = !(returnType exists);
        if (classGenerator) {
            value typeParams = ArrayList<TypeParameter>();
            value typeParamDef = StringBuilder();
            value typeParamConstDef = StringBuilder();
            appendTypeParams2(typeParams, typeParamDef, typeParamConstDef, returnType);
            if (exists parameters) {
                appendTypeParams3(typeParams, typeParamDef, typeParamConstDef, parameters.values());
            }
            if (typeParamDef.size > 0) {
                typeParamDef.insert(0, "<");
                typeParamDef.deleteTerminal(1);
                typeParamDef.append(">");
            }
            value defIndent = indents.defaultIndent;
            value supertype = if (isVoid) then null else supertypeDeclaration(returnType);
            def.append("class ").append(brokenName).append(typeParamDef.string);
            assert (exists parameters);
            appendParameters(parameters, def, defaultedSupertype);
            if (exists supertype) {
                def.append(delim).append(indent).append(defIndent).append(defIndent).append(supertype);
            }
            def.append(typeParamConstDef.string);
            def.append(" {").append(delim);
            if (!isVoid) {
                appendMembers(indent, delim, def, defIndent);
            }
            def.append(indent).append("}");
        } else if (objectGenerator) {
            value defIndent = indents.defaultIndent;
            value supertype = if (isVoid) then null else supertypeDeclaration(returnType);
            def.append("object ").append(brokenName);
            if (exists supertype) {
                def.append(delim).append(indent).append(defIndent).append(defIndent).append(supertype);
            }
            def.append(" {").append(delim);
            if (!isVoid) {
                appendMembers(indent, delim, def, defIndent);
            }
            def.append(indent).append("}");
        } else {
            return "<error!>";
        }
        return def.string;
    }
    
    Boolean classGenerator {
        return isUpperCase && parameters exists;
    }
    
    Boolean objectGenerator {
        return !isUpperCase && !parameters exists;
    }
    
    shared actual Set<Declaration> getImports() {
        value imports = HashSet<Declaration>();
        importProposals.importType(imports, returnType, rootNode);
        if (exists parameters) {
            importProposals.importTypes(imports, parameters.values(), rootNode);
        }
        if (exists returnType) {
            importMembers(imports);
        }
        return imports;
    }
    
    void importMembers(Set<Declaration> imports) {
        //TODO: this is a major copy/paste from appendMembers() below
        value td = defaultedSupertype;
        value ambiguousNames = HashSet<String>();
        value unit = rootNode.unit;
        value members = td.getMatchingMemberDeclarations(unit, null, "", 0).values();
        for (dwp in members) {
            value dec = dwp.declaration;
            for (d in overloads(dec)) {
                if (d.formal /*&& td.isInheritedFromSupertype(d)*/) {
                    importProposals.importSignatureTypes(d, rootNode, imports);
                    ambiguousNames.add(d.name);
                }
            }
        }
        for (superType in td.supertypeDeclarations) {
            for (m in superType.members) {
                if (m.shared) {
                    Declaration? r = td.getMember(m.name, null, false);
                    if (!(r?.refines(m) else false),
                        // !r.getContainer().equals(ut) &&  
                        !ambiguousNames.add(m.name)) {
                        
                        importProposals.importSignatureTypes(m, rootNode, imports);
                    }
                }
            }
        }
    }
    
    void appendMembers(String indent, String delim, StringBuilder def, String defIndent) {
        value td = defaultedSupertype;
        value ambiguousNames = HashSet<String>();
        value unit = rootNode.unit;
        value members = td.getMatchingMemberDeclarations(unit, null, "", 0).values();
        for (dwp in members) {
            value dec = dwp.declaration;
            if (ambiguousNames.add(dec.name)) {
                for (d in overloads(dec)) {
                    if (d.formal /*&& td.isInheritedFromSupertype(d)*/) {
                        appendRefinementText(indent, delim, def, defIndent, d);
                    }
                }
            }
        }
        for (superType in td.supertypeDeclarations) {
            for (m in superType.members) {
                if (m.shared) {
                    Declaration? r = td.getMember(m.name, null, false);
                    if (!(r?.refines(m) else false),
                        // !r.getContainer().equals(ut)) && 
                        ambiguousNames.add(m.name)) {
                        
                        appendRefinementText(indent, delim, def, defIndent, m);
                    }
                }
            }
        }
    }
    
    TypeDeclaration defaultedSupertype {
        if (isNotBasic(returnType), exists returnType) {
            return returnType.declaration;
        } else {
            value unit = rootNode.unit;
            return ModelUtil.intersectionType(returnType, unit.basicType, unit).declaration;
        }
    }
    
    void appendRefinementText(String indent, String delim, StringBuilder def, String defIndent, Declaration d) {
        assert (exists returnType);
        value pr = completionManager.getRefinedProducedReference(returnType, d);
        value unit = node.unit;
        variable value text = getRefinementTextFor(d, pr, unit, false, null, "", false, true, indents, false);
        if (exists parameters, parameters.containsKey(d.name)) {
            text = text.spanTo((text.firstInclusion(" =>") else 0) - 1) + ";";
        }
        def.append(indent).append(defIndent).append(text).append(delim);
    }
    
    Boolean isNotBasic(Type? returnType) {
        if (ModelUtil.isTypeUnknown(returnType)) {
            return false;
        } else if (exists returnType) {
            value rtd = returnType.declaration;
            value bd = rtd.unit.basicDeclaration;
            if (returnType.\iclass) {
                return rtd.inherits(bd);
            } else if (returnType.\iinterface) {
                return false;
            } else if (returnType.intersection) {
                for (st in returnType.satisfiedTypes) {
                    if (st.\iclass) {
                        return rtd.inherits(bd);
                    }
                }
                return false;
            }
        }
        return false;
    }
}

String? supertypeDeclaration(Type? returnType) {
    if (ModelUtil.isTypeUnknown(returnType)) {
        return null;
    } else if (exists returnType) {
        if (returnType.\iclass) {
            return " extends " + returnType.asString() + "()"; //TODO: supertype arguments!
        } else if (returnType.\iinterface) {
            return " satisfies " + returnType.asString();
        } else if (returnType.intersection) {
            variable value extendsClause = "";
            value satisfiesClause = StringBuilder();
            for (st in returnType.satisfiedTypes) {
                if (st.\iclass) {
                    extendsClause = " extends " + st.asString() + "()"; //TODO: supertype arguments!
                } else if (st.\iinterface) {
                    if (satisfiesClause.empty) {
                        satisfiesClause.append(" satisfies ");
                    } else {
                        satisfiesClause.append(" & ");
                    }
                    satisfiesClause.append(st.asString());
                }
            }
            return extendsClause + satisfiesClause.string;
        }
    }
    return null;
}

Boolean isValidSupertype(Type? returnType) {
    if (ModelUtil.isTypeUnknown(returnType)) {
        return true;
    } else if (exists returnType) {
        if (exists r = returnType.caseTypes) {
            return false;
        }
        value rtd = returnType.declaration;
        if (returnType.\iclass) {
            return !rtd.final;
        } else if (returnType.\iinterface) {
            value cd = rtd.unit.callableDeclaration;
            return !rtd.equals(cd);
        } else if (returnType.intersection) {
            for (st in returnType.satisfiedTypes) {
                if (!isValidSupertype(st)) {
                    return false;
                }
            }
            return true;
        }
    }
    return false;
}

ObjectClassDefinitionGenerator? createObjectClassDefinitionGenerator(String brokenName, 
    Tree.MemberOrTypeExpression node, Tree.CompilationUnit rootNode,
    ImportProposals<out Anything,out Anything,out Anything,out Anything,out Anything,out Anything> importProposals,
    Indents<out Anything> indents,
    IdeCompletionManager<out Anything,out Anything,out Anything> completionManager) {
    
    value isUpperCase = brokenName.first?.uppercase else false;
    value fav = FindArgumentsVisitor(node);
    rootNode.visit(fav);
    value unit = node.unit;
    variable Type? returnType = unit.denotableType(fav.expectedType);
    //value params = StringBuilder();
    value paramTypes = getParameters(fav);
    if (exists rt = returnType) {
        if (unit.isOptionalType(rt)) {
            returnType = rt.eliminateNull();
        }
        if (rt.\iobject || rt.anything) {
            returnType = null;
        }
    }
    if (!isValidSupertype(returnType)) {
        return null;
    }
    if (exists paramTypes, isUpperCase) {
        value supertype = supertypeDeclaration(returnType) else "";
        value desc = "'class " + brokenName + supertype + "'";
        return ObjectClassDefinitionGenerator(brokenName, node, rootNode, desc, Icons.localClass, returnType, paramTypes,
            importProposals, indents, completionManager);
    } else if (!exists paramTypes, !isUpperCase) {
        value desc = "'object " + brokenName + "'";
        return ObjectClassDefinitionGenerator(brokenName, node, rootNode, desc, Icons.localAttribute, returnType, null,
            importProposals, indents, completionManager);
    } else {
        return null;
    }
}

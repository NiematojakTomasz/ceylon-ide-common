import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    ParameterList,
    Value,
    Unit,
    Declaration,
    Package,
    Module
}
import java.util {
    List,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

Boolean isLocation(OccurrenceLocation? loc1, OccurrenceLocation loc2) {
    if (exists loc1) {
        return loc1 == loc2;
    }
    return false;
}

// see CompletionUtil.getParameters
List<Parameter> getParameters(ParameterList pl,
    Boolean includeDefaults, Boolean namedInvocation) {
    List<Parameter> ps = pl.parameters;
    if (includeDefaults) {
        return ps;
    }
    else {
        List<Parameter> list = ArrayList<Parameter>();
        for (p in CeylonIterable(ps)) {
            if (!p.defaulted || 
                (namedInvocation && 
                p==ps.get(ps.size()-1) && 
                    p.model is Value &&
                    p.type exists &&
                    p.declaration.unit
                    .isIterableParameterType(p.type))) {
                list.add(p);
            }
        }
        return list;
    }
}

Boolean isModuleDescriptor(Tree.CompilationUnit? cu)
    => (cu?.unit?.filename else "") == "module.ceylon";

Boolean isPackageDescriptor(Tree.CompilationUnit? cu)
        => (cu?.unit?.filename else "") == "package.ceylon";

String getTextForDocLink(Unit? unit, Declaration decl) {
    Package? pkg = decl.unit.\ipackage;
    String qname = decl.qualifiedNameString;
    
    if (exists pkg, (Module.\iLANGUAGE_MODULE_NAME.equals(pkg.nameAsString) || (if (exists unit) then pkg.equals(unit.\ipackage) else false))) {
        if (decl.toplevel) {
            return decl.nameAsString;
        } else {
            if (exists loc = qname.firstOccurrence("::")) {
                return qname.spanFrom(loc + 2);
            } else {
                return qname;
            }
        }
    } else {
        return qname;
    }
}


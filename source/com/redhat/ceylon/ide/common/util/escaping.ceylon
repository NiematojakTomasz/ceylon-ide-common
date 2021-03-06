import com.redhat.ceylon.model.typechecker.model {
    Package,
    DeclarationWithProximity,
    Declaration,
    TypedDeclaration,
    TypeDeclaration,
    Unit
}

import java.lang {
    JString=String
}


shared object escaping {
    
    shared {String+} keywords = {"import", "assert",
        "alias", "class", "interface", "object", "given", "value", "assign", "void", "function", 
        "assembly", "module", "package", "of", "extends", "satisfies", "abstracts", "in", "out", 
        "return", "break", "continue", "throw", "if", "else", "switch", "case", "for", "while", 
        "try", "catch", "finally", "this", "outer", "super", "is", "exists", "nonempty", "then",
        "dynamic", "new", "let"};
    
    shared String concatenateKeywords(String delim)
        => delim.join(keywords);
    
    shared Boolean isKeyword(String|JString identifier) 
            => identifier.string in keywords;
    
    shared String escape(String name)
            => if (name in keywords)
                then "\\i``name``"
                else name;
    
    shared String escapePackageName(Package p) {
        value path = p.name;
        value sb = StringBuilder();
        
        for (pathPart in toCeylonStringIterable(path)) {
            if (!pathPart.empty) {
                sb.append(escape(pathPart));
                sb.append(".");
            }
        }
        
        if (sb.endsWith(".")) {
            sb.deleteTerminal(1);
        }
        
        return sb.string;
    }
    
    shared String escapeName(DeclarationWithProximity|Declaration d, Unit? unit = null) {
        switch (d)
        case (is DeclarationWithProximity) {
            return escapeAliasedName(d.declaration, d.name);
        }
        else {
            value name = if (exists unit) then d.getName(unit) else d.name;
            return escapeAliasedName(d, name);
        }
    }
    
    shared String escapeAliasedName(Declaration d, String? aliass) {
        if (!exists aliass) {
            return "";
        }
        else {
            assert (exists c = aliass.first);
            if (is TypedDeclaration d, 
                    c.uppercase || aliass in keywords) {
                return "\\i``aliass``";
            }
            else if (is TypeDeclaration d, 
                    c.lowercase && !d.anonymous) {
                return "\\I``aliass``";
            }
            else {
                return aliass;
            }
        }
    }

    shared String toInitialLowercase(String name) {
        value first = name.first;
        
        return if (exists first)
            then first.lowercased.string + name.spanFrom(1)
            else name;
    }
    
    shared String toInitialUppercase(String name) {
        value first = name.first;
        
        return if (exists first)
            then first.uppercased.string + name.spanFrom(1)
            else name;
    }
}
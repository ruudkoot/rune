 fun termAttributes term=F.defer(fn()=>case force term of
    Sym(i,j,types,attrs)=>attrs
   |App(a,b,types,attrs)=>attrs
   |PairTerm(a,b,c,types,attrs)=>attrs
   |Constant(kind,types,attrs)=>attrs
   |Binder(kind,dec,body,types,attrs)=>attrs
   |Unary(kind,body,types,attrs)=>attrs
   |Binary(kind,a,b,types,attrs)=>attrs
   |Cond(dec,a,b,types,attrs)=>attrs
   |Const(i,j,k,types,attrs)=>attrs
   |Recurse(terms,body,types,attrs)=>attrs|_=>raise Match)
 fun replaceAttributes term attrs:itr=D.delay(fn()=>case force term of
    Sym(i,j,types,_)=>Sym(i,j,types,attrs)
   |App(a,b,types,_)=>App(a,b,types,attrs)
   |PairTerm(a,b,c,types,_)=>PairTerm(a,b,c,types,attrs)
   |Constant(kind,types,_)=>Constant(kind,types,attrs)
   |Binder(kind,dec,body,types,_)=>Binder(kind,dec,body,types,attrs)
   |Unary(kind,body,types,_)=>Unary(kind,body,types,attrs)
   |Binary(kind,a,b,types,_)=>Binary(kind,a,b,types,attrs)
   |Cond(dec,a,b,types,_)=>Cond(dec,a,b,types,attrs)
   |Const(i,j,k,types,_)=>Const(i,j,k,types,attrs)
   |Recurse(terms,body,types,_)=>Recurse(terms,body,types,attrs)|_=>raise Match)
 fun addType term ty:itr=D.delay(fn()=>case force term of
    Sym(i,j,types,attrs)=>Sym(i,j,F.cons(ty,types),attrs)
   |App(a,b,types,attrs)=>App(a,b,F.cons(ty,types),attrs)
   |PairTerm(a,b,c,types,attrs)=>PairTerm(a,b,c,F.cons(ty,types),attrs)
   |Constant(kind,types,attrs)=>Constant(kind,F.cons(ty,types),attrs)
   |Binder(kind,dec,body,types,attrs)=>Binder(kind,dec,body,F.cons(ty,types),attrs)
   |Unary(kind,body,types,attrs)=>Unary(kind,body,F.cons(ty,types),attrs)
   |Binary(kind,a,b,types,attrs)=>Binary(kind,a,b,F.cons(ty,types),attrs)
   |Cond(dec,a,b,types,attrs)=>Cond(dec,a,b,F.cons(ty,types),attrs)
   |Const(i,j,k,types,attrs)=>Const(i,j,k,F.cons(ty,types),attrs)
   |Recurse(terms,body,types,attrs)=>Recurse(terms,body,F.cons(ty,types),attrs)|_=>raise Match)

 fun getTermAttributes term indices=
   let val selected=selectTerm term indices
       val selectedTerm=D.delay(fn()=>force(#1(L.force selected)))
   in termAttributes selectedTerm end
 fun setTermAttributes term indices attributes=
   let val selected=selectTerm term indices
       val subterm=D.delay(fn()=>force(#1(L.force selected)))
   in replaceTerm term indices(replaceAttributes subterm attributes)end
 fun declarationAttributes dec=F.defer(fn()=>case force dec of
    SymbolDec(_,attrs)=>attrs|AxiomDec(_,attrs)=>attrs|Def(_,_,attrs)=>attrs|Data(_,_,attrs)=>attrs|DecPair(_,_,attrs)=>attrs)
 fun setDeclarationAttributes dec attrs:idec=D.delay(fn()=>case force dec of
    SymbolDec(term,_)=>SymbolDec(term,attrs)|AxiomDec(term,_)=>AxiomDec(term,attrs)
   |Def(a,b,_)=>Def(a,b,attrs)|Data(decs,terms,_)=>Data(decs,terms,attrs)|DecPair(a,b,_)=>DecPair(a,b,attrs))
 fun signatureAttributes signatureValue=F.defer(fn()=>case force signatureValue of
    EmptySig attrs=>attrs|Extend(_,_,attrs)=>attrs|Combine(_,_,_,_,attrs)=>attrs|Share(_,_,_,_,_,attrs)=>attrs)
 fun setSignatureAttributes signatureValue attrs:isgn=D.delay(fn()=>case force signatureValue of
    EmptySig _=>EmptySig attrs|Extend(dec,sg,_)=>Extend(dec,sg,attrs)
   |Combine(a,b,k,map,_)=>Combine(a,b,k,map,attrs)|Share(sg,i,j,k,map,_)=>Share(sg,i,j,k,map,attrs))
 fun subSignature first second=
   let fun sub index signatureValue=D.delay(fn()=>if equalSignature first signatureValue then SomeValue index
         else case force signatureValue of EmptySig _=>NoValue
          |Extend(_,rest,_)=>force(sub(add index(int 1))rest)
          |Combine(a,b,k,_,_)=>(case force(sub index b)of SomeValue found=>SomeValue found|NoValue=>force(sub(add index k)a))
          |Share(rest,_,_,_,_,_)=>force(sub index rest))
   in sub(int 0)second end


 fun shareMap signatureValue=
   let fun shared signatureValue n=F.defer(fn()=>case force signatureValue of
         Share(_,_,_,_,indices,_)=>F.append(range(int 0)(subtract n(int 1)))(map(fn i=>D.delay(fn()=> ~(force i)))indices)
        |Combine(_,_,_,indices,_)=>F.append(range(int 0)(subtract n(int 1)))(map(fn i=>D.delay(fn()=> ~(force i)))indices)
        |EmptySig _=>range(int 0)(subtract n(int 1))
        |Extend(_,rest,_)=>shared rest(add n(int 1)))
   in shared signatureValue(int 0)end
 fun canonicalIndex indices index=D.delay(fn()=>force(if null indices then index else nth indices index))
 fun shareSymbol indices depth i j types attrs=cell(Sym(add depth(canonicalIndex indices(subtract i depth)),j,types,attrs))
 fun shareConstructor indices depth i j k types attrs=cell(Const(add depth(canonicalIndex indices(subtract i depth)),j,k,types,attrs))
 fun shiftSymbol indices offset depth i j types attrs=shareSymbol indices depth(add i offset)j types attrs
 fun shiftConstructor indices offset depth i j k types attrs=shareConstructor indices depth(add i offset)j k types attrs
 fun shareTerm indices term=
   let val(terms,_)=mapSymbols(shareSymbol indices)(shareConstructor indices)in terms term end
 fun shiftTerm indices offset term=
   let val(terms,_)=mapSymbols(shiftSymbol indices offset)(shiftConstructor indices offset)in terms term end
 fun shiftDeclaration indices offset dec=
   let val(_,decs)=mapSymbols(shiftSymbol indices offset)(shiftConstructor indices offset)in decs dec end
 fun substitutionTable index dec term=L.delay(fn()=>case(force dec,force term)of
    (DecPair(a,b,_),PairTerm(x,y,_,_,_))=>
       let val first=substitutionTable(add index(int 1))a x
           val firstIndex=D.delay(fn()=>force(#1(L.force first)))
           val firstTable=F.defer(fn()=> #2(L.force first))
           val second=substitutionTable(add firstIndex(int 1))b y
           val finalIndex=D.delay(fn()=>force(#1(L.force second)))
           val secondTable=F.defer(fn()=> #2(L.force second))
       in(finalIndex,F.append firstTable secondTable)end
   |(SymbolDec _,_)=>(index,singleton(pair index term))|_=>raise Match)
 fun substituteSymbol table depth i j types attrs:itr=D.delay(fn()=>
    if equalInt i depth then case force(lookup equalInt j table)of SomeValue term=>force(shiftTerm(F.empty())depth term)|_=>raise Match
    else Sym(subtract i(int 1),j,types,attrs))
 fun substituteConstructor depth i j k types attrs=cell(Const(subtract i(int 1),j,k,types,attrs))
 fun substituteTerm dec original replacement=
   let val result=substitutionTable(int 0)dec replacement
       val table=F.defer(fn()=> #2(L.force result))
       val(terms,_)=mapSymbols(substituteSymbol table)substituteConstructor
   in terms original end
 fun substituteDeclaration first second replacement=
   let val result=substitutionTable(int 0)first replacement
       val table=F.defer(fn()=> #2(L.force result))
       val(_,decs)=mapSymbols(substituteSymbol table)substituteConstructor
   in decs second end
 fun extractionIndices declaration index=
   let fun extract index dec j path stack=F.defer(fn()=>if equalInt index(int 0)then path
        else case force dec of DecPair(a,b,_)=>extract(subtract index(int 1))a(add j(int 1))path
              (F.cons(pair b(F.cons(add j(int 1),path)),stack))
          |_=>case force stack of F.Cons(entry,rest)=>let val(next,path)=force entry
              in extract(subtract index(int 1))next(add j(int 1))path rest end|_=>raise Match)
   in extract index declaration(int 0)(F.empty())(F.empty())end
 fun uncurrySymbol indices decDepth localDepth i j types attrs=
   if less(subtract i localDepth)decDepth then cell(Sym(localDepth,add j(nth indices i),types,attrs))
     else cell(Sym(add(subtract i decDepth)(int 1),j,types,attrs))
 fun uncurryConstructor indices decDepth localDepth i j k types attrs=
   if less(subtract i localDepth)decDepth then cell(Const(localDepth,add j(nth indices i),k,types,attrs))
     else cell(Const(add(subtract i decDepth)(int 1),j,k,types,attrs))
 fun uncurryTerm dec index term=
   let val indices=extractionIndices dec index
       val depth=length indices
       val(terms,_)=mapSymbols(uncurrySymbol indices depth)(uncurryConstructor indices depth)
   in terms term end
 fun extractDeclaration index dec:idec=D.delay(fn()=>
   let fun extract index dec stack=case force dec of
          DecPair(a,b,_)=>extract(subtract index(int 1))a(F.cons(b,stack))
         |_=>if equalInt index(int 0)then force dec else case force stack of F.Cons(next,rest)=>
             extract(subtract index(int 1))next rest|_=>raise Match
   in extract index dec(F.empty())end)
 fun remakeType original path replacement:itr=D.delay(fn()=>case force original of Binder(q,dec,body,types,attrs)=>
   (case force path of F.Nil=>force(substituteTerm dec body replacement)
     |F.Cons(_,rest)=>Binder(q,dec,remakeType body rest replacement,types,attrs))|_=>raise Match)
 fun isSymbolDeclaration dec=case force dec of SymbolDec _=>true
   |DecPair(a,b,_)=>isSymbolDeclaration a andalso isSymbolDeclaration b|_=>false
 fun isAxiomDeclaration dec=case force dec of AxiomDec _=>true
   |DecPair(a,b,_)=>isAxiomDeclaration a andalso isAxiomDeclaration b|_=>false
 fun isDefinitionDeclaration dec=case force dec of Def _=>true
   |DecPair(a,b,_)=>isDefinitionDeclaration a andalso isDefinitionDeclaration b|_=>false
 fun declarationType dec:itr=D.delay(fn()=>case force dec of
    SymbolDec(body,_)=>force body|AxiomDec(body,_)=>force body
   |DecPair(a,b,_)=>if isSymbolDeclaration dec then Binder(SigmaB,a,declarationType b,F.empty(),F.empty())
        else if isAxiomDeclaration dec then Binary(AndB,declarationType a,
             shiftTerm(F.empty())(int ~1)(declarationType b),F.empty(),F.empty())
        else Sym(int 0,int 0,F.empty(),F.empty())|_=>raise Match)
 fun makePi dec term=cell(Binder(PiB,dec,term,F.empty(),F.empty()))
 fun functionSpace first second=cell(Binder(PiB,cell(SymbolDec(first,F.empty())),
      shiftTerm(F.empty())(int 1)second,F.empty(),F.empty()))
 fun makeSymbols dec i j=L.delay(fn()=>case force dec of
    SymbolDec _=>(cell(Sym(i,j,F.empty(),F.empty())),add j(int 1))
   |DecPair(a,b,_)=>let val first=makeSymbols a i(add j(int 1))
        val term1=D.delay(fn()=>force(#1(L.force first)))
        val next1=D.delay(fn()=>force(#2(L.force first)))
        val second=makeSymbols b i next1
        val term2=D.delay(fn()=>force(#1(L.force second)))
        val next2=D.delay(fn()=>force(#2(L.force second)))
     in(cell(PairTerm(term1,term2,declarationType dec,F.empty(),F.empty())),next2)end
   |_=>raise Match)
 fun makeSymbolList declarations index terms=F.defer(fn()=>case force declarations of F.Nil=>terms
   |F.Cons(dec,rest)=>
      let val result=makeSymbols dec index(int 0)
          val term=D.delay(fn()=>force(#1(L.force result)))
      in makeSymbolList rest(add index(int 1))(F.cons(term,terms))end)

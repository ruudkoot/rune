
 fun replaceAt index values value=F.defer(fn()=>case force values of F.Nil=>raise Match
   |F.Cons(x,rest)=>if equalInt index(int 0)then F.cons(value,rest)
       else F.cons(x,replaceAt(subtract index(int 1))rest value))
 fun replaceTerm original indices replacement=
   let fun termAt indices term:itr=D.delay(fn()=>case force indices of F.Nil=>force replacement
        |F.Cons(index,rest)=>case force term of
           App(a,b,types,attrs)=>if equalInt index(int 0)then App(termAt rest a,b,types,attrs)
                else if equalInt index(int 1)then App(a,termAt rest b,types,attrs)else raise Match
          |PairTerm(a,b,c,types,attrs)=>if equalInt index(int 0)then PairTerm(termAt rest a,b,c,types,attrs)
                else if equalInt index(int 1)then PairTerm(a,termAt rest b,c,types,attrs)else raise Match
          |Binder(q,dec,body,types,attrs)=>if equalInt index(int 0)then Binder(q,decAt rest dec,body,types,attrs)
                else if equalInt index(int 1)then Binder(q,dec,termAt rest body,types,attrs)else raise Match
          |Unary(c,body,types,attrs)=>if equalInt index(int 0)then Unary(c,termAt rest body,types,attrs)else raise Match
          |Binary(c,a,b,types,attrs)=>if equalInt index(int 0)then Binary(c,termAt rest a,b,types,attrs)
                else if equalInt index(int 1)then Binary(c,a,termAt rest b,types,attrs)else raise Match
          |Cond(dec,a,b,types,attrs)=>if equalInt index(int 0)then Cond(decAt rest dec,a,b,types,attrs)
                else if equalInt index(int 1)then Cond(dec,termAt rest a,b,types,attrs)
                else if equalInt index(int 2)then Cond(dec,a,termAt rest b,types,attrs)else raise Match
          |Recurse(terms,body,types,attrs)=>Recurse(replaceAt index terms(termAt rest(nth terms index)),body,types,attrs)
          |_=>raise Fail("iL(len):"^Int.toString(force(length indices))^"\niL:"^
                  String.concat(List.map Int.toString(F.toList indices))^"|"))
       and decAt indices dec:idec=D.delay(fn()=>case force indices of F.Nil=>raise Match
         |F.Cons(index,rest)=>case force dec of
             SymbolDec(body,attrs)=>if equalInt index(int 0)then SymbolDec(termAt rest body,attrs)else raise Match
            |AxiomDec(body,attrs)=>if equalInt index(int 0)then AxiomDec(termAt rest body,attrs)else raise Match
            |DecPair(a,b,attrs)=>if equalInt index(int 0)then DecPair(decAt rest a,b,attrs)
                 else if equalInt index(int 1)then DecPair(a,decAt rest b,attrs)else raise Match
            |_=>raise Match)
   in termAt indices original end
 fun mapSymbols symbol constructor=
   let fun termAt n term:itr=D.delay(fn()=>case force term of
          Sym(i,j,types,attrs)=>if less i n then Sym(i,j,map(termAt n)types,attrs)
               else force(symbol n i j(map(termAt n)types)attrs)
         |Const(i,j,k,types,attrs)=>if less i n then Const(i,j,k,map(termAt n)types,attrs)
               else force(constructor n i j k(map(termAt n)types)attrs)
         |Constant(c,types,attrs)=>Constant(c,map(termAt n)types,attrs)
         |App(a,b,types,attrs)=>App(termAt n a,termAt n b,map(termAt n)types,attrs)
         |PairTerm(a,b,c,types,attrs)=>PairTerm(termAt n a,termAt n b,termAt n c,map(termAt n)types,attrs)
         |Binder(q,dec,body,types,attrs)=>Binder(q,decAt n dec,termAt(add n(int 1))body,map(termAt n)types,attrs)
         |Unary(c,body,types,attrs)=>Unary(c,termAt n body,map(termAt n)types,attrs)
         |Binary(c,a,b,types,attrs)=>Binary(c,termAt n a,termAt n b,map(termAt n)types,attrs)
         |Cond(dec,a,b,types,attrs)=>Cond(decAt n dec,termAt(add n(int 1))a,
               termAt(add n(int 1))b,map(termAt n)types,attrs)
         |Recurse(terms,body,types,attrs)=>Recurse(map(termAt n)terms,termAt n body,map(termAt n)types,attrs)
         |TagId _=>force term|ITermError _=>force term)
       and decAt n dec:idec=D.delay(fn()=>case force dec of
          SymbolDec(body,attrs)=>SymbolDec(termAt n body,attrs)
         |AxiomDec(body,attrs)=>AxiomDec(termAt n body,attrs)
         |DecPair(a,b,attrs)=>DecPair(decAt n a,decAt(add n(int 1))b,attrs)
         |Def(a,b,attrs)=>Def(termAt n a,termAt n b,attrs)
         |Data(declarations,terms,attrs)=>
            let val result=dataAt n declarations terms attrs
                val ds=F.defer(fn()=>let val(ds,_,_)=L.force result in ds end)
                val terms=F.defer(fn()=>let val(_,terms,_)=L.force result in terms end)
                val attrs=F.defer(fn()=>let val(_,_,attrs)=L.force result in attrs end)
            in Data(ds,terms,attrs)end)
       and dataAt n declarations terms attrs=L.delay(fn()=>case force declarations of
          F.Nil=>(F.empty(),map(map(termAt(add n(int 1))))terms,attrs)
         |F.Cons(dec,rest)=>
            let val following=dataAt(add n(int 1))rest terms attrs
                val terms=F.defer(fn()=>let val(_,terms,_)=L.force following in terms end)
                val attrs=F.defer(fn()=>let val(_,_,attrs)=L.force following in attrs end)
            (* Original keeps rest, not its separately computed dcL1. *)
            in(F.cons(decAt n dec,rest),terms,attrs)end)
   in(termAt(int 0),decAt(int 0))end
 fun nthSignature index signatureValue:isgn=D.delay(fn()=>if equalInt index(int 0)then force signatureValue
   else case force signatureValue of Extend(_,rest,_)=>force(nthSignature(subtract index(int 1))rest)
      |Combine(first,second,k,_,_)=>force(if less index k then nthSignature(subtract index(int 1))second
          else nthSignature(subtract(subtract index k)(int 1))first)
      |Share(rest,_,_,_,_,_)=>force(nthSignature(subtract index(int 1))rest)|_=>raise Match)
 fun nthDeclaration index signatureValue:idec=D.delay(fn()=>case force(nthSignature index signatureValue)of
     Extend(dec,_,_)=>force dec|_=>raise Match)
 fun signatureLength signatureValue:integer=D.delay(fn()=>case force signatureValue of EmptySig _=>0
    |Extend(_,rest,_)=>1+force(signatureLength rest)
    |Combine(first,_,k,_,_)=>1+force k+force(signatureLength first)
    |Share(rest,_,_,_,_,_)=>1+force(signatureLength rest))

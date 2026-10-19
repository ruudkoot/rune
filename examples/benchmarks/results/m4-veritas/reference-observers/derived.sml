
 fun findTerms predicate function term=L.delay(fn()=>
   let fun find depth path term=F.defer(fn()=>if predicate depth term then singleton(pair depth path)else children depth path term)
       and children depth path term=F.defer(fn()=>case force term of
          App(a,b,_,_)=>F.append(find depth(appendLast path(int 0))a)(find depth(appendLast path(int 1))b)
         |PairTerm(a,b,c,_,_)=>concat(fromNative[find depth(appendLast path(int 0))a,
              find depth(appendLast path(int 1))b,find depth(appendLast path(int 2))c])
         |Binder(_,dec,body,_,_)=>F.append(declaration depth(appendLast path(int 0))dec)
              (find(add depth(int 1))(appendLast path(int 1))body)
         |Unary(_,body,_,_)=>find depth(appendLast path(int 0))body
         |Binary(_,a,b,_,_)=>F.append(find depth(appendLast path(int 0))a)(find depth(appendLast path(int 1))b)
         |Cond(dec,a,b,_,_)=>concat(fromNative[declaration depth(appendLast path(int 0))dec,
              find(add depth(int 1))(appendLast path(int 1))a,find(add depth(int 1))(appendLast path(int 2))b])
         |Recurse(terms,_,_,_)=>
              let fun loop index terms=F.defer(fn()=>case force terms of F.Nil=>F.empty()|F.Cons(term,rest)=>
                    F.append(find depth(appendLast path index)term)(loop(add index(int 1))rest))
              in loop(int 0)terms end
         |_=>F.empty())
       and declaration depth path dec=F.defer(fn()=>case force dec of SymbolDec(term,_)=>find depth(appendLast path(int 0))term
          |AxiomDec(term,_)=>find depth(appendLast path(int 0))term|_=>F.empty())
       val locations=find(int 0)(F.empty())term
       fun apply term location=let val(depth,path)=force location
           val(selected,_)=L.force(selectTerm term path)
         in replaceTerm term path(function depth selected)end
       val changed=foldLeft apply term locations
       val paths=map(fn entry=>let val(_,path)=force entry in path end)locations
   in(changed,paths)end)
 fun findBetas term=
   let fun predicate _ term=case force term of App(function,_,_,_)=>
           (case force function of Binder(LambdaB,_,_,_,_)=>true|_=>false)|_=>false
       fun reduce _ term:itr=D.delay(fn()=>case force term of App(function,argument,_,_)=>
           (case force function of Binder(LambdaB,dec,body,_,_)=>force(substituteTerm dec body argument)|_=>raise Match)|_=>raise Match)
   in findTerms predicate reduce term end
 fun repeatBeta theorem paths=foldLeft betaRewrite theorem paths
 val conjunctionSchema:itr L.delay=L.delay(fn()=>
   let fun sym n=cell(Sym(int n,int 0,F.empty(),F.empty()))
       fun dec term=cell(SymbolDec(term,F.empty()))
       val body=bareBinary AndB(sym 3)(sym 2)
       val body=bareBinder ImpB(dec(sym 1))(bareBinder ImpB(dec(sym 1))body)
   in bareBinder ForallB(dec(bareConstant BoolType))(bareBinder ForallB(dec(bareConstant BoolType))body)end)
 val disjunctionSchema:itr L.delay=L.delay(fn()=>
   let fun sym n=cell(Sym(int n,int 0,F.empty(),F.empty()))
       fun dec term=cell(SymbolDec(term,F.empty()))
       val body=sym 3
       val body=bareBinder ImpB(dec(bareBinder ImpB(dec(sym 3))(sym 3)))body
       val body=bareBinder ImpB(dec(bareBinder ImpB(dec(sym 3))(sym 2)))body
       val body=bareBinder ImpB(dec(bareBinary OrB(sym 2)(sym 1)))body
   in bareBinder ForallB(dec(bareConstant BoolType))(bareBinder ForallB(dec(bareConstant BoolType))
       (bareBinder ForallB(dec(bareConstant BoolType))body))end)
 val conjunctionTheorem:theorem L.delay=L.delay(fn()=>tautology(buildITerm emptySignature(L.force conjunctionSchema)))
 val disjunctionTheorem:theorem L.delay=L.delay(fn()=>tautology(buildITerm emptySignature(L.force disjunctionSchema)))
 fun deriveConjunction first second=
   let val signatureValue=theoremSignature first
       val specialized=specialize(weaken signatureValue(L.force conjunctionTheorem))(wrappedTheoremType first)
       val specialized=specialize specialized(wrappedTheoremType second)
   in modusPonens(modusPonens specialized first)second end
 fun deriveDisjunction first second third=
   let val signatureValue=theoremSignature first
       (* The source's local th3 shadows its third parameter. *)
       val localThird=specialize(weaken signatureValue(L.force disjunctionTheorem))(wrappedTheoremType first)
       val fourth=specialize localThird(wrappedTheoremType second)
       val fifth=specialize fourth(wrappedTheoremType localThird)
   in modusPonens(modusPonens(modusPonens fifth first)second)localThird end

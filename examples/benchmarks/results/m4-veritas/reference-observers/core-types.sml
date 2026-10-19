
 fun selectSymbolType symbol signatureValue i j:itr=D.delay(fn()=>
   let val dec=nthDeclaration i signatureValue
       fun wrong()=raise Fail("select: "^(if symbol then"True"else"False")^
           Int.toString(force i)^Int.toString(force j)^"|\n")
   in case force(extractDeclaration j dec)of
       SymbolDec(body,_)=>if symbol then force(uncurryTerm dec j body)else wrong()
      |AxiomDec(body,_)=>if not symbol then force(uncurryTerm dec j body)else wrong()
      |Def(body,ty,_)=>if symbol then force(uncurryTerm dec j ty)
          else Binary(EqualB,cell(Sym(int 0,j,F.empty(),F.empty())),uncurryTerm dec j body,F.empty(),F.empty())
      |_=>wrong()end)
 (* The pinned source's constructor-type implementation is this stub. *)
 fun selectConstructorType signatureValue i j k=cell(Sym(int 0,int 0,F.empty(),F.empty()))
 fun symbolType signatureValue i j=shiftTerm(shareMap signatureValue)i(selectSymbolType true signatureValue i j)
 fun constructorType signatureValue i j k=shiftTerm(shareMap signatureValue)i(selectConstructorType signatureValue i j k)
 fun axiomType signatureValue i j=shiftTerm(shareMap signatureValue)i(selectSymbolType false signatureValue i j)
 fun otherTypes term=F.defer(fn()=>case force term of
    Sym(_,_,types,_)=>types|App(_,_,types,_)=>types|PairTerm(_,_,_,types,_)=>types|Const(_,_,_,types,_)=>types
   |Binder(_,_,_,types,_)=>types|Unary(_,_,types,_)=>types|Binary(_,_,_,types,_)=>types|Cond(_,_,_,types,_)=>types
   |Constant(_,types,_)=>types|Recurse(_,_,types,_)=>types|_=>raise Match)
 fun termType signatureValue term:itr=D.delay(fn()=>case force(otherTypes term)of
    F.Nil=>force(naturalType signatureValue term)|F.Cons(ty,_)=>force ty)
 and naturalType signatureValue term:itr=D.delay(fn()=>case force term of
    Sym(i,j,_,_)=>force(symbolType signatureValue i j)
   |Const(i,j,k,_,_)=>force(constructorType signatureValue i j k)
   |App(first,second,_,_)=>
      let val ty=termType signatureValue first
          fun result ty=case force ty of Binder(PiB,dec,body,_,_)=>force(substituteTerm dec body second)|_=>raise Match
      in case force ty of Binder(PiB,_,_,_,_)=>result ty|_=>result(naturalType signatureValue first)end
   |PairTerm(_,_,ty,_,_)=>force ty
   |Binder(kind,dec,body,_,_)=>force(binderType signatureValue kind dec body)
   |Constant(kind,_,_)=>force(constantType kind)
   |Recurse(_,ty,_,_)=>force ty|_=>Constant(BoolType,F.empty(),F.empty()))
 and binderType signatureValue kind dec body:itr=D.delay(fn()=>case kind of
    ForallB=>Constant(BoolType,F.empty(),F.empty())
   |ExistsB=>Constant(BoolType,F.empty(),F.empty())
   |ImpB=>Constant(BoolType,F.empty(),F.empty())
   |PiB=>force(productType signatureValue dec body)
   |SigmaB=>force(productType signatureValue dec body)
   |SubtypeB=>Constant(Universe(int 0),F.empty(),F.empty())
   |LambdaB=>Binder(PiB,dec,termType(cell(Extend(dec,signatureValue,F.empty())))body,F.empty(),F.empty())
   |ChooseB=>Binder(SubtypeB,dec,body,F.empty(),F.empty())|_=>raise Match)
 and productType signatureValue dec body:itr=D.delay(fn()=>
   let val extended=cell(Extend(dec,signatureValue,F.empty()))
       val first=termType extended body
       val second=termType signatureValue(declarationType dec)
       val i=case force first of Constant(Universe i,_,_)=>i|_=>raise Match
       val j=case force second of Constant(Universe j,_,_)=>j|_=>raise Match
   in Constant(Universe(D.delay(fn()=>Int.max(force i,force j))),F.empty(),F.empty())end)
 and constantType kind:itr=D.delay(fn()=>case kind of
    Truth=>Constant(BoolType,F.empty(),F.empty())|Falsehood=>Constant(BoolType,F.empty(),F.empty())
   |BoolType=>Constant(Universe(int 0),F.empty(),F.empty())
   |Universe i=>Constant(Universe(add i(int 1)),F.empty(),F.empty()))
 fun evaluateProposition term=case force term of
    Constant(Truth,_,_)=>true|Constant(Falsehood,_,_)=>false
   |Binder(ForallB,dec,body,_,_)=>evaluateQuantifier true dec body
   |Binder(ExistsB,dec,body,_,_)=>evaluateQuantifier false dec body
   |Binder(ImpB,dec,body,_,_)=>not(evaluateProposition(declarationType dec))orelse evaluateProposition body
   |Binary(AndB,a,b,_,_)=>evaluateProposition a andalso evaluateProposition b
   |Binary(OrB,a,b,_,_)=>evaluateProposition a orelse evaluateProposition b
   |Binary(EqualB,a,b,_,_)=>evaluateProposition a=evaluateProposition b
   |Unary(NotU,body,_,_)=>not(evaluateProposition body)
   |Cond(dec,first,_,_,_)=>
        evaluateProposition(substituteTerm dec first(cell(Constant(Truth,F.empty(),F.empty()))))andalso
        evaluateProposition(substituteTerm dec first(cell(Constant(Falsehood,F.empty(),F.empty()))))
   |_=>raise Match
 and evaluateQuantifier universal dec body=
   let fun predicate value=evaluateProposition(substituteTerm dec body value)
   in if universal then all predicate(truthTable dec)else any predicate(truthTable dec)end
 and truthTable dec=F.defer(fn()=>case force dec of
    SymbolDec(body,_)=>(case force body of Constant(BoolType,_,_)=>
       F.fromList[Constant(Truth,F.empty(),F.empty()),Constant(Falsehood,F.empty(),F.empty())]|_=>raise Match)
   |DecPair(a,b,_)=>truthPairs(truthTable a)(truthTable b)|_=>raise Match)
 and truthPairs first second=F.defer(fn()=>case force first of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.append(map(fn y=>cell(PairTerm(x,y,cell(Constant(BoolType,F.empty(),F.empty())),F.empty(),F.empty())))second)
       (truthPairs rest second))
 fun occurs level term=case force term of Sym(i,_,_,_)=>equalInt level i
   |App(a,b,_,_)=>occurs level a orelse occurs level b
   |PairTerm(a,b,c,_,_)=>occurs level a orelse occurs level b orelse occurs level c
   |Binder(_,dec,body,_,_)=>occursDeclaration level dec orelse occurs(add level(int 1))body
   |Unary(_,body,_,_)=>occurs level body
   |Binary(_,a,b,_,_)=>occurs level a orelse occurs level b
   |Cond(dec,a,b,_,_)=>occursDeclaration level dec orelse occurs(add level(int 1))a orelse occurs(add level(int 1))b
   |Recurse(terms,body,_,_)=>any(occurs level)terms orelse occurs level body|_=>false
 and occursDeclaration level dec=case force dec of SymbolDec(body,_)=>occurs level body
   |AxiomDec(body,_)=>occurs level body|DecPair(a,b,_)=>occursDeclaration level a orelse occursDeclaration(add level(int 1))b
   |_=>raise Match

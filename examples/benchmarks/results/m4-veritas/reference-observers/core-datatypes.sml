
 fun foldRightOne function values=D.delay(fn()=>case force values of F.Nil=>raise Empty
   |F.Cons(x,rest)=>force(if null rest then x else function x(foldRightOne function rest)))
 fun iterate count function value=if equalInt count(int 0)then value
   else iterate(subtract count(int 1))function(function value)
 fun makeApplication first second=cell(App(first,second,F.empty(),F.empty()))
 fun etaMatch dec term index=raise Fail"VTS_ERROR"
 fun makeRecursive functionType clauseType recursiveTypes:itr=D.delay(fn()=>case force recursiveTypes of F.Nil=>force clauseType
   |F.Cons(ty,rest)=>case force functionType of Binder(PiB,dec,body,_,_)=>
        let val result=makeRecursive(shiftTerm(F.empty())(int 1)functionType)(shiftTerm(F.empty())(int 1)clauseType)rest
            val argument=substituteTerm dec body ty
        in Binder(PiB,cell(SymbolDec(argument,F.empty())),result,F.empty(),F.empty())end|_=>raise Match)
 fun generateType index functionType recursiveTypes constructor types:itr=D.delay(fn()=>case force functionType of
    Binder(PiB,dec,body,_,_)=>(case force types of F.Nil=>
        force(makeRecursive functionType(substituteTerm dec body constructor)recursiveTypes)
      |F.Cons(ty,rest)=>
        let val applied=makeApplication(shiftTerm(F.empty())(int 1)constructor)(cell(Sym(int 0,int 0,F.empty(),F.empty())))
            val fnType=shiftTerm(F.empty())(int 1)functionType
            val shifted=map(shiftTerm(F.empty())(int 1))recursiveTypes
            val recursive=F.defer(fn()=>if equalTerm ty(cell(Sym(int 0,int 0,F.empty(),F.empty())))
               then F.append shifted(singleton(cell(Sym(index,int 1,F.empty(),F.empty()))))else shifted)
            val result=generateType(add index(int 1))fnType recursive applied rest
            val argument=shiftTerm(F.empty())index ty
        in Binder(PiB,cell(SymbolDec(argument,F.empty())),result,F.empty(),F.empty())end)
   |_=>raise Match)
 fun generateTypeList parameters dataType functionType rows i j k=F.defer(fn()=>case force rows of F.Nil=>F.empty()
   |F.Cons(types,rest)=>
      let val constructor=foldRight makeApplication(cell(Const(i,j,k,F.empty(),F.empty())))(reverse parameters)
          val ty=generateType(int 0)functionType(F.empty())constructor types
          val dec=cell(SymbolDec(dataType,F.empty()))
          fun substituteParameters index term parameters:itr=D.delay(fn()=>case force parameters of F.Nil=>force term
            |F.Cons(parameter,rest)=>force(substituteParameters(subtract index(int 1))
                 (substituteTerm dec term(shiftTerm(F.empty())index parameter))rest))
          val result=substituteParameters(subtract(length parameters)(int 1))(substituteTerm dec ty dataType)parameters
      in F.cons(result,generateTypeList parameters dataType functionType rest i j(add k(int 1)))end)
 fun datatypeInformation signatureValue term=L.delay(fn()=>case force term of
    App(first,second,_,_)=>let val result=datatypeInformation signatureValue first
         val(i,j,parameters,declarations,types)=L.force result
       in(i,j,F.cons(second,parameters),declarations,types)end
   |Const(i,j,k,_,_)=>
      let val dec=extractDeclaration j(nthDeclaration i signatureValue)
      in case force(shiftDeclaration(shareMap signatureValue)i dec)of
          Data(declarations,types,_)=> (i,j,F.empty(),declarations,types)|_=>raise Match end
   |_=>raise Match)
 fun parameterCount types:integer=D.delay(fn()=>case force types of F.Nil=>0
   |F.Cons(term,rest)=>(case force term of Sym _=>2+force(parameterCount rest)|_=>force(parameterCount rest)))
 fun shiftUnder depth offset term=
   let fun bind term=cell(Binder(PiB,cell(SymbolDec(cell(Sym(int 0,int 0,F.empty(),F.empty())),F.empty())),
            term,F.empty(),F.empty()))
       fun body term:itr=D.delay(fn()=>case force term of Binder(_,_,body,_,_)=>force body|_=>raise Match)
   in iterate depth body(shiftTerm(F.empty())offset(iterate depth bind term))end
 fun clauseTypes signatureValue dataType functionType=L.delay(fn()=>
   let val(i,j,parameters,declarations,types)=L.force(datatypeInformation signatureValue dataType)
       val functionType=shiftTerm(F.empty())(add(length declarations)(int 1))functionType
       val dataType=shiftTerm(F.empty())(length declarations)dataType
       val shifted=map(map(shiftUnder(add(length declarations)(int 1))j))types
       val clauses=generateTypeList parameters dataType functionType shifted i j(int 0)
       val counts=map parameterCount types
   in(clauses,counts)end)
 fun makeInduction term recursiveType recursiveTypes:itr=D.delay(fn()=>case force recursiveTypes of F.Nil=>force recursiveType
   |F.Cons(ty,rest)=>
      let val result=makeInduction term recursiveType rest
          val dec=cell(SymbolDec(makeApplication term ty,F.empty()))
      in Binder(ImpB,dec,result,F.empty(),F.empty())end)
 fun inductionType index term recursiveTypes constructor types:itr=D.delay(fn()=>case force types of
    F.Nil=>force(makeInduction term(makeApplication term constructor)recursiveTypes)
   |F.Cons(ty,rest)=>
      let val constructor=makeApplication(shiftTerm(F.empty())(int 1)constructor)(cell(Sym(int 0,int 0,F.empty(),F.empty())))
          val term=shiftTerm(F.empty())(int 1)term
          val shifted=map(shiftTerm(F.empty())(int 1))recursiveTypes
          val recursive=F.defer(fn()=>if equalTerm ty(cell(Sym(int 0,int 0,F.empty(),F.empty())))
              then F.append shifted(singleton ty)else shifted)
          val result=inductionType(add index(int 1))term recursive constructor rest
          val dec=cell(SymbolDec(shiftTerm(F.empty())index ty,F.empty()))
      in Binder(ForallB,dec,result,F.empty(),F.empty())end)
 fun inductionTypeList recursiveType symbols term types i j k=F.defer(fn()=>case force types of F.Nil=>F.empty()
   |F.Cons(arguments,rest)=>
      let val constructor=foldRight makeApplication(cell(Const(i,j,k,F.empty(),F.empty())))(reverse symbols)
          val initial=inductionType(int 0)term(F.empty())constructor arguments
          val dec=cell(SymbolDec(cell(Const(i,j,int 0,F.empty(),F.empty())),F.empty()))
          val result=substituteTerm dec initial recursiveType
      in F.cons(result,inductionTypeList recursiveType symbols term rest i j(add k(int 1)))end)
 fun inductionTerm signatureValue term:itr=D.delay(fn()=>
   let val(i,j,_,declarations,types)=L.force(datatypeInformation signatureValue term)
       val shiftedTypes=map(map(shiftUnder(int 1)(int 1)))types
       val symbols=makeSymbolList declarations(int 0)(F.empty())
       val dataType=foldRight makeApplication(shiftTerm(F.empty())(length declarations)term)(reverse symbols)
       val ty=cell(Binder(PiB,cell(SymbolDec(dataType,F.empty())),cell(Constant(BoolType,F.empty(),F.empty())),F.empty(),F.empty()))
       val dec=cell(SymbolDec(ty,F.empty()))
       val shiftedDatatype=shiftTerm(F.empty())(int 1)dataType
       val shiftedSymbols=map(shiftTerm(F.empty())(int 2))symbols
       val clauses=inductionTypeList shiftedDatatype shiftedSymbols(cell(Sym(int 1,int 0,F.empty(),F.empty())))
            shiftedTypes(add(add(int 2)i)(length declarations))j(int 1)
       val application=makeApplication(cell(Sym(int 1,int 0,F.empty(),F.empty())))(cell(Sym(int 0,int 0,F.empty(),F.empty())))
       val all=cell(Binder(ForallB,cell(SymbolDec(shiftedDatatype,F.empty())),application,F.empty(),F.empty()))
       val implicationDec=cell(SymbolDec(all,F.empty()))
       fun imply first second=cell(Binder(ImpB,implicationDec,second,F.empty(),F.empty()))
       val body=foldRightOne imply(F.append clauses(singleton all))
       fun forall dec term=cell(Binder(ForallB,dec,term,F.empty(),F.empty()))
   in force(foldRight forall body(reverse(F.cons(dec,declarations))))end)
 fun equivalentIndices equal value values=
   let fun loop index values=F.defer(fn()=>case force values of F.Nil=>F.empty()
         |F.Cons(x,rest)=>if equal x value then F.cons(index,loop(add index(int 1))rest)
             else loop(add index(int 1))rest)
   in loop(int 0)values end
 fun union equal first second=F.defer(fn()=>case force first of F.Nil=>second
   |F.Cons(x,rest)=>if any(equal x)second then union equal rest second else F.cons(x,union equal rest second))
 fun updateIndices value indices values=
   let fun loop index values=F.defer(fn()=>case force values of F.Nil=>F.empty()
         |F.Cons(x,rest)=>F.cons(if any(equalInt index)indices then value else x,loop(add index(int 1))rest))
   in loop(int 0)values end
 fun addEquivalence pairValue values=
   let val(i,j)=force pairValue
       val left=nth values i val right=nth values j
       val matches=union equalInt(equivalentIndices equalInt left values)(equivalentIndices equalInt right values)
       val value=D.delay(fn()=>Int.min(force left,force right))
   in updateIndices value matches values end
 fun addEquivalenceRange i j count values=
   let fun pairs i j count=F.defer(fn()=>if equalInt count(int 0)then F.empty()
          else F.cons(pair i j,pairs(add i(int 1))(add j(int 1))(subtract count(int 1))))
   in foldRight addEquivalence values(pairs i j count)end
 fun splitDefinition dec=L.delay(fn()=>case force dec of Def(term,ty,_)=>
      (cell(SymbolDec(ty,F.empty())),term,ty)
   |DecPair(a,b,_)=>
      let val first=splitDefinition a val second=splitDefinition b
          val(dec1,term1,_)=L.force first
          val(dec2,term2,type2)=L.force second
          val ty=shiftTerm(F.empty())(int 1)(substituteTerm a type2 term1)
          val term=substituteTerm a term2 term1
      in(cell(DecPair(dec1,dec2,F.empty())),cell(PairTerm(term1,term,ty,F.empty(),F.empty())),ty)end
   |_=>raise Match)

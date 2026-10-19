
 val emptySignature:signatureValue=cell(SG(cell(EmptySig(F.empty()))))
 fun extendSignature declaration signatureValue:signatureValue=D.delay(fn()=>case(force declaration,force signatureValue)of
    (DC(dec,first),SG second)=>if equalSignature first second then SG(cell(Extend(dec,second,F.empty())))
       else force(signatureError"Malformed signature extension")
   |_=>force(signatureError"Invalid declaration in signature"))
 fun combineSignatures first second:signatureValue=D.delay(fn()=>case(force first,force second)of(SG a,SG b)=>
    let val mapA=shareMap a val mapB=shareMap b
        val offset=length mapB
        val combined=F.append mapB(map(fn i=>add i offset)mapA)
    in SG(cell(Combine(a,b,signatureLength b,combined,F.empty())))end|_=>raise Match)
 fun shareSignature signatureValue i j:signatureValue=D.delay(fn()=>case force signatureValue of SG sg=>
    let val first=nthSignature i sg val second=nthSignature j sg
        val map=shareMap sg
    in if equalSignature first second then SG(cell(Share(sg,i,j,signatureLength second,
          addEquivalenceRange i j(signatureLength second)map,F.empty())))
       else force(signatureError"sg: Share")end|_=>raise Match)
 fun getSignatureInformation signatureValue=F.defer(fn()=>case force signatureValue of SG sg=>signatureAttributes sg|_=>raise Match)
 fun setSignatureInformation signatureValue attrs:signatureValue=D.delay(fn()=>case force signatureValue of SG sg=>
    SG(setSignatureAttributes sg attrs)|_=>raise Match)
 fun internalSignature signatureValue:isgn=D.delay(fn()=>case force signatureValue of SG sg=>force sg|_=>raise Match)
 fun restoreSignature source=signatureError"restore_Sgn unimplemented"
 fun symbolDeclaration term:declaration=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force(termType sg ty)of Constant(Universe _,_,_)=>DC(cell(SymbolDec(body,F.empty())),sg)
      |_=>force(declarationError"Malformed symbol declaration"))|_=>raise Match)
 fun axiomDeclaration term:declaration=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Constant(BoolType,_,_)=>DC(cell(AxiomDec(body,F.empty())),sg)
      |_=>force(declarationError"Malformed axiom declaration"))
   |_=>force(declarationError"Malformed axiom declaration"))
 fun definition term:declaration=D.delay(fn()=>case force term of TM(body,ty,sg)=>DC(cell(Def(body,ty,F.empty())),sg)|_=>raise Match)
 fun makeData terms theorem:declaration=D.delay(fn()=>case force theorem of TH(body,sg)=>
   let fun wellFormed parameter=case force parameter of TM(body,ty,_)=>
         (case force ty of Constant(Universe _,_,_)=>equalTerm body(cell(Sym(int 0,int 0,F.empty(),F.empty())))orelse not(occurs(int 0)body)
           |_=>false)|_=>false
       fun termBody term:itr=D.delay(fn()=>case force term of TM(body,_,_)=>force body|_=>raise Match)
       fun base terms=not(any(fn term=>equalTerm term(cell(Sym(int 0,int 0,F.empty(),F.empty()))))(map termBody terms))
       fun exists first second=bareBinder ExistsB(cell(SymbolDec(shiftTerm(F.empty())(int ~1)first,F.empty())))
           (shiftTerm(F.empty())(int 1)second)
       fun proof terms=foldRight exists(bareConstant Truth)(reverse(map termBody terms))
       val proofs=map proof(filter base terms)
   in if all(all wellFormed)terms then
        if any(equalTerm body)proofs then DC(cell(Data(F.empty(),map(map termBody)terms,F.empty())),sg)
           else force(declarationError"Malformed datatype")
      else force(declarationError"Malformed datatype (2)")end
   |_=>raise Match)
 fun polymorphicData declaration:declaration=D.delay(fn()=>case force declaration of DC(dec,sg)=>
    (case(force dec,force sg)of(Data(parameters,terms,_),Extend(new,parent,_))=>
       if isSymbolDeclaration new then DC(cell(Data(F.cons(new,parameters),terms,F.empty())),parent)
          else force(declarationError"Malformed datatype (polydata)")
      |_=>force(declarationError"Malformed datatype (polydata 2)"))
   |_=>force(declarationError"Malformed datatype (polydata 2)"))
 fun declarationPair declaration:declaration=D.delay(fn()=>case force declaration of DC(first,sg)=>
    (case force sg of Extend(second,parent,_)=>DC(cell(DecPair(second,first,F.empty())),parent)
       |_=>force(declarationError"Malformed declaation pair"))
   |_=>force(declarationError"Malformed declaation pair"))
 fun getDeclarationInformation declaration=F.defer(fn()=>case force declaration of DC(dec,_)=>declarationAttributes dec|_=>raise Match)
 fun setDeclarationInformation declaration attrs:declaration=D.delay(fn()=>case force declaration of DC(dec,sg)=>
    DC(setDeclarationAttributes dec attrs,sg)|_=>raise Match)
 fun internalDeclaration declaration=L.delay(fn()=>case force declaration of DC(dec,sg)=>(dec,sg)|_=>raise Match)
 fun restoreDeclaration source=raise Fail"BadDeclaration"

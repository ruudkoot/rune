
 fun termError message=cell(TermError(text message))
 fun theoremError message=cell(TheoremError(text message))
 fun signatureError message=cell(SignatureError(text message))
 fun declarationError message=cell(DeclarationError(text message))
 fun bareConstant kind=cell(Constant(kind,F.empty(),F.empty()))
 fun bareBinder kind dec body=cell(Binder(kind,dec,body,F.empty(),F.empty()))
 fun bareBinary kind first second=cell(Binary(kind,first,second,F.empty(),F.empty()))
 fun symbol signatureValue i j:term=D.delay(fn()=>case force signatureValue of SG sg=>
    if equalInt(nth(shareMap sg)i)i then TM(cell(Sym(i,j,F.empty(),F.empty())),symbolType sg i j,sg)
       else force(termError"Malformed symbol")|_=>raise Match)
 fun universe signatureValue index:term=D.delay(fn()=>case force signatureValue of SG sg=>
    if leq(int 0)index then TM(bareConstant(Universe index),bareConstant(Universe(add index(int 1))),sg)
       else force(termError"Malformed Universe")|_=>raise Match)
 fun piFormation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(Universe i,_,_),Extend(dec,parent,_))=>
        (case force(termType parent(declarationType dec))of Constant(Universe j,_,_)=>
           TM(bareBinder PiB dec body,bareConstant(Universe(D.delay(fn()=>Int.max(force i,force j)))),parent)
          |_=>force(termError"Malformed pi expression"))
      |_=>force(termError"Sort of pi exression is not a universe"))
   |_=>force(termError"Sort of pi exression is not a universe"))
 fun lambdaFormation term:term=D.delay(fn()=>case force term of TermError _=>force term
   |TM(body,ty,sg)=>(case force sg of Extend(dec,parent,_)=>if isSymbolDeclaration dec then
        TM(bareBinder LambdaB dec body,bareBinder PiB dec ty,parent)else force(termError"lambda: invalid declaration")
       |_=>force(termError"Malformed lambda expression")))
 fun application first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(f,ty,sg1),TM(argument,argType,sg2))=>(case force ty of Binder(PiB,dec,body,_,_)=>
         if equalSignature sg1 sg2 andalso equalTerm(declarationType dec)argType then
           TM(makeApplication f argument,substituteTerm dec body argument,sg1)else force(termError"Malformed application")
       |_=>force(termError"Malformed application (2)"))
   |_=>force(termError"Malformed application (2)"))
 fun sigmaFormation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(Universe i,_,_),Extend(dec,parent,_))=>
        (case force(termType parent(declarationType dec))of Constant(Universe j,_,_)=>
           TM(bareBinder SigmaB dec body,bareConstant(Universe(D.delay(fn()=>Int.max(force i,force j)))),parent)
          |_=>force(termError"Malformed sigma"))
      |_=>force(termError"Malformed sigma (2)"))
   |_=>force(termError"Malformed sigma (2)"))
 fun pairFormation first second pairType:term=D.delay(fn()=>case(force first,force second,force pairType)of
    (TM(a,aType,sg1),TM(b,bType,sg2),TM(ty,_,sg3))=>(case force ty of Binder(SigmaB,dec,result,_,_)=>
      if equalSignature sg1 sg2 andalso equalSignature sg2 sg3 andalso equalTerm aType(declarationType dec)
         andalso equalTerm bType(substituteTerm dec result a)then TM(cell(PairTerm(a,b,ty,F.empty(),F.empty())),ty,sg1)
      else force(termError"Malformed pair")|_=>force(termError"Malformed pair (2)"))
   |_=>force(termError"Malformed pair (2)"))
 fun subtypeFormation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
        if equalTerm(termType parent(declarationType dec))(bareConstant(Universe(int 0)))
           then TM(bareBinder SubtypeB dec body,bareConstant(Universe(int 0)),parent)
           else force(termError"Malformed subtype")|_=>force(termError"Malformed subtype (2)"))
   |_=>force(termError"Malformed subtype (2)"))
 fun subtypeIntroduction first second proof:term=D.delay(fn()=>case(force first,force second,force proof)of
    (TM(body,ty,sg1),TM(subtype,_,sg2),TH(theorem,sg3))=>(case force subtype of Binder(SubtypeB,dec,condition,_,_)=>
      if equalSignature sg1 sg2 andalso equalSignature sg2 sg3
         andalso equalTerm(termType sg2(declarationType dec))(bareConstant(Universe(int 0)))
         andalso equalTerm ty(declarationType dec)andalso equalTerm theorem(substituteTerm dec condition body)
      then TM(addType body subtype,subtype,sg1)else force(termError"Malformed subtype introduction ")
      |_=>force(termError"Malformed subtype introduction (2)"))
   |_=>force(termError"Malformed subtype introduction (2)"))
 fun subtypeElimination term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Binder(SubtypeB,dec,_,_,_)=>let val ty=declarationType dec in TM(addType body ty,ty,sg)end
      |_=>force(termError" outof: argument invalid"))
   |_=>force(termError" outof: argument invalid"))
 fun boolean signatureValue:term=D.delay(fn()=>case force signatureValue of SG sg=>
    TM(bareConstant BoolType,bareConstant(Universe(int 0)),sg)|_=>raise Match)
 fun truth signatureValue:term=D.delay(fn()=>case force signatureValue of SG sg=>
    TM(bareConstant Truth,bareConstant BoolType,sg)|_=>raise Match)
 fun falsehood signatureValue:term=D.delay(fn()=>case force signatureValue of SG sg=>
    TM(bareConstant Falsehood,bareConstant BoolType,sg)|_=>raise Match)
 fun universal term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
       if isSymbolDeclaration dec then TM(bareBinder ForallB dec body,bareConstant BoolType,parent)
         else force(termError"Malformed universal quantification")
      |_=>force(termError"Malformed universal quantification (2)"))
   |_=>force(termError"Malformed universal quantification (2)"))
 fun existential term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
       if isSymbolDeclaration dec then TM(bareBinder ExistsB dec body,bareConstant BoolType,parent)
         else force(termError"Malformed existential quantification")
      |_=>force(termError"Malformed existential quantification (2)"))
   |_=>force(termError"Malformed existential quantification (2)"))
 fun implication term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
       if isAxiomDeclaration dec then TM(bareBinder ImpB dec body,bareConstant BoolType,parent)
         else force(termError"Malformed Implication")
      |_=>force(termError"Malformed Implication (2)"))
   |_=>force(termError"Malformed Implication (2)"))
 fun conjunction first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force ty1,force ty2)of(Constant(BoolType,_,_),Constant(BoolType,_,_))=>
       if equalSignature sg1 sg2 then TM(bareBinary AndB a b,bareConstant BoolType,sg1)
          else force(termError"Malformed conjunction")
       |_=>force(termError"Malformed conjunction (2)"))
   |_=>force(termError"Malformed conjunction (2)"))
 fun disjunction first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force ty1,force ty2)of(Constant(BoolType,_,_),Constant(BoolType,_,_))=>
       if equalSignature sg1 sg2 then TM(bareBinary OrB a b,bareConstant BoolType,sg1)
          else force(termError"Malformed disjunction ")
       |_=>force(termError"Malformed disjunction (2)"))
   |_=>force(termError"Malformed disjunction (2)"))
 fun negation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Constant(BoolType,_,_)=>TM(cell(Unary(NotU,body,F.empty(),F.empty())),bareConstant BoolType,sg)
      |_=>force(termError"Malformed negation"))
   |_=>force(termError"Malformed negation"))
 fun equality first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,_,sg1),TM(b,_,sg2))=>if equalSignature sg1 sg2 then TM(bareBinary EqualB a b,bareConstant BoolType,sg1)
       else force(termError"Malformed equality")|_=>raise Match)
 fun isSubtype first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force ty1,force ty2)of
       (Constant(Universe i,_,_),Constant(Universe j,_,_))=>
          if equalInt i(int 0)andalso equalInt j(int 0)then
            if equalSignature sg1 sg2 then TM(bareBinary IsSubtypeB a b,bareConstant BoolType,sg1)
               else force(termError"Malformed subtype")
          else force(termError"Malformed subtype (2)")|_=>force(termError"Malformed subtype (2)"))
   |_=>force(termError"Malformed subtype (2)"))
 fun conditional first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force sg1,force sg2)of(Extend(dec1,parent1,_),Extend(dec2,parent2,_))=>
      if equalSignature parent1 parent2 andalso equalTerm ty1 ty2 andalso
           equalTerm(cell(Unary(NotU,declarationType dec1,F.empty(),F.empty())))(declarationType dec2)
      then TM(cell(Cond(dec1,a,b,F.empty(),F.empty())),ty1,parent1)else force(termError"Malformed conditional")
       |_=>force(termError"Malformed conditional (2)"))
   |_=>force(termError"Malformed conditional (2)"))
 fun choose theorem:term=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binder(ExistsB,dec,condition,_,_)=>
       if equalTerm(termType sg(declarationType dec))(bareConstant(Universe(int 0)))
         then TM(bareBinder ChooseB dec condition,bareBinder SubtypeB dec condition,sg)
         else force(termError"epsilon operator error")|_=>force(termError"epsilon operator error (2)"))
   |_=>force(termError"epsilon operator error (2)"))
 fun constructor signatureValue i j k:term=D.delay(fn()=>case force signatureValue of SG sg=>
    if equalInt(nth(shareMap sg)i)i then TM(cell(Const(i,j,k,F.empty(),F.empty())),constructorType sg i j k,sg)
       else force(termError"Malformed constructor")|_=>raise Match)
 fun recurse terms function:term=D.delay(fn()=>case force function of TM(body,_,sg)=>
    (case force body of Binder(PiB,dec,_,_,_)=>(case force dec of SymbolDec(dataType,_)=>
       let val result=clauseTypes sg dataType body
           val types=F.defer(fn()=> #1(L.force result))
           fun ok term ty=case force term of TM(_,actual,signatureValue)=>equalSignature sg signatureValue andalso equalTerm actual ty
              |_=>raise Match
           val valid=all(fn value=>let val(term,ty)=force value in ok term ty end)(zip pair terms types)
           val bodies=map(fn term=>D.delay(fn()=>case force term of TM(body,_,_)=>force body|_=>raise Match))terms
       in if valid then TM(cell(Recurse(bodies,body,F.empty(),F.empty())),body,sg)else force(termError"recurse error")end
       |_=>force(termError"recurse error (2)"))|_=>force(termError"recurse error (2)"))
   |_=>force(termError"recurse error (2)"))
 fun widen term theorem:term=D.delay(fn()=>case(force term,force theorem)of
    (TM(body,ty,sg1),TH(proposition,sg2))=>(case force proposition of Binary(IsSubtypeB,from,to,_,_)=>
        if equalSignature sg1 sg2 andalso equalTerm ty from then TM(addType body to,to,sg1)
           else force(termError"widen: error")|_=>force(termError"widen: error (2)"))
   |_=>force(termError"widen: error (2)"))
 fun setTermInformation term indices attrs:term=D.delay(fn()=>case force term of
    TM(body,ty,sg)=>TM(setTermAttributes body indices attrs,ty,sg)|TermError _=>force term)
 fun getTermInformation term indices=F.defer(fn()=>case force term of TM(body,_,_)=>getTermAttributes body indices|_=>raise Match)
 fun internalTerm term=L.delay(fn()=>case force term of TM(body,ty,sg)=>(body,ty,sg)|_=>raise Match)
 fun restoreTerm source=termError"restore_Trm unimplemented"

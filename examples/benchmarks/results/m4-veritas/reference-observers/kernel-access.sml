
 fun equalWrappedTerms first second=case(force first,force second)of(TM(a,_,sg1),TM(b,_,sg2))=>
    equalTerm a b andalso equalSignature sg1 sg2|_=>raise Match
 fun equalWrappedSignatures first second=case(force first,force second)of(SG a,SG b)=>equalSignature a b|_=>raise Match
 fun equalWrappedDeclarations first second=case(force first,force second)of(DC(a,sg1),DC(b,sg2))=>
    equalDeclaration a b andalso equalSignature sg1 sg2|_=>raise Match
 fun equalWrappedTheorems first second=case(force first,force second)of(TH(a,sg1),TH(b,sg2))=>
    equalTerm a b andalso equalSignature sg1 sg2|_=>raise Match
 fun wrappedTermType term:term=D.delay(fn()=>case force term of TM(_,ty,sg)=>TM(ty,termType sg ty,sg)|_=>raise Match)
 fun wrappedDeclarationType declaration:term=D.delay(fn()=>case force declaration of DC(dec,sg)=>
    let val ty=declarationType dec in TM(ty,termType sg ty,sg)end|_=>raise Match)
 fun wrappedTheoremType theorem:term=D.delay(fn()=>case force theorem of TH(body,sg)=>TM(body,bareConstant BoolType,sg)|_=>raise Match)
 fun shiftWrappedTerm offset signatureValue term:term=D.delay(fn()=>case(force signatureValue,force term)of(SG sg1,TM(body,ty,sg2))=>
    if equalSignature sg2(nthSignature offset sg1)then
       TM(shiftTerm(shareMap sg2)offset body,shiftTerm(shareMap sg2)offset ty,sg1)
    else force(termError"shift_Trm: signatures unequal")|_=>raise Match)
 fun substituteWrappedTerm first second:term=D.delay(fn()=>case(force first,force second)of(TM(body,ty,sg1),TM(replacement,replacementType,sg2))=>
    (case force sg1 of Extend(dec,parent,_)=>if equalSignature parent sg2 andalso equalTerm(declarationType dec)replacementType
       then TM(substituteTerm dec body ty,substituteTerm dec ty replacement,parent)
       else force(termError"subst_Trm: signatures unequal or type of dc unequal to type of second argument")
      |_=>force(termError"subst_Trm: Invalid arguments"))
   |_=>force(termError"subst_Trm: Invalid arguments"))
 fun termSignature term:signatureValue=D.delay(fn()=>case force term of TM(_,_,sg)=>SG sg|TermError message=>SignatureError message)
 fun declarationSignature declaration:signatureValue=D.delay(fn()=>case force declaration of DC(_,sg)=>SG sg|DeclarationError message=>SignatureError message)
 fun theoremSignature theorem:signatureValue=D.delay(fn()=>case force theorem of TH(_,sg)=>SG sg|TheoremError message=>SignatureError message)
 fun validTheorem theorem=case force theorem of TH _=>true|_=>false
 fun validTerm term=case force term of TM _=>true|_=>false
 fun validSignature signatureValue=case force signatureValue of SG _=>true|_=>false


 fun axiom signatureValue i j:theorem=D.delay(fn()=>case force signatureValue of SG sg=>
    if equalInt(nth(shareMap sg)i)i then TH(axiomType sg i j,sg)
       else force(theoremError"Malformed Axiom")|_=>raise Match)
 fun generalize theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force sg of Extend(dec,parent,_)=>if isSymbolDeclaration dec then TH(bareBinder ForallB dec body,parent)
        else force(theoremError"Malformed generalisation")|_=>force(theoremError"Malformed generalisation (2)"))
   |_=>force(theoremError"Malformed generalisation (2)"))
 fun specialize theorem term:theorem=D.delay(fn()=>case(force theorem,force term)of(TH(body,sg1),TM(argument,ty,sg2))=>
    (case force body of Binder(ForallB,dec,result,_,_)=>
       if equalSignature sg1 sg2 andalso equalTerm(declarationType dec)ty then TH(substituteTerm dec result argument,sg1)
          else force(theoremError"Malformed specialisation")|_=>force(theoremError"Malformed specialisation (2)"))
   |_=>force(theoremError"Malformed specialisation (2)"))
 fun existsIntroduction proof exists witness:theorem=D.delay(fn()=>case(force proof,force exists,force witness)of
    (TH(body,sg1),TM(target,_,sg2),TM(term,ty,sg3))=>(case force target of Binder(ExistsB,dec,condition,_,_)=>
       if equalSignature sg1 sg2 andalso equalSignature sg2 sg3 andalso equalTerm(declarationType dec)ty
          andalso equalTerm(substituteTerm dec condition term)body then TH(target,sg2)
          else force(theoremError"Malformed existential introduction")|_=>force(theoremError"Malformed existential introduction (2)"))
   |_=>force(theoremError"Malformed existential introduction (2)"))
 fun existsElimination first second:theorem=D.delay(fn()=>case(force first,force second)of(TH(body1,sg1),TH(body2,sg2))=>
    (case(force body1,force body2)of(Binder(ForallB,dec1,inner,_,_),Binder(ExistsB,dec2,condition,_,_))=>
       (case force inner of Binder(ImpB,dec,result,_,_)=>if equalSignature sg1 sg2 andalso equalDeclaration dec1 dec2
           andalso equalTerm(declarationType dec)condition andalso not(occurs(int 0)result)then TH(result,sg1)
           else force(theoremError"Invalid existential elimination")|_=>force(theoremError"Invalid existential elimination"))
      |_=>force(theoremError"Invalid existential elimination"))
   |_=>force(theoremError"Invalid existential elimination"))
 fun discharge theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force sg of Extend(dec,parent,_)=>if isAxiomDeclaration dec then TH(bareBinder ImpB dec body,parent)
       else force(theoremError"Invalid implication introduction")|_=>force(theoremError"Invalid implication introduction (2)"))
   |_=>force(theoremError"Invalid implication introduction (2)"))
 fun modusPonens first second:theorem=D.delay(fn()=>case(force first,force second)of(TH(body,sg1),TH(argument,sg2))=>
    (case force body of Binder(ImpB,dec,result,_,_)=>if equalSignature sg1 sg2 andalso equalTerm(declarationType dec)argument
       then TH(result,sg1)else force(theoremError"Invalid implication elimination")|_=>force(theoremError"Invalid implication elimination"))
   |_=>force(theoremError"Invalid implication elimination"))
 fun tautology term:theorem=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Constant(BoolType,_,_)=>if evaluateProposition body then TH(body,sg)
          else force(theoremError"term is not a tautology")
       |_=>force(theoremError("argument must be a term of sort "^String.str(Char.chr 96)^"bool'")))
   |_=>force(theoremError("argument must be a term of sort "^String.str(Char.chr 96)^"bool'")))
 fun reflexivity term:theorem=D.delay(fn()=>case force term of TM(body,_,sg)=>TH(bareBinary EqualB body body,sg)|_=>raise Match)
 fun symmetry theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binary(EqualB,first,second,_,_)=>TH(bareBinary EqualB second first,sg)
       |_=>force(theoremError"symmetry: argument must be an equality term"))
   |_=>force(theoremError"symmetry: argument must be an equality term"))
 fun betaRewrite theorem indices:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    let val(selected,_)=L.force(selectTerm body indices)
    in case force selected of App(function,argument,_,_)=>(case force function of Binder(LambdaB,dec,result,_,_)=>
          TH(replaceTerm body indices(substituteTerm dec result argument),sg)|_=>force(theoremError"Invalid beta reduction"))
       |_=>force(theoremError"Invalid beta reduction")end|_=>raise Match)
 fun etaRewrite theorem indices:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    let val(selected,_)=L.force(selectTerm body indices)
    in case force selected of Binder(LambdaB,dec,application,_,_)=>(case force application of App(function,argument,_,_)=>
         if not(occurs(int 0)function)andalso etaMatch dec argument(int 1)
           then TH(replaceTerm body indices(shiftTerm(F.empty())(int ~1)function),sg)
           else force(theoremError"Invalid eta reduction")|_=>force(theoremError"Invlaid eta reduction (2)"))
      |_=>force(theoremError"Invlaid eta reduction (2)")end|_=>raise Match)
 fun conditionalTrueRewrite first second indices:theorem=D.delay(fn()=>case(force first,force second)of(TH(proof,sg1),TH(body,sg2))=>
    let val(selected,declarations)=L.force(selectTerm body indices)
    in case force selected of Cond(dec,yes,_,_,_)=>
        let val signatureValue=foldRight(fn dec=>fn sg=>cell(Extend(dec,sg,F.empty())))sg2 declarations
        in if equalSignature sg1 signatureValue andalso equalTerm proof(declarationType dec)
           then TH(replaceTerm body indices(shiftTerm(F.empty())(int ~1)yes),sg1)
           else force(theoremError"cond_true_rw: error")end
       |_=>force(theoremError"cond_true_rw: error 2")end|_=>raise Match)
 fun conditionalFalseRewrite first second indices:theorem=D.delay(fn()=>case(force first,force second)of(TH(proof,sg1),TH(body,sg2))=>
    let val(selected,declarations)=L.force(selectTerm body indices)
    in case force selected of Cond(dec,_,no,_,_)=>
        let val signatureValue=foldRight(fn dec=>fn sg=>cell(Extend(dec,sg,F.empty())))sg2 declarations
        in if equalSignature sg1 signatureValue andalso equalTerm proof(cell(Unary(NotU,declarationType dec,F.empty(),F.empty())))
           then TH(replaceTerm body indices(shiftTerm(F.empty())(int ~1)no),sg1)
           else force(theoremError"cond_false_rw: error")end
       |_=>force(theoremError"cond_false_rw: error 2")end|_=>raise Match)
 fun subtermRewrite first second indices:theorem=D.delay(fn()=>case(force first,force second)of(TH(body,sg1),TH(equation,sg2))=>
    (case force equation of Binary(EqualB,from,to,_,_)=>
       let val(selected,declarations)=L.force(selectTerm body indices)
           val signatureValue=foldRight(fn dec=>fn sg=>cell(Extend(dec,sg,F.empty())))sg1 declarations
       (* The source compares sg3 with itself, not with sg2. *)
       in if equalSignature signatureValue signatureValue andalso equalTerm from selected
          then TH(replaceTerm body indices to,sg1)else force(theoremError"subterm_rw: terms or sigs unequal")end
      |_=>force(theoremError"subterm_rw: Invalid argument"))
   |_=>force(theoremError"subterm_rw: Invalid argument"))
 fun injection theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binary(EqualB,first,second,_,_)=>
       let fun reduce term arguments=F.defer(fn()=>case force term of App(first,second,_,_)=>reduce first(F.cons(second,arguments))
               |_=>F.cons(term,arguments))
           val left=reduce first(F.empty())val right=reduce second(F.empty())
           val c1=head left val c2=head right val args1=tail left val args2=tail right
       in case(force c1,force c2)of(Const(i,j,k,_,_),Const _)=>
          (case force(extractDeclaration j(nthDeclaration i sg))of Data(declarations,_,_)=>
             if less(length declarations)(length args1)andalso equalTerm c1 c2 andalso equalInt(length args1)(length args2)then
                let val a=drop(length declarations)args1 val b=drop(length declarations)args2
                    val equations=zip(bareBinary EqualB)a b
                in TH(foldRightOne(bareBinary AndB)equations,sg)end
             else force(theoremError"Invalid injection")
            |_=>force(theoremError"Invalid injection: not a datatype"))
         |_=>force(theoremError"Invalid injection (3)")end
      |_=>force(theoremError"Invalid injection (4)"))
   |_=>force(theoremError"Invalid injection (4)"))
 fun induction term:theorem=D.delay(fn()=>case force term of TM(body,_,sg)=>
    (case force body of Const(i,j,k,_,_)=>if equalInt k(int 0)then TH(inductionTerm sg body,sg)
       else force(theoremError"Invalid induction")|_=>force(theoremError"Invalid induction"))
   |_=>force(theoremError"Invalid induction"))
 fun subtypeProofIntroduction theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binder(ForallB,dec1,body,_,_)=>
       (case force body of Binder(ExistsB,dec2,equation,_,_)=>
          (case force equation of Binary(EqualB,first,second,_,_)=>
             (case(force first,force second)of(Sym(i,j,_,_),Sym(k,l,_,_))=>
                if equalInt i(int 1)andalso equalInt j(int 0)andalso equalInt k(int 0)andalso equalInt l(int 0)
                  then TH(bareBinary IsSubtypeB(declarationType dec1)(shiftTerm(F.empty())(int ~1)(declarationType dec2)),sg)
                  else force(theoremError"issubtype_intro error (1)")
               |_=>force(theoremError"issubtype_intro error (1)"))
            |_=>force(theoremError"issubtype_intro error (2)"))
         |_=>force(theoremError"issubtype_intro error (2)"))
      |_=>force(theoremError"issubtype_intro error (3)"))
   |_=>force(theoremError"issubtype_intro error (3)"))
 fun subtypeProofElimination theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binary(IsSubtypeB,first,second,_,_)=>
       let val dec1=cell(SymbolDec(first,F.empty()))
           val dec2=cell(SymbolDec(shiftTerm(F.empty())(int 1)second,F.empty()))
           val equation=bareBinary EqualB(cell(Sym(int 1,int 0,F.empty(),F.empty())))(cell(Sym(int 0,int 0,F.empty(),F.empty())))
       in TH(bareBinder ForallB dec1(bareBinder ExistsB dec2 equation),sg)end
      |_=>force(theoremError"issubtype_elim error"))
   |_=>force(theoremError"issubtype_elim error"))
 fun equalityOfTypes first second:theorem=D.delay(fn()=>case(force first,force second)of(TH(body1,sg1),TH(body2,sg2))=>
    (case(force body1,force body2)of(Binary(IsSubtypeB,a,b,types1,attrs1),Binary(IsSubtypeB,c,d,types2,attrs2))=>
       if null types1 andalso null attrs1 andalso null types2 andalso null attrs2 then
          if equalSignature sg1 sg2 andalso equalTerm a d andalso equalTerm b c then TH(bareBinary EqualB a b,sg1)
             else force(theoremError"eq_of_ty error")
       else force(theoremError"eq_of_ty error (2)")
      |_=>force(theoremError"eq_of_ty error (2)"))
   |_=>force(theoremError"eq_of_ty error (2)"))
 fun fromSubtype term:theorem=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Binder(SubtypeB,dec,condition,_,_)=>TH(substituteTerm dec condition body,sg)
       |_=>force(theoremError"from: argument must be term of subtype sort"))
   |_=>force(theoremError"from: argument must be term of subtype sort"))
 fun definitionElimination theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force sg of Extend(dec,parent,_)=>if isDefinitionDeclaration dec then
       let val result=splitDefinition dec
           val(new,replacement,_)=L.force result
       in TH(substituteTerm new body replacement,parent)end
       else force(theoremError"Definition elimination error")
      |_=>force(theoremError"Definition elimination error (2)"))
   |_=>force(theoremError"Definition elimination error (2)"))
 fun weaken signatureValue theorem:theorem=D.delay(fn()=>case(force signatureValue,force theorem)of(SG sg1,TH(body,sg2))=>
    (case force(subSignature sg2 sg1)of SomeValue index=>TH(shiftTerm(shareMap sg1)index body,sg1)
      |NoValue=>force(theoremError"Weaken error"))|_=>raise Match)
 fun setTheoremInformation theorem indices attrs:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    TH(setTermAttributes body indices attrs,sg)|_=>raise Match)
 fun getTheoremInformation theorem indices=F.defer(fn()=>case force theorem of TH(body,sg)=>getTermAttributes body indices|_=>raise Match)
 fun restoreTheorem source=raise Fail"BadTheorem"
 fun internalTheorem theorem=L.delay(fn()=>case force theorem of TH(body,sg)=>(body,sg)
   |TheoremError _=>raise Fail"add feed to itm via extra itrm ctr")

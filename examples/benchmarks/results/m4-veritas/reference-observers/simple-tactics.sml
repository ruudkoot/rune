
 fun exactlyTwo values=case force values of F.Cons(first,rest)=>(case force rest of F.Cons(second,rest)=>
       if null rest then SOME(first,second)else NONE|_=>NONE)|_=>NONE
 fun noCompletion()=cell NoValue:completion
 fun completedTheorem theorem=cell(SomeValue(cell(TheoremDone theorem))):completion
 fun completedDeclaration declaration=cell(SomeValue(cell(DeclarationDone declaration))):completion
 fun completedTerm term=cell(SomeValue(cell(TermDone term))):completion
 fun autoValidator done values=if null values then cell(SomeValue done)else noCompletion()
 fun autoSubgoals global signatureValue lookup arguments object=L.delay(fn()=>
   let fun result done=Ok(cell(F.empty(),autoValidator done))
   in case force object of TheoremSpec _=>Bad(text"Not Applicable")
     |TermSpec term=>result(cell(TermDone(buildITerm signatureValue term)))
     |DeclarationSpec declaration=>result(cell(DeclarationDone(buildDeclaration signatureValue declaration)))
     |SignatureSpec signatureValue=>result(cell(SignatureDone(buildSignature signatureValue)))end)
 fun singletonValidator theorem values=if null values then completedTheorem theorem else noCompletion()
 fun reflexSubgoals global signatureValue lookup arguments object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binary(EqualB,first,second,_,_)=>
       if equalTerm first second then
          let val theorem=reflexivity(buildITerm signatureValue first)
          in Ok(cell(F.empty(),singletonValidator theorem))end
       else Bad(text"Terms not equal")
      |_=>Bad(text"cannot apply 'reflex' to specified goal"))
   |_=>Bad(text"cannot apply 'reflex' to specified goal"))
 fun createDeclarationName prefix index dec=L.delay(fn()=>case force dec of DecPair(first,second,attrs)=>
    let val one=createDeclarationName prefix index first
        val(a,next)=L.force one
        val(b,final)=L.force(createDeclarationName prefix next second)
    in(cell(DecPair(a,b,attrs)),final)end|_=>(dec,index))
 fun orderedBinderValidator generalizeRule signatureValue values editable=L.delay(fn()=>
   let fun defaults()=(editable,fromNative[signatureValue,signatureValue],noCompletion())
   in case exactlyTwo values of NONE=>defaults()|SOME(first,second)=>
      case force first of NoValue=>defaults()|SomeValue done=>
        case force done of DeclarationDone declaration=>
           (case force second of SomeValue done=>
              (case force done of TheoremDone theorem=>
                 (editable,fromNative[signatureValue,extendSignature declaration signatureValue],
                  completedTheorem(generalizeRule theorem))|_=>defaults())
            |NoValue=>if Option.isSome(exactlyTwo editable)then
                (F.fromList[true,true],fromNative[signatureValue,extendSignature declaration signatureValue],noCompletion())
               else defaults())
          |_=>defaults() end)
 fun generalizeSubgoals global signatureValue lookup arguments object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binder(ForallB,dec,body,_,_)=>
       let val(named,_)=L.force(createDeclarationName(text"xxx")(int 0)dec)
       in Ok(cell(F.fromList[DeclarationSpec named,TheoremSpec body],fromNative[lookup,lookup],F.fromList[true,false],
            orderedBinderValidator generalize signatureValue))end
      |_=>Bad(text"Cannot apply tactic to given goal"))
   |_=>Bad(text"Cannot apply tactic to given goal"))
 fun dischargeSubgoals global signatureValue lookup arguments object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binder(ImpB,dec,body,_,_)=>
       let val(named,_)=L.force(createDeclarationName(text"hhh")(int 0)dec)
       in Ok(cell(F.fromList[DeclarationSpec named,TheoremSpec body],fromNative[lookup,lookup],F.fromList[true,false],
            orderedBinderValidator discharge signatureValue))end
      |_=>Bad(text"Cannot apply 'Disch' to specified goal"))
   |_=>Bad(text"Cannot apply 'Disch' to specified goal"))
 val autoTactic=Tactic(text"Auto",nullArguments,autoSubgoals)
 val reflexTactic=Tactic(text"Reflex",nullArguments,reflexSubgoals)
 val generalizeTactic=OrderedTactic(text"Gen",nullArguments,generalizeSubgoals)
 val dischargeTactic=OrderedTactic(text"Disch",nullArguments,dischargeSubgoals)

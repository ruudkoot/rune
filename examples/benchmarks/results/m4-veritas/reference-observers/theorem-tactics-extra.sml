
 fun existsSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of
    (SOME[input,kind],TheoremSpec goal)=>
      let fun make term extra validator=case force term of Binder(ExistsB,dec,condition,_,_)=>
           let val implication=bareBinder ImpB(cell(AxiomDec(condition,F.empty())))(shiftTerm(F.empty())(int 2)goal)
               val quantified=bareBinder ForallB dec implication
               val objects=if extra then F.fromList[TheoremSpec quantified,TheoremSpec term]else singleton(cell(TheoremSpec quantified))
           in Ok(cell(objects,validator))end
          |_=>Bad(text"term is not an existential")
          fun known given values=case oneTheorem values of SOME theorem=>completedTheorem(existsElimination given theorem)|NONE=>noCompletion()
          fun pair values=case twoTheorems values of SOME(a,b)=>completedTheorem(existsElimination a b)|NONE=>noCompletion()
      in if equalText kind(text"Derivation")then
           let val proof=parsedTheorem global signatureValue input
           in if validTheorem proof then let val(body,_)=L.force(internalTheorem proof)in make body false(known proof)end
              else case force proof of TheoremError message=>Bad message|_=>raise Match end
         else if equalText kind(text"Specification")then
           (case parseTermSpec signatureValue(getGlobalTags global)input of Ok term=>make term true pair|Bad message=>Bad message)
         else Bad(text"Invalid application of 'ExistsElim'")end
   |_=>Bad(text"Invalid application of 'ExistsElim'"))
 val existsEliminationTactic=Tactic(text"ExistsElim",argumentForm(F.fromList[FormComment(text"Exists Elimination"),
     MultiText(text"Existential Object",text""),
     Radio(text"Type of Object",int 0,F.fromList(List.map(fn s=>force(text s))["Derivation","Specification"]))])2,existsSubgoals)
 fun reduceInduction term=F.defer(fn()=>case force term of Binder(ImpB,dec,body,_,_)=>
       F.cons(declarationType dec,reduceInduction(shiftTerm(F.empty())(int ~1)body))|_=>F.empty())
 fun inductionValidator theorem paths values:completion=D.delay(fn()=>
   let val count=subtract(length values)(int 1)
       val first=take count values
       val last=head(drop count values)
       val term=case force last of SomeValue done=>(case force done of TermDone term=>term|_=>raise Match)|_=>raise Match
       val initial=repeatBeta(specialize theorem term)paths
       fun step theorem value:theorem=D.delay(fn()=>case force value of SomeValue done=>
             (case force done of TheoremDone other=>force(modusPonens theorem other)|_=>raise Match)|_=>raise Match)
       val proof=foldLeft step initial first
   in SomeValue(cell(TheoremDone proof))end)
 fun inductionSubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binder(ForallB,dec,condition,_,attrs)=>
       let val dataType=case force dec of SymbolDec(dataType,_)=>dataType|_=>raise Match
           val(i,j,parameters,_,_)=L.force(datatypeInformation(internalSignature signatureValue)dataType)
           val specialized=foldLeft specialize(induction(constructor signatureValue i j(int 0)))(map(buildITerm signatureValue)parameters)
           val(theoremBody,_)=L.force(internalTheorem specialized)
           val(formal,result)=case force theoremBody of Binder(_,dec,result,_,_)=>(dec,result)|_=>raise Match
           val function=cell(Binder(LambdaB,dec,condition,F.empty(),attrs))
           val(reduced,paths)=L.force(findBetas(substituteTerm formal result function))
           val subgoals=F.append(map(fn body=>cell(TheoremSpec body))(reduceInduction reduced))(singleton(cell(TermSpec function)))
       in Ok(cell(subgoals,inductionValidator specialized paths))end
      |_=>Bad(text"Goal is not universally quantified"))
   |_=>Bad(text"Goal is not universally quantified"))
 val inductionTactic=Tactic(text"Induction",nullArguments,inductionSubgoals)
 fun stripTactic state=
   let val choices=List.map(fn tactic=> #2(liftTactic tactic))[reflexTactic,hypothesisTactic]
       val choices=choices@[#2(liftOrderedTactic generalizeTactic),#2(liftOrderedTactic dischargeTactic)]
          @List.map(fn tactic=> #2(liftTactic tactic))[conjunctionTactic,orTactic,notTactic,equalityTactic,autoTactic]
       fun combine [last]=last|combine(first::rest)=tacticOrElse first(combine rest)|combine[]=raise Empty
   in repeatTactic(combine choices)state end
 fun trivialTactic state=
   let val choices=List.map(fn tactic=> #2(liftTactic tactic))[reflexTactic,hypothesisTactic,autoTactic,tautologyTactic]
       fun combine []=(fn state=>returnAction(fn()=>state))
         |combine(first::rest)=tacticOrElse first(combine rest)
   in combine choices state end

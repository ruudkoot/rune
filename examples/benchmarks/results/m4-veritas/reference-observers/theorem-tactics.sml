
 fun argumentValues arguments=
   let fun collect values=case force values of F.Nil=>[]|F.Cons(x,rest)=>x::collect rest
   in case force arguments of NoValue=>NONE|SomeValue values=>SOME(collect values)end
 fun oneTheorem values=case force values of F.Nil=>NONE|F.Cons(first,rest)=>
    case force first of NoValue=>NONE|SomeValue done=>case force done of TheoremDone theorem=>
       if null rest then SOME theorem else NONE|_=>NONE
 fun twoTheorems values=case force values of F.Nil=>NONE|F.Cons(first,rest)=>
    case force first of NoValue=>NONE|SomeValue done=>case force done of TheoremDone first=>
       (case oneTheorem rest of SOME second=>SOME(first,second)|NONE=>NONE)|_=>NONE
 fun threeTheorems values=case force values of F.Nil=>NONE|F.Cons(first,rest)=>
    case force first of NoValue=>NONE|SomeValue done=>case force done of TheoremDone first=>
       (case twoTheorems rest of SOME(second,third)=>SOME(first,second,third)|NONE=>NONE)|_=>NONE
 fun parsedTheorem global signatureValue chars=parseDerivation(getGlobalTags global,signatureValue)
       (parseIterm(getGlobalTags global,signatureValue)chars)
 fun argumentForm descriptors expected global lookup object=case force object of TheoremSpec _=>
    bindAction(form true descriptors)(fn delayed=>case L.force delayed of NONE=>returnAction(fn()=>cell NoValue:tacticArguments)
      |SOME values=>
        let val fields=List.map force(controlItems values)
            fun strings []=[]|strings(OutText x::rest)=x::strings rest|strings(OutRadio x::rest)=x::strings rest|strings _=raise Match
            val args=strings fields
        in if List.length args=expected then returnAction(fn()=>cell(SomeValue(fromNative args))):tacticArguments action
           else raise Match end)
   |_=>raise Match
 fun completeSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of
    (SOME[derivation],TheoremSpec goal)=>
       let val theorem=parsedTheorem global signatureValue derivation
       in if not(validTheorem theorem)then(case force theorem of TheoremError message=>Bad message|_=>raise Match)
          else let val(body,_)=L.force(internalTheorem theorem)
               in if equalTerm body goal then Ok(cell(F.empty(),singletonValidator theorem))
                  else Bad(textConcat[text"Derivation does not prove given goal\nproves: ",objectText signatureValue(cell(TheoremSpec body))])end end
   |_=>Bad(text"Goal is not a theorem"))
 val completeTactic=Tactic(text"Complete",
     argumentForm(F.fromList[FormComment(text"Complete Theorem"),MultiText(text"Derivation",text"")])1,completeSubgoals)
 fun conjunctionValidator values=case twoTheorems values of SOME(first,second)=>completedTheorem(deriveConjunction first second)|NONE=>noCompletion()
 fun conjunctionSubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec term=>
    (case force term of Binary(AndB,first,second,_,_)=>Ok(cell(F.fromList[TheoremSpec first,TheoremSpec second],conjunctionValidator))
      |_=>Bad(text"cannot apply tactic to specified goal"))
   |_=>Bad(text"cannot apply tactic to specified goal"))
 val conjunctionTactic=Tactic(text"Conjunction",nullArguments,conjunctionSubgoals)
 fun disjunctionValidator given values=case twoTheorems values of SOME(first,second)=>completedTheorem(deriveDisjunction given first second)|NONE=>noCompletion()
 fun disjunctionTermValidator values=case threeTheorems values of SOME(first,second,third)=>completedTheorem(deriveDisjunction third first second)|NONE=>noCompletion()
 fun disjunctionSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of
    (SOME[kind,input],TheoremSpec goal)=>
      let fun result term validator=case force term of Binary(OrB,first,second,_,_)=>
           let val shifted=shiftTerm(F.empty())(int 1)goal
               val a=bareBinder ImpB(cell(AxiomDec(first,F.empty())))shifted
               val b=bareBinder ImpB(cell(AxiomDec(second,F.empty())))shifted
           in Ok(cell(F.fromList[TheoremSpec a,TheoremSpec b],validator))end|_=>Bad(text"Goal is not a disjunction")
      in if equalText kind(text"Derivation")then
           let val theorem=parsedTheorem global signatureValue input
           in if validTheorem theorem then
                let val(body,_)=L.force(internalTheorem theorem)in result body(disjunctionValidator theorem)end
              else case force theorem of TheoremError message=>Bad message|_=>raise Match end
         else if equalText kind(text"Specification")then
           (case parseTermSpec signatureValue(getGlobalTags global)input of Bad message=>Bad message|Ok term=>
              case force term of Binary(OrB,first,second,_,_)=>
                let val shifted=shiftTerm(F.empty())(int 1)goal
                    val a=bareBinder ImpB(cell(AxiomDec(first,F.empty())))shifted
                    val b=bareBinder ImpB(cell(AxiomDec(second,F.empty())))shifted
                in Ok(cell(F.fromList[TheoremSpec a,TheoremSpec b,TheoremSpec term],disjunctionTermValidator))end
               |_=>Bad(text"Specification  is not a disjunction"))
         else Bad(text"No selection")end
   |_=>Bad(text"Cannot apply 'disjunction'"))
 val disjunctionTactic=Tactic(text"Disjunction",argumentForm(F.fromList[FormComment(text"Disjunction"),
      Radio(text"Argument Type",int 0,F.fromList(List.map(fn s=>force(text s))["Derivation","Specification"])),MultiText(text"",text"")])2,
      disjunctionSubgoals)
 fun tautologySubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec term=>
    let val theorem=tautology(buildITerm signatureValue term)
    in if validTheorem theorem then Ok(cell(F.empty(),singletonValidator theorem))
       else case force theorem of TheoremError message=>Bad message|_=>raise Match end
   |_=>Bad(text"goal is not a theorem specification"))
 val tautologyTactic=Tactic(text"Taut",nullArguments,tautologySubgoals)
 fun axiomSubgoals global signatureValue lookup args object=L.delay(fn()=>case argumentValues args of SOME[name]=>
    (case force(lookupParsedName name signatureValue)of Operand operand=>(case force operand of ITerm term=>
       (case force term of Sym(i,j,_,_)=>
          let val theorem=axiom signatureValue i j
          in if validTheorem theorem then Ok(cell(F.empty(),singletonValidator theorem))
             else Bad(textConcat[text"Axiom: ",integerText i,text" ",integerText j])end
        |_=>Bad(F.append(text"No Such Axiom Name: ")name))|_=>raise Match)
      |_=>Bad(F.append(text"No Such Axiom Name: ")name))
   |_=>Bad(text"Hmm: it's failed, no name supplied perhaps?"))
 val axiomTactic=Tactic(text"Axiom",argumentForm(F.fromList[FormComment(text"Tactic: Axiom"),SingleText(text"Name Of Axiom",text"")])1,axiomSubgoals)
 fun hypotheses signatureValue sg i=F.defer(fn()=>case force sg of EmptySig _=>F.empty()
   |Extend(dec,parent,_)=>let val(_,current)=L.force(hypothesisDeclarations signatureValue dec i(int 0))
      in F.append current(hypotheses signatureValue parent(add i(int 1)))end|_=>F.empty())
 and hypothesisDeclarations signatureValue dec i j=L.delay(fn()=>case force dec of
    AxiomDec _=>(j,singleton(axiom signatureValue i j))|Def _=>(j,singleton(axiom signatureValue i j))
   |DecPair(a,b,_)=>let val(next,first)=L.force(hypothesisDeclarations signatureValue a i(add j(int 1)))
        val(final,second)=L.force(hypothesisDeclarations signatureValue b i(add next(int 1)))
     in(final,F.append first second)end|_=>(j,F.empty()))
 fun hypothesisSubgoals global signatureValue lookup args object=L.delay(fn()=>case(force args,force object)of(NoValue,TheoremSpec goal)=>
    let val matches=filter(fn theorem=>let val(body,_)=L.force(internalTheorem theorem)in equalTerm goal body end)
          (hypotheses signatureValue(internalSignature signatureValue)(int 0))
    in if null matches then Bad(text"Can't find match")else Ok(cell(F.empty(),singletonValidator(head matches)))end
   |_=>Bad(text"goal is not a theorem specification"))
 val hypothesisTactic=Tactic(text"Hyp",nullArguments,hypothesisSubgoals)
 fun lemmaValidator values=case twoTheorems values of SOME(first,second)=>completedTheorem(modusPonens first second)|NONE=>noCompletion()
 fun lemmaSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of(SOME[name,specification],TheoremSpec goal)=>
    (case parseTermSpec signatureValue(getGlobalTags global)specification of Bad message=>Bad message|Ok lemma=>
       let val dec=cell(AxiomDec(lemma,singleton(symbolName(cell(Name name)))))
           val implication=bareBinder ImpB dec(shiftTerm(F.empty())(int 1)goal)
       in Ok(cell(F.fromList[TheoremSpec implication,TheoremSpec lemma],lemmaValidator))end)
   |_=>Bad(text"Goal is not a theorem specification"))
 val lemmaTactic=Tactic(text"Lemma",argumentForm(F.fromList[FormComment(text"Add lemma"),SingleText(text"Name ",text""),MultiText(text"Lemma",text"")])2,lemmaSubgoals)
 fun parsedProof global signatureValue input=parsedTheorem global signatureValue(textConcat input)
 fun equalityValidator global signatureValue first second values=case twoTheorems values of NONE=>noCompletion()|SOME(a,b)=>
    let val proof=parsedProof global signatureValue[byte 186,text"(",byte 177,text"a:bool.",byte 177,text"b:bool.(a",byte 182,text"b)",
          byte 182,text"(b",byte 182,text"a)",byte 182,text"(a=b))"]
        val specialized=specialize(specialize proof first)second
    in completedTheorem(modusPonens(modusPonens specialized a)b)end
 fun equalitySubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec goal=>
    (case force goal of Binary(EqualB,first,second,_,_)=>
       let val a=buildITerm signatureValue first val b=buildITerm signatureValue second
           val(ty1,_,_)=L.force(internalTerm(wrappedTermType a))
           val(ty2,_,_)=L.force(internalTerm(wrappedTermType b))
       in if equalTerm ty1 ty2 andalso equalTerm ty1(bareConstant BoolType)then
           let val x=bareBinder ImpB(cell(AxiomDec(first,F.empty())))(shiftTerm(F.empty())(int 1)second)
               val y=bareBinder ImpB(cell(AxiomDec(second,F.empty())))(shiftTerm(F.empty())(int 1)first)
           in Ok(cell(F.fromList[TheoremSpec x,TheoremSpec y],equalityValidator global signatureValue a b))end
          else Bad(text"Equality not on booleans")end
      |_=>Bad(text"Cannot apply tactic to given goal"))
   |_=>Bad(text"Cannot apply tactic to given goal"))
 val equalityTactic=Tactic(text"Eq",nullArguments,equalitySubgoals)
 fun orValidator global signatureValue first second values=case oneTheorem values of NONE=>noCompletion()|SOME theorem=>
    let val proof=parsedProof global signatureValue[byte 186,text"(",byte 177,text"a:bool.",byte 177,text"b:bool.(",
           byte 181,text"a",byte 182,text"b)=(a",byte 180,text"b))"]
        val specialized=specialize(specialize proof first)second
    in completedTheorem(subtermRewrite theorem specialized(F.empty()))end
 fun orSubgoals global signatureValue lookup args object=L.delay(fn()=>case(force args,force object)of(NoValue,TheoremSpec goal)=>
    (case force goal of Binary(OrB,first,second,_,_)=>
       let val dec=cell(AxiomDec(cell(Unary(NotU,first,F.empty(),F.empty())),F.empty()))
           val sub=bareBinder ImpB dec(shiftTerm(F.empty())(int 1)second)
       in Ok(cell(singleton(cell(TheoremSpec sub)),orValidator global signatureValue(buildITerm signatureValue first)(buildITerm signatureValue second)))end
      |_=>Bad(text"Goal is not a disjunction"))
   |_=>Bad(text"Goal is not a disjunction"))
 val orTactic=Tactic(text"Or",nullArguments,orSubgoals)
 fun notValidator global signatureValue term values=case oneTheorem values of NONE=>noCompletion()|SOME theorem=>
    let val proof=parsedProof global signatureValue[byte 186,text"(",byte 177,text"a:bool.a=",byte 181,byte 181,text"a)"]
        val specialized=specialize proof term
    in completedTheorem(subtermRewrite theorem specialized(F.empty()))end
 fun notSubgoals global signatureValue lookup args object=L.delay(fn()=>case(force args,force object)of(NoValue,TheoremSpec goal)=>
    (case force goal of Unary(NotU,inner,_,_)=>(case force inner of Unary(NotU,term,_,_)=>
        Ok(cell(singleton(cell(TheoremSpec term)),notValidator global signatureValue(buildITerm signatureValue term)))
          |_=>Bad(text"cannot apply 'Not' to given goal"))
      |_=>Bad(text"cannot apply 'Not' to given goal"))
   |_=>Bad(text"cannot apply 'Not' to given goal"))
 val notTactic=Tactic(text"Not",nullArguments,notSubgoals)

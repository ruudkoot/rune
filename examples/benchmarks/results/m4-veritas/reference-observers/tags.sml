
 fun oneArgument arguments=case force arguments of F.Cons(first,rest)=>if null rest then first else raise Match|_=>raise Match
 fun twoArguments arguments=case force arguments of F.Cons(first,rest)=>
      (case force rest of F.Cons(second,rest)=>if null rest then(first,second)else raise Match|_=>raise Match)
    |_=>raise Match
 fun threeArguments arguments=case force arguments of F.Cons(first,rest)=>
      let val(second,third)=twoArguments rest in(first,second,third)end|_=>raise Match
 fun reflexTag arguments:theorem=D.delay(fn()=>case force(oneArgument arguments)of TagTerm term=>force(reflexivity term)|_=>raise Match)
 fun betaTag arguments:theorem=D.delay(fn()=>let val(first,second)=twoArguments arguments
    in case(force first,force second)of(TagTheorem theorem,TagInt indices)=>force(betaRewrite theorem indices)|_=>raise Match end)
 fun etaTag arguments:theorem=D.delay(fn()=>let val(first,second)=twoArguments arguments
    in case(force first,force second)of(TagTheorem theorem,TagInt indices)=>force(etaRewrite theorem indices)|_=>raise Match end)
 fun symmetryTag arguments:theorem=D.delay(fn()=>case force(oneArgument arguments)of TagTheorem theorem=>force(symmetry theorem)|_=>raise Match)
 fun tautologyTag arguments:theorem=D.delay(fn()=>case force(oneArgument arguments)of TagTerm term=>force(tautology term)|_=>raise Match)
 fun conditionalTrueTag arguments:theorem=D.delay(fn()=>let val(first,second,third)=threeArguments arguments
    in case(force first,force second,force third)of(TagTheorem first,TagTheorem second,TagInt indices)=>
        force(conditionalTrueRewrite first second indices)|_=>raise Match end)
 val defaultTags:tagData F.seq=F.fromList[
   (text"reflex",F.fromList[TermArg],F.fromList[TheoremFunction reflexTag]),
   (byte 226,F.fromList[DerivArg,IntArg],F.fromList[TheoremFunction betaTag]),
   (byte 232,F.fromList[DerivArg,IntArg],F.fromList[TheoremFunction etaTag]),
   (text"symmetry",F.fromList[DerivArg],F.fromList[TheoremFunction symmetryTag]),
   (byte 186,F.fromList[TermArg],F.fromList[TheoremFunction tautologyTag]),
   (text"if_true",F.fromList[DerivArg,DerivArg,IntArg],F.fromList[TheoremFunction conditionalTrueTag])]

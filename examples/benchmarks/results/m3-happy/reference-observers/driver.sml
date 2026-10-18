 (* Main's selected non-GLR redundancy analysis retains linear nub/member
  * searches; generated token/production arrays are shared with codegen. *)
 fun firstReduction action=F.defer(fn()=>case D.force action of
      LRReduce(rule,_)=>singleton rule
     |LRMultiple(_,winner)=>firstReduction winner|_=>F.empty())
 fun isShift action=case D.force action of LRShift _=>true
   |LRMultiple(_,winner)=>(case D.force winner of LRShift _=>true|_=>false)|_=>false
 fun nubInts values=
   let fun go seen values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(value,rest)=>if List.exists(fn x=>x=D.force value)seen then go seen rest
            else F.cons(value,go(D.force value::seen)rest))
   in go[]values end
 fun findRedundancies grammar action=
   let val actions=flatMap(fn(_,row)=>A.assocs row)(A.assocs action)
       val usedRules=F.append(range 0(length(starts grammar)-1))
           (nubInts(flatMap(fn(_,a)=>firstReduction a)actions))
       val usedTokens=F.cons(D.delay(fn()=>1),F.cons(D.delay(fn()=>eof grammar),
           nubInts(F.map(fn(n,_)=>n)(F.filter(fn(_,a)=>isShift a)actions))))
       val unusedRules=F.filter(fn r=>not(memberInt r usedRules))(range 0(length(productions grammar)-1))
       val unusedTokens=F.filter(fn n=>not(memberInt n usedTokens))(terminals grammar)
   in(unusedRules,F.map(fn n=>A.sub(tokenNames grammar)n)unusedTokens)end
 fun generate input=
   let val ast=case parse(X.input input)1 of X.Failed message=>raise Fail(String.implode(F.toList message))
         |X.Ok ast=>ast
       val grammar=case mangler"TestInput.y"ast of Succeeded value=>L.force value
         |Rejected errors=>raise Fail(String.implode(F.toList(flatMap(fn x=>F.append x(X.text"\n"))errors)))
       val AbsSyn(hd,_,_,tl)=D.force ast
       val first=mkFirst grammar
       val states=genLR0items grammar(precalcClosure0 grammar)
       val(spont,prop)=propLookaheads grammar states first
       val final=calcLookaheads(cLength states)spont prop
       val merged=mergeLookaheadInfo final states
       val goto=genGotoTable grammar states
       val action=genActionTable grammar first merged
       val(_,counts)=countConflicts action
       val(unusedRules,unusedTokens)=findRedundancies grammar action
       val warnings=F.defer(fn()=>
         let fun unused label values=case D.force values of F.Nil=>emptyText
               |_=>X.text("unused "^label^": "^Int.toString(length values)^"\n")
             fun conflicts()=
               let val(sr,rr)=L.force counts
                   val sr=L.force sr val rr=L.force rr
               in case expect grammar of SOME n=>
                 if n=sr andalso rr=0 then emptyText
                 else if rr>0 then raise Fail("The grammar has reduce/reduce conflicts.\n"^
                   "This is not allowed when an expect directive is given\n")
                 else raise Fail("The grammar has "^Int.toString sr^" shift/reduce conflicts.\n"^
                   "This is different from the number given in the expect directive\n")
               |NONE=>X.text((if sr=0 then""else"shift/reduce conflicts:  "^Int.toString sr^"\n")^
                            (if rr=0 then""else"reduce/reduce conflicts: "^Int.toString rr^"\n"))end
         in F.append(unused"rules"unusedRules)
             (F.defer(fn()=>F.append(unused"terminals"unusedTokens)(F.defer conflicts)))end)
       val header=D.delay(fn()=>SOME(F.append(case D.force hd of NONE=>emptyText|SOME t=>t)(X.text"\n")))
   in(warnings,produceParser grammar action goto header tl)end
 fun emitOutput input emitWarning emitBody=
   let val(warnings,body)=generate input
       fun stream emit text=case D.force text of F.Nil=>()
         |F.Cons(value,rest)=>(emit(D.force value);stream emit rest)
   in stream emitWarning warnings;stream emitBody body end

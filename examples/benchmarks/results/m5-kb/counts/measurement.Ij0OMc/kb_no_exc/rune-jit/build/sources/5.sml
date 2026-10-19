(* Xavier Leroy, INRIA, 1996; Q Public License version 1.0. *)
functor BenchSandmarkKBCompletionFn(R:sig
  val reducible:BenchSandmarkKBTerms.term->BenchSandmarkKBTerms.term->bool
  val rewriteAll:BenchSandmarkKBTerms.rule list->BenchSandmarkKBTerms.term->BenchSandmarkKBTerms.term
  val prettyTerm:BenchSandmarkKBTerms.term->unit
end) =
struct
  structure T=BenchSandmarkKBTerms
  fun printString _=()
  fun printInt _=()
  fun printNewline()=()
  fun prettyRule(r:T.rule)=(printInt(#number r);printString" : ";
    R.prettyTerm(#lhs r);printString" = ";R.prettyTerm(#rhs r);printNewline())
  fun prettyRules rules=List.app prettyRule rules
  fun super m(n as T.Term(_,sons))=
      let fun collate _ []=[]
            |collate index(son::rest)=
              List.map(fn(path,subs)=>(index::path,subs))(super m son)@collate(index+1)rest
          val insides=collate 1 sons
      in (([],T.unify(m,n))::insides)handle T.Failure _=>insides end
    |super _ _=[]
  fun superStrict m(T.Term(_,sons))=
      let fun collate _ []=[]|collate i(son::rest)=
        List.map(fn(path,subs)=>(i::path,subs))(super m son)@collate(i+1)rest
      in collate 1 sons end
    |superStrict _ _=[]
  fun critical(l1,r1)(l2,r2)=List.map(fn(path,subs)=>
      (T.substitute subs(T.replace l2 path r1),T.substitute subs r2))(super l1 l2)
  fun strictCritical(l1,r1)(l2,r2)=List.map(fn(path,subs)=>
      (T.substitute subs(T.replace l2 path r1),T.substitute subs r2))(superStrict l1 l2)
  fun mutual first second=strictCritical first second@critical second first
  fun rename n(a,b)=
    let fun term(T.Var k)=T.Var(k+n)|term(T.Term(name,sons))=T.Term(name,List.map term sons)
    in(term a,term b)end
  fun deletion(r:T.rule)=(printString"Rule ";printInt(#number r);printString" deleted";printNewline())
  fun nonOrientable(m,n)=(R.prettyTerm m;printString" = ";R.prettyTerm n;printNewline())
  fun partition test []=([],[])
    |partition test(x::xs)=let val(a,b)=partition test xs
      in if test x then(x::a,b)else(a,x::b)end
  fun getRule _ []=raise T.NotFound
    |getRule n((r:T.rule)::rest)=if n= #number r then r else getRule n rest
  fun completion greater=
    let fun kbrec j rules=
          let fun process failures(k,l)[]=
                    if k<l then next failures(k+1,l)
                    else if l<j then next failures(1,l+1)
                    else(case failures of []=>rules|_=>
                      (printString"Non-orientable equations :";printNewline();
                       List.app nonOrientable failures;raise T.Failure "kb_completion"))
                |process failures(k,l)((m,n)::eqs)=
                   let val m'=R.rewriteAll rules m val n'=R.rewriteAll rules n
                       fun enter(left,right)=
                         let val newRule=T.mkRule(j+1)left right
                             val _=prettyRule newRule
                             val(red,irred)=partition(fn(r:T.rule)=>R.reducible left(#lhs r))rules
                             val _=List.app deletion red
                             fun rightReduce(r:T.rule)=T.mkRule(#number r)(#lhs r)(R.rewriteAll(newRule::rules)(#rhs r))
                             val irreds=List.map rightReduce irred
                             val eqs'=List.map(fn(r:T.rule)=>(#lhs r,#rhs r))red
                         in kbrec(j+1)(newRule::irreds)[](k,l)(eqs@eqs'@failures)end
                   in if m'=n' then process failures(k,l)eqs
                      else if greater(m',n')then enter(m',n')
                      else if greater(n',m')then enter(n',m')
                      else process((m',n')::failures)(k,l)eqs end
              and next failures(k,l)=
                (let val rl=getRule l rules val el=(#lhs rl,#rhs rl)
                 in if k=l then process failures(k,l)(strictCritical el(rename(#numvars rl)el))
                    else(let val rk=getRule k rules val ek=(#lhs rk,#rhs rk)
                         in process failures(k,l)(mutual el(rename(#numvars rl)ek))end
                         handle T.NotFound=>next failures(k+1,l))end
                 handle T.NotFound=>next failures(1,l+1))
          in process end
    in kbrec end
  fun complete greater completeRules rules=
    let val n=T.checkRules completeRules
        val eqs=List.map(fn(r:T.rule)=>(#lhs r,#rhs r))rules
        val result=completion greater n completeRules[](n,n)eqs
        val _=(printString"Canonical set found :";printNewline();prettyRules(List.rev result))
    in result end
end

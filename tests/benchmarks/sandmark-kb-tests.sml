functor SandmarkKBTestsFn(P:sig
  val policy:string
  structure R:sig
    val reducible:BenchSandmarkKBTerms.term->BenchSandmarkKBTerms.term->bool
    val rewriteAll:BenchSandmarkKBTerms.rule list->BenchSandmarkKBTerms.term->BenchSandmarkKBTerms.term
    val prettyTerm:BenchSandmarkKBTerms.term->unit
  end
end) =
struct
  structure K=BenchSandmarkKBTerms
  structure C=BenchSandmarkKBCompletionFn(P.R)
  structure Driver=BenchSandmarkKBDriverFn(C)
  fun label s="sandmark-kb/"^P.policy^"/"^s
  val base=""
  val rules=C.complete BenchSandmarkKBOrder.greater[]BenchSandmarkKBData.rules
  val reference=Driver.read(base^"kb.rules")
  val _=T.check(label"complete-source-rules",fn()=>String.concat(List.map K.canonicalRule rules)=reference)
  val _=T.check(label"rule-count",fn()=>List.length rules=24)
  val _=List.app(fn(r:K.rule)=>T.check(label("oriented-"^Int.toString(#number r)),fn()=>
     BenchSandmarkKBOrder.greater(#lhs r,#rhs r)))rules
  val _=List.app(fn(r:K.rule)=>T.check(label("normal-rhs-"^Int.toString(#number r)),fn()=>
     P.R.rewriteAll rules(#rhs r)= #rhs r))rules
  val _=List.app(fn(r:K.rule)=>T.check(label("source-equation-"^Int.toString(#number r)),fn()=>
     P.R.rewriteAll rules(#lhs r)=P.R.rewriteAll rules(#rhs r)))BenchSandmarkKBData.rules
  val pairs=List.concat(List.map(fn(a:K.rule)=>List.map(fn(b:K.rule)=>(a,b))rules)rules)
  val _=List.app(fn(a:K.rule,b:K.rule)=>T.check(
     label("critical-pairs-"^Int.toString(#number a)^"-"^Int.toString(#number b)),fn()=>
     List.all(fn(x,y)=>P.R.rewriteAll rules x=P.R.rewriteAll rules y)
       (C.critical(#lhs a,#rhs a)(C.rename(#numvars a)(#lhs b,#rhs b)))))pairs
  val _=T.check(label"repeat-driver",fn()=>Driver.run["2",base^"kb.rules"]="2:48")
  val _=T.check(label"zero-driver",fn()=>Driver.run["0",base^"kb.rules"]="0:0")
  val _=T.check(label"source-variable-standardization",fn()=>
    let val r=K.mkRule 9(K.Term("f",[K.Var 7,K.Var 9]))(K.Var 7)
    in #numvars r=2 andalso K.vars(#lhs r)=[1,2]andalso #rhs r=K.Var 1 end)
  val _=T.check(label"source-path-replacement",fn()=>
    K.replace(K.Term("f",[K.Var 1,K.Term("g",[K.Var 2])]))[2,1](K.Term("z",[]))=
      K.Term("f",[K.Var 1,K.Term("g",[K.Term("z",[])])]))
  val _=T.check(label"occurs-check",fn()=>
    ((K.unify(K.Var 1,K.Term("f",[K.Var 1]));false)handle K.Failure _=>true))
  val _=T.check(label"unifier-validates-both-sides",fn()=>
    let val a=K.Term("f",[K.Var 1,K.Term("a",[])])
        val b=K.Term("f",[K.Term("b",[]),K.Var 2])
        val s=K.unify(a,b)
    in K.substitute s a=K.substitute s b end)
  val _=T.check(label"wrong-arity-remains-invalid",fn()=>
    ((K.unify(K.Term("f",[]),K.Term("f",[K.Var 1]));false)handle K.Invalid _=>true))
end
structure RaiseTests=SandmarkKBTestsFn(struct val policy="raise"structure R=BenchSandmarkKBRaise end)
structure OptionTests=SandmarkKBTestsFn(struct val policy="option"structure R=BenchSandmarkKBOption end)
structure KBControls =
struct
  structure K=BenchSandmarkKBTerms
  val a=K.Term("a",[])val b=K.Term("b",[])
  val pattern=K.Term("f",[K.Var 1,K.Var 1])
  val good=K.Term("f",[a,a])val bad=K.Term("f",[a,b])
  val _=T.check("sandmark-kb/raise/matching-repeated-variable",fn()=>BenchSandmarkKBRaise.matching pattern good=[(1,a)])
  val _=T.check("sandmark-kb/option/matching-repeated-variable",fn()=>BenchSandmarkKBOption.matching pattern good=SOME[(1,a)])
  val _=T.check("sandmark-kb/raise/matching-conflict",fn()=>((BenchSandmarkKBRaise.matching pattern bad;false)handle K.Failure _=>true))
  val _=T.check("sandmark-kb/option/matching-conflict",fn()=>BenchSandmarkKBOption.matching pattern bad=NONE)
  structure Wrong=BenchSandmarkKBDriverFn(struct fun complete _ _ _=[]end)
  val _=T.check("sandmark-kb/checker/changed-completed-rules",fn()=>
    ((Wrong.run["1","kb.rules"];false)handle Fail _=>true))
end

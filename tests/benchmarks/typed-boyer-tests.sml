structure TypedBoyerNeed=BenchTypedBoyerFn(BenchNeed)
structure TypedBoyerStrict=BenchTypedBoyerFn(BenchStrict)
structure TypedBoyerNeedCheck=TypedBoyerFormCheckFn(TypedBoyerNeed)
structure TypedBoyerStrictCheck=TypedBoyerFormCheckFn(TypedBoyerStrict)
structure TypedBoyerTests=
struct
 structure N=TypedBoyerNeed
 structure L=BenchLazy
 structure S=BenchStream
 fun id name=
  let fun find i=if i=Vector.length BenchBoyerIds.names then raise Fail "unknown ID"
        else if Vector.sub(BenchBoyerIds.names,i)=name then i else find(i+1)
  in find 0 end
 val expected=[("A",false),("B",false),("C",false),("D",false),("X",true),("Y",false),("Z",false),("U",false),("W",false)]
 val _=List.app(fn(name,result)=>
  (T.check("typed-boyer/lazy-source-variable-"^name,fn()=>N.test(id name)=result);
   T.check("typed-boyer/strict-source-variable-"^name,fn()=>TypedBoyerStrict.test(id name)=result)))expected
 val _=T.check("typed-boyer/complete-original-input",fn()=>(TypedBoyerNeedCheck.original BenchBoyerIds.xId "input.term";true))
 val _=T.check("typed-boyer/complete-lazy-normal",fn()=>(TypedBoyerNeedCheck.normal BenchBoyerIds.xId "normal.term";true))
 val _=T.check("typed-boyer/complete-strict-normal",fn()=>(TypedBoyerStrictCheck.normal BenchBoyerIds.xId "normal.term";true))
 val _=T.check("typed-boyer/equality-ignores-recursive-lemmas",fn()=>
  let val bad=L.delay(fn()=>raise Fail "lemmas demanded")
      val a=BenchNeed.delay(fn()=>N.Fun(id "F",N.noArgs,bad))
      val b=BenchNeed.delay(fn()=>N.Fun(id "F",N.noArgs,S.empty()))
  in N.equal a b end)
 val _=T.check("typed-boyer/failed-unification-env-not-demanded",fn()=>
  let val first=N.app(id "F")(fn()=>[])
      val second=N.app(id "PLUS")(fn()=>[])
      val(matched,_)=N.unify first second(L.delay(fn()=>[]))
  in not matched end)
 val _=T.check("typed-boyer/failed-unification-env-bottom-preserved",fn()=>
  let val first=N.app(id "F")(fn()=>[])
      val second=N.app(id "PLUS")(fn()=>[])
      val(_,environment)=N.unify first second(L.delay(fn()=>[]))
  in (ignore(L.force environment);false)handle Fail message=>message="unify"end)
 val _=T.check("typed-boyer/unification-requires-both-list-ends",fn()=>
  let val first=N.app(id "F")(fn()=>[])
      val second=N.app(id "F")(fn()=>[N.variable(id "X")])
  in not(#1(N.unify first second(L.delay(fn()=>[]))))end)
 val _=T.check("typed-boyer/head-failure-does-not-force-tail",fn()=>
  let val bad=BenchNeed.delay(fn()=>raise Fail "argument tail demanded")
      val args=BenchNeed.delay(fn()=>N.ACons(N.app(id "F")(fn()=>[]),bad))
      val patterns=BenchNeed.delay(fn()=>N.ACons(N.app(id "PLUS")(fn()=>[]),bad))
  in not(#1(N.unifyArgs args patterns(L.delay(fn()=>[]))))end)
 val _=T.check("typed-boyer/strict-retains-lazy-recursive-rule-graph",fn()=>
   TypedBoyerStrict.equal(TypedBoyerStrict.app(id "FOUR")(fn()=>[]))(TypedBoyerStrict.app(id "FOUR")(fn()=>[])))
 fun rejects path=(TypedBoyerNeedCheck.normal BenchBoyerIds.xId path;false)
   handle Fail message=>String.isPrefix "incorrect result:" message
 val _=T.check("typed-boyer/wrong-normal-rejected",fn()=>rejects "wrong.term")
 val _=T.check("typed-boyer/truncated-rejected",fn()=>rejects "truncated.term")
 val _=T.check("typed-boyer/extra-rejected",fn()=>rejects "extra.term")
end

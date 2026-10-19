functor ParserDemandFn(structure D:BENCH_SUSPEND val strict:bool val label:string)=struct
 structure K=BenchNofibParserFn(D)
 structure L=BenchLazy
 structure X=K.X
 exception Demanded
 val env=K.hsPrecTable
 fun poisonTokens()=L.delay(fn()=>raise Demanded)
 fun failParser _ _=L.delay(fn()=>K.PFail K.eof)
 fun mustSkip _ _=raise Demanded
 fun success result=case L.force result of K.POk _=>true|_=>false
 fun failure result=case L.force result of K.PFail _=>true|_=>false
 fun check name valid=if valid then print("PASS "^label^" "^name^"\n")else raise Fail name
 val _=check"first-empty-alternative-skips-input-and-rest"
   (success(K.pgAlts[K.pgEmpty(K.cell 42),mustSkip]env(poisonTokens())))
 val _=check"sequence-failure-skips-later-parser"
   (failure(K.pgThen2(fn _=>fn _=>raise Demanded)failParser mustSkip env(poisonTokens())))
 val _=check"failed-line-parser-skips-input"
   (failure(K.pgGetLineNumber failParser env(poisonTokens())))
 fun error line:X.token L.delay=L.delay(fn()=>(X.pos line,L.delay(fn()=>raise Demanded),X.Lvar,X.text""))
 val initial=error 0 val nearer=error 10 val further=error 20
 fun fail token _ _=L.delay(fn()=>K.PFail token)
 val result:int K.result=K.pgAlts[fail nearer,fail further]env(X.C.cons(initial,X.C.empty()))
 val _=check"furthest-line-skips-unused-columns"
   (case L.force result of K.PFail token=>K.tokenLine token=20|_=>false)
 val hits=ref 0
 val parsed=K.pgApply(fn _=>D.delay(fn()=>(hits:= !hits+1;42)))
   (K.pgEmpty(K.cell 0))env(X.C.empty())
 val value=case L.force parsed of K.POk(_,_,value)=>value|_=>raise Fail"success"
 val _=check"semantic-attribute-demand"
   (!hits=(if strict then 1 else 0)andalso D.force value=42 andalso D.force value=42 andalso !hits=1)
end
structure NeedParserDemand=ParserDemandFn(structure D=BenchNeed val strict=false val label="need")
structure StrictParserDemand=ParserDemandFn(structure D=BenchStrict val strict=true val label="strict")

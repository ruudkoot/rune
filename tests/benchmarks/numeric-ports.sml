structure BenchNumericPortTests =
struct
  fun rejects f = (f();false) handle Fail _=>true
  val state=Benchmark.calculate 4
  val _=T.check("kahan/exact-oracle",fn()=>(Benchmark.validate 4 "expected/smoke.txt" state;true))
  fun changedSum(j,delta)=
    let val (s,c)=state
        val altered=Array.tabulate(100,fn i=>Array.sub(s,i)+(if i=j then delta else 0.0))
    in (altered,c)end
  val _=T.check("kahan/exact-seed-coordinate-rejected",fn()=>rejects(fn()=>Benchmark.validate 4 "expected/smoke.txt" (changedSum(0,1.0))))
  val _=T.check("kahan/perturbed-sum-rejected",fn()=>rejects(fn()=>Benchmark.validate 4 "expected/smoke.txt" (changedSum(50,1.0E15))))
  val _=T.check("kahan/perturbed-correction-rejected",fn()=>
    let val(s,c)=state val altered=Array.tabulate(100,fn i=>if i=50 then 1.0E15 else Array.sub(c,i))
    in rejects(fn()=>Benchmark.validate 4 "expected/smoke.txt" (s,altered))end)
  val _=T.check("complex/root-power",fn()=>
    (BenchX2N1.consume(64,BenchX2N1.term 64);true))
  val _=T.check("complex/perturbed-term-rejected",fn()=>rejects(fn()=>(BenchX2N1.consume(64,(1.01,0.0));())))
  val _=T.check("complex/perturbed-imaginary-rejected",fn()=>rejects(fn()=>(BenchX2N1.consume(64,(1.0,0.01));())))
  val _=T.check("complex/perturbed-total-rejected",fn()=>rejects(fn()=>(BenchX2N1.validate 64 (64.01,0.0);())))
  val _=T.check("complex/nonfinite-total-rejected",fn()=>rejects(fn()=>(BenchX2N1.validate 64 (0.0/0.0,0.0);())))
  val _=T.check("integrate/polynomial-oracle",fn()=>
    (BenchIntegrate.checked 1 (0.0,1.0,1.0) "integration-reference.txt";true))
  val _=T.check("integrate/perturbed-error-rejected",fn()=>rejects(fn()=>(BenchIntegrate.checked 1 (0.01,1.0,1.0) "integration-reference.txt";())))
  val _=T.check("integrate/perturbed-running-total-rejected",fn()=>rejects(fn()=>(BenchIntegrate.checked 1 (0.0,1.1,1.0) "integration-reference.txt";())))
  val _=T.check("rational/sign-and-reduction",fn()=>BenchRational.ratio(6,~12)=(~1,2))
  val _=T.check("rational/cross-product-reduction",fn()=>BenchRational.add((1,6),(1,3))=(1,2))
  val _=T.check("rational/haskell-show",fn()=>BenchRational.show(~1,30)="(-1) % 30")
  val _=T.check("hash/machine-width",fn()=>
    BenchNofibHash.signed "(-1215233140483755572040304994079820246041491) % 56786730"="4837159772545863515")
end

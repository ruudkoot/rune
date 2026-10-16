structure EvolutionTests =
struct
  structure K=BenchEvolutionary structure C=EvolutionCheck
  fun bits xs=Array.fromList xs
  fun individual xs=K.evaluate K.onemax(bits xs)
  fun rejects f=(f();false)handle Fail _=>true
  val _=T.check("evolution/onemax",fn()=>Real.==(K.onemax(bits[true,false,true]),2.0))
  val _=T.check("evolution/ties-choose-second",fn()=>
    let val a=individual[true,false]val b=individual[false,true]
    in K.chromosome(K.fittest a b)=K.chromosome b end)
  val _=T.check("evolution/better-fitness",fn()=>
    let val a=individual[true,true]val b=individual[false,true]
    in K.chromosome(K.fittest a b)=K.chromosome a end)
  val _=T.check("evolution/zero-mutation-still-draws-and-copies",fn()=>
    let val state=BenchOCamlRandom.seed42()val parent=bits[true,false,true]
        val child=K.mutate state 0.0 parent
    in Array.foldr(op ::)[]child=[true,false,true]andalso child<>parent andalso !(#index state)=6 end)
  val _=T.check("evolution/certain-mutation",fn()=>
    let val parent=bits[true,false,true]val child=K.mutate(BenchOCamlRandom.seed42())6.0 parent
    in Array.foldr(op ::)[]child=[false,true,false]andalso Array.foldr(op ::)[]parent=[true,false,true]end)
  val _=T.check("evolution/tournament-one-still-draws",fn()=>
    let val state=BenchOCamlRandom.seed42()val pop=Array.fromList[individual[true],individual[false]]
        val _=K.tournament state 1 pop
    in !(#index state)=1 end)
  val _=T.check("evolution/budget-zero-extra-generations",fn()=>
    let val evaluated=ref 0
        fun fitness x=(evaluated:= !evaluated+1;K.onemax x)
        val _=K.run(BenchOCamlRandom.seed42())0 2 2 0.4 fitness 3
    in !evaluated=6 end)
  val _=T.check("evolution/budget-inclusive-check",fn()=>
    let val evaluated=ref 0
        fun fitness x=(evaluated:= !evaluated+1;K.onemax x)
        val _=K.run(BenchOCamlRandom.seed42())4 2 2 0.4 fitness 3
    in !evaluated=10 end)
  val _=T.check("evolution/complete-tiny-source-population",fn()=>(C.run 3 2 0 "tiny.expected";true))
  val _=T.check("evolution/complete-smoke-source-population",fn()=>(C.run 16 16 128 "smoke.expected";true))
  val _=T.check("evolution/perturbed-chromosome-rejected",fn()=>
    let val pop=K.run(BenchOCamlRandom.seed42())0 2 2 0.4 K.onemax 3
        val chromosome=K.chromosome(Array.sub(pop,0))val _=Array.update(chromosome,0,not(Array.sub(chromosome,0)))
    in rejects(fn()=>C.check 3 2 "tiny.expected"pop)end)
  val _=T.check("evolution/population-size-rejected",fn()=>
    rejects(fn()=>C.check 3 2 "tiny.expected"(Array.fromList[individual[true,false,false]])))
end

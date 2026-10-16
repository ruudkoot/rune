structure CryptarithmPermutationCount =
struct
 structure Kernel=BenchCryptarithmPermutationFn(BenchNeed)
 val visited=ref 0
 val selected=Kernel.filter(fn row=>(visited:= !visited+1;Kernel.condition row))
       (Kernel.permutations(Kernel.S.fromList(List.tabulate(10,fn i=>i))))
 val result=Kernel.renderRows selected
 val _=T.check("cryptarithm1/visits-all-10-factorial-candidates",fn()=> !visited=3628800)
 val _=T.check("cryptarithm1/exhaustive-result",fn()=>result="[[1,9,4,2,5,3,0,7,6,8]]\n")
end

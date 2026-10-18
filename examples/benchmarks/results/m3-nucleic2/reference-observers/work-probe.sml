functor WorkProbeFn(structure D:BENCH_SUSPEND val shared:bool val label:string)=struct
 structure K=BenchNucleic2Fn(structure D=D val shared=shared)
 val total=Array.array(3,0)
 val passed=Array.array(3,0)
 fun add array i=Array.update(array,i,Array.sub(array,i)+1)
 fun predicate v partial=
   let val K.Var(i,_,_)=D.force v
       val pass=K.pseudoknot_constraint v partial
       val _=add total 0
       val _=if pass then add passed 0 else()
       val group=if i=18 then 1 else if i=6 then 2 else 0
       val _=if group=0 then()else(add total group;if pass then add passed group else())
   in pass end
 val solutions=K.search(K.F.empty())K.pseudoknot_domains predicate
 val result=D.force(K.most_distant_atom solutions)
 val counts=List.concat(List.tabulate(3,fn i=>[Array.sub(total,i),Array.sub(passed,i)]))
 val _=print(label^" "^String.concatWith","(List.map Int.toString counts)^" "^Real.toString result^"\n")
end
structure NeedDefaultWork=WorkProbeFn(structure D=BenchNeed val shared=false val label="on-demand-need")
structure StrictDefaultWork=WorkProbeFn(structure D=BenchStrict val shared=false val label="on-demand-strict")
structure NeedSharedWork=WorkProbeFn(structure D=BenchNeed val shared=true val label="shared-need")
structure StrictSharedWork=WorkProbeFn(structure D=BenchStrict val shared=true val label="shared-strict")

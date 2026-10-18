functor BenchDomDriverFn(P:sig val idom:BenchDomGraph.rooted->(int*int)list end)=
struct
  structure R=BenchDomReader
  fun calculate graphs argument expected=
    let val _=if length graphs=length expected then()else raise Fail "expected dominator results for every graph"
        fun pass iteration=
          let fun loop [] [] total=total
                |loop(graph::rest)(want::results)total=
                   let val actual=P.idom graph
                   in if actual=want then loop rest results(total+iteration+length actual)
                      else raise Fail "incorrect result: dominator pairs"end
                |loop _ _ _=raise Fail "dominator graph/result count"
          in loop graphs expected 0 end
        fun repeat iteration total=if iteration>argument then total
          else repeat(iteration+1)(total+pass iteration)
    in repeat 0 0 end
  fun run[path,repetitions,reference]=
    let val argument=BenchInput.between(0,2000)(BenchInput.integer repetitions)
        val graphs=R.graphs(R.read path)
        val expected=R.results(R.read reference)
    in Int.toString(calculate graphs argument expected)end
    |run _=raise Fail "expected graph file, repetition argument and dominator reference"
end

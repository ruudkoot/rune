structure EvolutionCheck =
struct
 structure K=BenchEvolutionary
 fun check n lambda expected population=
   let val input=TextIO.openIn expected val text=TextIO.inputAll input val _=TextIO.closeIn input
       val fields=String.tokens Char.isSpace text
       fun integer s=BenchInput.integer s
       fun individual index fitness chromosome=
         let val({chromosome=actual,fitness=score}:K.individual)=Array.sub(population,index)
             val wanted=integer fitness
             val _=if String.size chromosome=n andalso Array.length actual=n andalso
               Real.==(score,Real.fromInt wanted)andalso Real.==(K.onemax actual,score)
               then()else raise Fail "incorrect result: individual fitness or dimensions differ"
         in K.for 0(n-1)(fn i=>let val c=String.sub(chromosome,i)
              in if c<> #"0"andalso c<> #"1"then raise Fail "invalid chromosome reference"
                 else if Array.sub(actual,i)=(c= #"1")then()
                 else raise Fail "incorrect result: chromosome differs"end)end
       fun rows i []=if i=lambda then()else raise Fail "incorrect result: missing individuals"
         | rows i(fitness::chromosome::rest)=if i<lambda then(individual i fitness chromosome;rows(i+1)rest)
           else raise Fail "incorrect result: extra individuals"
         | rows _ _=raise Fail "invalid population reference"
   in case fields of count::width::best::rest=>
       if integer count=lambda andalso integer width=n andalso Array.length population=lambda
       then(rows 0 rest;if Real.==(#fitness(K.popFittest population),Real.fromInt(integer best))then()
          else raise Fail "incorrect result: fittest individual differs")
       else raise Fail "incorrect result: population dimensions differ"
      | _=>raise Fail "missing population reference"end
 fun run n lambda budget path=
   let val state=BenchOCamlRandom.seed42()
       val population=K.run state budget lambda 2 0.4 K.onemax n
   in check n lambda path population end
end

functor BenchNucleic2CheckFn(K:sig val compute:string->real end)=struct
 val reference=33.7975921630859375
 val relative=0.000001
 fun valid value=Real.isFinite value andalso Real.abs(value-reference)<=relative*Real.abs reference
 fun run[countText]=
   let val count=BenchInput.between(~100000,100000)(BenchInput.integer countText)
       fun loop completed=if completed>=count then Int.toString completed
         else let val result=K.compute countText
                  val _=if valid result then()else raise Fail"incorrect result: nucleic2 maximum atom distance"
              in loop(completed+1)end
   in if count<=0 then"0"else loop 0 end
  |run _=raise Fail"expected source repetition count"
end

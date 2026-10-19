functor BenchNofibVeritasCheckFn(K:sig
 type input
 val input:string->input
 val benchmark:input->Word64.word
 val signedHash:Word64.word->string
end)=struct
 fun read file=let val f=TextIO.openIn file
   in(TextIO.inputAll f before TextIO.closeIn f)handle e=>(TextIO.closeIn f;raise e)end
 fun run[countText,inputPath,hashText]=
   let val normalized=if String.isPrefix "-" countText then "~"^String.extract(countText,1,NONE)else countText
       val requested=BenchInput.between(~100000,100000)(BenchInput.integer normalized)
       val count=Int.max(0,requested)
       val chars=BenchLazy.delay(fn()=>K.input(read inputPath))
       val expected=case Word64.fromString("0wx"^hashText)of SOME word=>word|NONE=>raise Fail"bad reviewed Veritas hash"
       fun loop completed=if completed=count then Int.toString completed
         else let val value=K.benchmark(BenchLazy.force chars)
                  val _=if value=expected then()else raise Fail"incorrect result: complete Veritas request stream hash"
                  val _=TextIO.output(TextIO.stdOut,K.signedHash value^"\n")
              in loop(completed+1)end
   in loop 0 end
  |run _=raise Fail"expected source repetitions, scripted input and reviewed modular 64-bit hash"
end

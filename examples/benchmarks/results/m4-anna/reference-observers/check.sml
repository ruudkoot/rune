functor BenchAnnaCheckFn(K:sig
 type input type table
 val input:string->input
 val readTable:input->table
 val benchmark:input->table->Word64.word
 val signedHash:Word64.word->string
end)=struct
 fun read file=let val f=TextIO.openIn file
   in(TextIO.inputAll f before TextIO.closeIn f)handle e=>(TextIO.closeIn f;raise e)end
 fun run[countText,inputPath,hashText]=
   let val count=BenchInput.between(0,100000)(BenchInput.integer countText)
       val chars=BenchLazy.delay(fn()=>K.input(read inputPath))
       val expected=case Word64.fromString("0wx"^hashText)of SOME word=>word|NONE=>raise Fail"bad reviewed Anna hash"
       fun loop completed=if completed=count then Int.toString completed
         else let val table=K.readTable(K.input(read"runtime_files/anna_table"))
                  val value=K.benchmark(BenchLazy.force chars)table
                  val _=if value=expected then()else raise Fail"incorrect result: complete Anna report hash"
                  val _=TextIO.output(TextIO.stdOut,K.signedHash value^"\n")
              in loop(completed+1)end
   in loop 0 end
  |run _=raise Fail"expected source repetitions, source input and reviewed modular 64-bit hash"
end

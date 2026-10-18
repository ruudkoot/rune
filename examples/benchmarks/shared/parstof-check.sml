functor BenchParstofCheckFn(K:sig
 type input
 val input:string->input
 val benchmark:int->input->string
end)=struct
 fun read path=let val f=TextIO.openIn path in
   (TextIO.inputAll f before TextIO.closeIn f)handle e=>(TextIO.closeIn f;raise e)end
 fun run[repsText,countText,inputPath,crcPath]=
   let val reps=BenchInput.between(0,1000)(BenchInput.integer repsText)
       val count=BenchInput.between(1,100)(BenchInput.integer countText)
       val source=read inputPath val expected=read crcPath
       val root=BenchLazy.delay(fn()=>K.input source)
       fun loop 0 iterations parses bytes=Int.toString iterations^":"^Int.toString parses^":"^Int.toString bytes
         |loop n iterations parses bytes=
           let val output=K.benchmark count(BenchLazy.force root)
               val _=if output=expected then()else raise Fail"incorrect result: parstof source checksum"
           in loop(n-1)(iterations+1)(parses+count)(bytes+String.size output)end
   in loop reps 0 0 0 end
 |run _=raise Fail"expected repetitions, programs per iteration, source file and source checksum"
end

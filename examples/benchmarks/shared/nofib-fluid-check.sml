functor BenchFluidCheckFn(K:sig
 type chars type mesh type config
 val input:string->chars
 val readConfig:chars->string*config
 val readMesh:chars->mesh
 val run:config->mesh->chars
 val hash:chars->Word64.word
end)=struct
 fun read path=let val f=TextIO.openIn path
   in(TextIO.inputAll f before TextIO.closeIn f)handle e=>(TextIO.closeIn f;raise e)end
 fun run[count,headerPath,expectedHash]=
   let val count=if String.isPrefix "-"count then "~"^String.extract(count,1,NONE)else count
       val count=Int.max(0,BenchInput.between(~100000,100000)(BenchInput.integer count))
       val source=BenchLazy.delay(fn()=>K.input(read headerPath))
       val expected=case Word64.fromString("0wx"^expectedHash)of SOME w=>w|NONE=>raise Fail"bad source Fluid hash"
       fun loop completed=if completed=count then Int.toString completed else
         let val(file,config)=K.readConfig(BenchLazy.force source)
             val mesh=K.readMesh(K.input(read file))
             val actual=K.hash(K.run config mesh)
             val _=if actual=expected then()else raise Fail"incorrect result: complete Fluid simulation output hash"
         in loop(completed+1)end
   in loop 0 end
  |run _=raise Fail"expected source repetitions, source header file and reviewed modular 64-bit hash"
end

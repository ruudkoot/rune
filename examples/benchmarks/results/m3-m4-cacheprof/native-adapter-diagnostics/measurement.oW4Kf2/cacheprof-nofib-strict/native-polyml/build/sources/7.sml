functor BenchCacheprofCheckFn(K:sig val emitOutput:int->string->(string->unit)->unit end)=
struct
 fun read file=
   let val stream=TextIO.openIn file
   in (TextIO.inputAll stream before TextIO.closeIn stream)
       handle ex=>(TextIO.closeIn stream;raise ex)end
 fun selectedInput file=
   let val text=read file
   in if String.size text<=9999999 then text else String.substring(text,0,9999999)end
 fun consumer expected=
   let val offset=ref 0
       fun emit text=
         let val start= !offset val size=String.size text
             fun compare i=if i=size then()else
               if start+i<String.size expected andalso String.sub(text,i)=String.sub(expected,start+i)
               then compare(i+1)else raise Fail"incorrect result: Cacheprof annotated assembly"
         in compare 0;offset:=start+size end
       fun finish()=if !offset=String.size expected then !offset
                    else raise Fail"incorrect result: truncated Cacheprof annotated assembly"
   in(emit,finish)end
 fun runRaw[inputPath,referencePath,hooksPath]=
   let val input=selectedInput inputPath
       val expected=read referencePath
       val hooks=read hooksPath
       val(emit,finish)=consumer expected
       val _=K.emitOutput 2 input emit
       val _=emit hooks
   in Int.toString(finish())end
   |runRaw _=raise Fail"expected assembly input, complete output reference and hooks text"
 fun runForced[repetitionsText,inputPath,referencePath,hooksPath]=
   let val repetitions=BenchInput.between(0,2000)(BenchInput.integer repetitionsText)
       val input=selectedInput inputPath
       val expected=read referencePath
       fun loop 0 count total=Int.toString count^":"^Int.toString total
         |loop n count total=
           let val hooks=TextIO.openIn hooksPath
               val _=TextIO.closeIn hooks
               val(emit,finish)=consumer expected
               val _=K.emitOutput 2 input emit
               val bytes=finish()
           in loop(n-1)(count+1)(total+bytes)end
   in loop repetitions 0 0 end
   |runForced _=raise Fail"expected repetitions, assembly input, complete output reference and hooks path"
end

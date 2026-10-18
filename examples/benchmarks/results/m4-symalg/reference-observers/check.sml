functor BenchSymalgCheckFn(K:sig
 val numberObserver:(string->unit)ref
 val streamTranscript:(string->unit)->string list->unit
end)=
struct
 fun read path=
   let val input=TextIO.openIn path
   in (TextIO.inputAll input before TextIO.closeIn input)
      handle ex=>(TextIO.closeIn input;raise ex)end
 fun run[scriptPath,numbersPath,outputPath]=
   let val script=String.fields(fn c=>c= #"\n")(read scriptPath)
       val numbers=Vector.fromList(String.tokens(fn c=>c= #"\n")(read numbersPath))
       val output=read outputPath
       val numberIndex=ref 0
       val outputIndex=ref 0
       fun observe text=
         if !numberIndex>=Vector.length numbers orelse text<>Vector.sub(numbers,!numberIndex)
         then raise Fail"incorrect result: Symalg complete numeric value"
         else numberIndex:= !numberIndex+1
       fun emit text=
         let val length=String.size text val start= !outputIndex
             fun compare i=if i=length then()else
               if start+i<String.size output andalso String.sub(text,i)=String.sub(output,start+i)
               then compare(i+1)else raise Fail"incorrect result: Symalg source transcript"
         in compare 0;outputIndex:=start+length end
       val previous= !K.numberObserver
       val _=K.numberObserver:=observe
       val _=(K.streamTranscript emit script before K.numberObserver:=previous)
               handle ex=>(K.numberObserver:=previous;raise ex)
       val _=if !numberIndex=Vector.length numbers andalso !outputIndex=String.size output
             then()else raise Fail"incorrect result: incomplete Symalg validation"
   in Int.toString(!numberIndex)^":"^Int.toString(!outputIndex)end
 |run _=raise Fail"expected script, complete numeric references and source transcript"
end

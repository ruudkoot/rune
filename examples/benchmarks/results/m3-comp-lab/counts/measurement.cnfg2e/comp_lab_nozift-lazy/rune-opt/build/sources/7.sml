functor BenchCompLabCheckFn(K:sig
 val rendered:bool->int->int->int->string
 val sumcode:string->string
end)=
struct
 fun read file=
   let val input=TextIO.openIn file
   in (TextIO.inputAll input before TextIO.closeIn input)
      handle ex=>(TextIO.closeIn input;raise ex)end
 fun run useSift[repetitionsText,sizeText,thresholdText,path,wantedCode]=
   let val repetitions=BenchInput.between(0,1000)(BenchInput.integer repetitionsText)
       val size=BenchInput.between(1,12)(BenchInput.integer sizeText)
       val threshold=BenchInput.between(0,1000000)(BenchInput.integer thresholdText)
       val expected=read path
       fun loop 0 count total=Int.toString count^":"^Int.toString total
         |loop n count total=
           let val actual=K.rendered useSift 3 size threshold
               val _=if actual=expected andalso K.sumcode actual=wantedCode then()
                     else raise Fail"incorrect result: connected-component image, ranges or object trees"
           in loop(n-1)(count+1)(total+String.size actual)end
   in loop repetitions 0 0 end
 |run _ _=raise Fail"expected repetitions, tiling factor, branch threshold, complete reference and sumcode"
end

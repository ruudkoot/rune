functor BenchWaveCheckFn(K:sig
  type matrix
  type solution
  val solve:int->solution
  val matrices:solution->matrix list
  val bounds:matrix->int*int*int*int
  val flatten:matrix->real list
  val output:solution->string
  val sumcode:string->string
end)=
struct
 type expected=(int*int*int*int)*real vector
 fun close(actual,wanted)=Real.isFinite actual andalso Real.isFinite wanted andalso
   Real.abs(actual-wanted)<=1.0E~10+1.0E~10*Real.abs wanted
 fun check values expected=
   List.length values=Vector.length expected andalso
   let fun loop [] _=true|loop(x::xs)i=close(x,Vector.sub(expected,i))andalso loop xs(i+1)
   in loop values 0 end
 fun verify solution expected wantedCode=
   let val matrices=K.matrices solution
       fun loop [] []=()
         |loop(matrix::rest)((bounds,values)::expected)=
           if K.bounds matrix=bounds andalso check(K.flatten matrix)values then loop rest expected
           else raise Fail"incorrect result: wave matrix"
         |loop _ _=raise Fail"incorrect result: wave matrix count"
       val _=loop matrices expected
   in if K.sumcode(K.output solution)=wantedCode then()else raise Fail"incorrect result: wave formatted checksum"end
 fun read path=
   let val stream=TextIO.openIn path
       val text=(TextIO.inputAll stream before TextIO.closeIn stream)
         handle ex=>(TextIO.closeIn stream;raise ex)
       val tokens=ref(String.tokens Char.isSpace text)
       fun next()=case !tokens of []=>raise Fail"truncated wave reference"|x::xs=>(tokens:=xs;x)
       fun integer()=case Int.fromString(next())of SOME n=>n|NONE=>raise Fail"invalid wave reference integer"
       fun real()=case Real.fromString(next())of SOME x=>x|NONE=>raise Fail"invalid wave reference real"
       val steps=integer()val code=next()^"\n"
       fun matrix()=
         let val x0=integer()val x1=integer()val y0=integer()val y1=integer()
             val _=if x0>=0 andalso x1<=8 andalso x1>=x0 andalso y0>=0 andalso y1<=8 andalso y1>=y0 then()
                   else raise Fail"invalid wave reference bounds"
             val values=Vector.tabulate((x1-x0+1)*(y1-y0+1),fn _=>real())
         in((x0,x1,y0,y1),values)end
       val expected=List.tabulate(6,fn _=>matrix())
       val _=if null(!tokens)then()else raise Fail"extra wave reference values"
   in(steps,code,expected)end
 fun run[repetitionsText,stepsText,path]=
   let val repetitions=BenchInput.between(0,5000)(BenchInput.integer repetitionsText)
       val steps=BenchInput.between(0,400)(BenchInput.integer stepsText)
       val(wantedSteps,code,expected)=read path
       val _=if steps=wantedSteps then()else raise Fail"wave reference step mismatch"
       fun loop 0 count=Int.toString count^":208"
         |loop n count=(verify(K.solve steps)expected code;loop(n-1)(count+1))
   in loop repetitions 0 end
 |run _=raise Fail"expected repetitions, time steps and full numeric reference"

end

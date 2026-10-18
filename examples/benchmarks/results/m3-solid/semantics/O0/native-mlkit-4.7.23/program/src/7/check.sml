functor BenchSolidCheckFn(K:sig val evaluate:string->int->real end)=
struct
 fun read file=
   let val input=TextIO.openIn file
   in(TextIO.inputAll input before TextIO.closeIn input)
      handle ex=>(TextIO.closeIn input;raise ex)end
 fun integer text=case Int.fromString text of SOME n=>n|NONE=>raise Fail"invalid solid count reference"
 fun power 0 n=n|power depth n=power(depth-1)(n*4)
 fun references file=
   let val rows=List.map(String.tokens Char.isSpace)(String.tokens(fn c=>c= #"\n")(read file))
       fun parse[depth,count,formatted]=(integer depth,integer count,formatted)
         |parse _=raise Fail"invalid solid reference row"
   in Vector.fromList(List.map parse rows)end
 fun run[repetitionsText,depthText,scenePath,referencePath]=
   let val repetitions=BenchInput.between(0,2000)(BenchInput.integer repetitionsText)
       val maximum=BenchInput.between(1,12)(BenchInput.integer depthText)
       val scene=read scenePath val expected=references referencePath
       fun depths depth count bytes=
         if depth>maximum then(count,bytes)
         else let val(d,wanted,formatted)=Vector.sub(expected,depth)
                  val actual=K.evaluate scene depth
                  val _=if d=depth andalso Real.isFinite actual andalso
                     Real.==(actual*Real.fromInt(power depth 1),Real.fromInt wanted)then()
                     else raise Fail"incorrect result: solid dyadic area count"
                  val output=Real.fmt(StringCvt.FIX(SOME 24))actual
                  val _=if output=formatted then()else raise Fail"incorrect result: solid area formatting"
              in depths(depth+1)(count+1)(bytes+String.size output+1)end
       fun loop 0 count values bytes=Int.toString count^":"^Int.toString values^":"^Int.toString bytes
         |loop n count values bytes=
           let val(done,size)=depths 1 0 0
           in loop(n-1)(count+1)(values+done)(bytes+size)end
   in loop repetitions 0 0 0 end
 |run _=raise Fail"expected repetitions, maximum depth, fixed scene and area references"
end

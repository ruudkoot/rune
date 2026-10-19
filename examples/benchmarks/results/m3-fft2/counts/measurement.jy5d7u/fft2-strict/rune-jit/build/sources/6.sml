(* Rex Page's Fourier benchmark: numerical checks and the original quoted
   result-string demand, with portable SML formatting. *)
functor BenchFFT2DriverFn(K:sig val run:real->real list end) =
struct
 fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
   val _=TextIO.closeIn f in text end
 fun real text=case Real.fromString text of SOME x=>if Real.isFinite x then x
       else raise Fail "nonfinite fft2 reference"|_=>raise Fail "invalid fft2 real"
 fun reference text=List.map(fn row=>case String.tokens Char.isSpace row of
       [a,b,c]=>[real a,real b,real c]|_=>raise Fail "fft2 reference expects triples")
     (String.tokens(fn c=>c= #"\n")text)
 val epsilon=2.220446049250313080847263336181640625E~16
 fun bounds size=
   let val n=Real.fromInt size
   in[(1.0E~9,1.0E~10),(128.0*epsilon*n*n*Math.sqrt n,0.0),
      (128.0*epsilon*n*n*n,0.0)]end
 fun valid size values wanted=
   List.length values=3 andalso List.length wanted=3 andalso
     ListPair.allEq(fn((value,expected),(absolute,relative))=>
       BenchInput.closeReal(value,expected,absolute,relative))
       (ListPair.zip(values,wanted),bounds size)
 fun number value=
   let val text=String.translate(fn #"~"=>"-"| #"E"=>"e"|c=>String.str c)
         (Real.fmt(StringCvt.GEN(SOME 17))value)
   in if List.exists(fn c=>c= #"."orelse c= #"e")(String.explode text)then text else text^".0"end
 fun quote text="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"
      |c=>String.str c)text^"\""
 fun unquote text=
   let fun loop []=raise Fail "short fft2 quoted result"
         |loop[#"\""]=[]
         |loop(#"\\":: #"n"::rest)= #"\n"::loop rest
         |loop(#"\\":: #"\\"::rest)= #"\\"::loop rest
         |loop(#"\\":: #"\""::rest)= #"\""::loop rest
         |loop(c::rest)=c::loop rest
   in case String.explode text of #"\""::rest=>String.implode(loop rest)
     |_=>raise Fail "unquoted fft2 result"end
 fun consume size values=
   let val names=["result1 = ","result2 = ","result3 = "]
       val tokens=List.map number values
       val parsed=List.map real tokens
       val _=if valid size parsed values then()else raise Fail "incorrect result: fft2 numeric rendering"
       val text=String.concat(ListPair.mapEq(fn(name,value)=>name^value^"\n")(names,tokens))
       val shown=quote text
       val expectedLength=2+List.foldl(fn(c,n)=>n+(if c= #"\n"orelse c= #"\\"orelse c= #"\""then 2 else 1))0(String.explode text)
   in if String.size shown=expectedLength andalso unquote shown=text then()
      else raise Fail "incorrect result: fft2 quoted output"end
 fun run[sampleText,baseText,path]=
   let val samples=BenchInput.between(0,100)(BenchInput.integer sampleText)
       val base=real baseText
       val _=if base>=2.0 andalso base<=1024.0 then()else raise Fail "fft2 base outside selected domain"
       val expected=reference(read path)
       val _=if List.length expected>=samples then()else raise Fail "short fft2 reference table"
       fun loop index rows=if index>samples then Int.toString samples^":"^Int.toString(index-1)
         else case rows of []=>raise Fail "short fft2 reference table"
         |wanted::rest=>
           let val bound=base+Real.fromInt index/15.0
               val size=Real.floor(bound+0.5)
               val values=K.run bound
               val _=if valid size values wanted then()else raise Fail "incorrect result: fft2 transform results"
               val _=consume size values
           in loop(index+1)rest end
   in loop 1 expected end
   |run _=raise Fail "fft2 expects sample count, floating base and numerical reference"
end

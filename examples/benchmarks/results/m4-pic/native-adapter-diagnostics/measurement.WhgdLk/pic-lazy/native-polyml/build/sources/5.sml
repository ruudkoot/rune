functor BenchPicDriverFn(K:sig val run:int->real end) =
struct
  structure W=Word64
  fun hash text=
    let fun loop i value=if i=String.size text then value
          else loop(i+1)(W.+(W.fromInt(Char.ord(String.sub(text,i))),W.*(value,0w31)))
    in loop 0 0w0 end
  fun hashReference text=
    let fun loop i power sum=if i<0 then sum
          else loop(i-1)(W.*(power,0w31))
            (W.+(sum,W.*(W.fromInt(Char.ord(String.sub(text,i))),power)))
    in loop(String.size text-1)0w1 0w0 end
  fun checkedText particles value=
    let val text=Real.fmt(StringCvt.GEN(SOME 17))value
        val valid=String.size text>0 andalso List.all(fn c=>
          Char.isDigit c orelse c= #"."orelse c= #"E"orelse c= #"e"orelse
          c= #"~"orelse c= #"+"orelse c= #"-")(String.explode text)
        val roundtrip=case Real.fromString text of SOME parsed=>Real.==(parsed,value)|NONE=>false
        val whole=Int.toString particles^text
    in if valid andalso roundtrip andalso hash whole=hashReference whole then()
       else raise Fail "incorrect result: PIC rendering or modular hash differs"end
  fun reference path=
    let val input=TextIO.openIn path val text=TextIO.inputAll input val _=TextIO.closeIn input
    in case String.tokens Char.isSpace text of [number]=>
         (case Real.fromString number of SOME value=>if Real.isFinite value then value
            else raise Fail "nonfinite PIC reference"|NONE=>raise Fail "invalid PIC reference")
       |_=>raise Fail "PIC reference expects one number"end
  fun run [repeatsText,particlesText,path]=
    let val repeats=BenchInput.between(0,1000)(BenchInput.integer repeatsText)
        val particles=BenchInput.between(1,300)(BenchInput.integer particlesText)
        val wanted=reference path
        fun loop 0 checked=Int.toString particles^":"^Int.toString checked
          |loop count checked=
            let val value=K.run particles
                val _=if BenchInput.closeReal(value,wanted,1.0E~12,1.0E~10)then()
                  else raise Fail "incorrect result: PIC timestep differs"
                val _=checkedText particles value
            in loop(count-1)(checked+1)end
    in loop repeats 0 end
    |run _=raise Fail "PIC expects repetitions, particle count and a timestep reference"
end

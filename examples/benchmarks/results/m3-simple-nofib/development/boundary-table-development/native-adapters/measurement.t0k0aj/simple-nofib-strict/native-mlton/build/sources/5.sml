(* Numerical checks are independent of host decimal formatting. *)
structure BenchSimpleReference=
struct
 val absolute=0.000000000001
 val relative=0.00000000001
 fun close expected actual=Real.isFinite expected andalso Real.isFinite actual
   andalso Real.abs(expected-actual)<=absolute+relative*Real.abs expected
 fun decode text=
   if String.size text<>16 orelse not(List.all Char.isHexDigit(String.explode text))
   then raise Fail"invalid SIMPLE binary64 field"
   else let
     fun digit c=if c>= #"0"andalso c<= #"9"then Char.ord c-Char.ord #"0"
                 else Char.ord(Char.toUpper c)-Char.ord #"A"+10
     val bits=List.foldl(fn(c,n)=>IntInf.+(IntInf.*(n,16),IntInf.fromInt(digit c)))0(String.explode text)
     val two52=IntInf.pow(2,52)
     val exponent=IntInf.toInt(IntInf.mod(IntInf.div(bits,two52),2048))
     val fraction=IntInf.mod(bits,two52)
     val negative=IntInf.div(bits,IntInf.pow(2,63))=1
     val _=if exponent=2047 then raise Fail"nonfinite SIMPLE reference"else()
     val significand=if exponent=0 then fraction else IntInf.+(two52,fraction)
     val magnitude=Real.fromManExp{man=Real.fromLargeInt significand,
                  exp=(if exponent=0 then 1 else exponent)-1023-52}
   in if negative then ~magnitude else magnitude end
 fun read file=
   let val stream=TextIO.openIn file
       val text=TextIO.inputAll stream before TextIO.closeIn stream
   in String.tokens Char.isSpace text end
 fun scalar expected actual=
   if close expected actual then()else raise Fail"incorrect result: SIMPLE binary64 value"
 val unitRoundoff=Real.fromManExp{man=1.0,exp= ~53}
 fun aggregateBound count scale=
   if count<1 orelse count>10404 orelse not(Real.isFinite scale)orelse scale<0.0
   then raise Fail"invalid SIMPLE aggregate scale"
   else let val n=Real.fromInt count
            val gamma=(n*unitRoundoff)/(1.0-n*unitRoundoff)
            val cells=n*absolute+relative*scale
        in((1.0+gamma)*cells+2.0*gamma*scale)*(1.0+64.0*unitRoundoff)end
 fun aggregate expected count scale actual=
   let val bound=aggregateBound count scale
   in if Real.isFinite expected andalso Real.isFinite actual andalso Real.isFinite bound
         andalso Real.abs(expected-actual)<=bound then()
      else raise Fail"incorrect result: SIMPLE array sum"end
 fun totals expected values=
   case(expected,values)of([],[])=>()
    |(bits::countText::scaleBits::rest,value::tail)=>
       let val count=BenchInput.integer countText
           val expected=decode bits val actual=BenchLazy.force value
           val _=if count=0 then scalar expected actual
                 else aggregate expected count(decode scaleBits)actual
       in totals rest tail end
    |_=>raise Fail"incorrect SIMPLE totals record count"

end
functor BenchSimpleCheckFn(val strict:bool val report:bool val gridMax:int)=
struct
 structure K=BenchSimpleNofibFn(val strict=strict val gridMax=gridMax)
 structure R=BenchSimpleReference
 fun integer s=case Int.fromString s of SOME n=>n|NONE=>raise Fail"invalid SIMPLE integer"
 fun parseHeader kind count tokens=
   case tokens of tag::grid::steps::n::rest=>
     if tag=kind andalso integer grid=gridMax andalso integer n=count
     then(integer steps,rest)else raise Fail"incorrect SIMPLE reference header"
   |_=>raise Fail"missing SIMPLE reference header"
 fun verifyState steps state tokens=
   let val(expectedStep,tokens)=parseHeader"SIMPLE-STATE"11 tokens
       val _=if steps=expectedStep then()else raise Fail"incorrect SIMPLE step reference"
       val pieces=ref([]:string list)
       fun emit text=pieces:=text:: !pieces
       fun real expected actual=
         let val _=R.scalar(R.decode expected)actual
             val raw=Real.fmt(StringCvt.GEN(SOME 17))actual
             val parsed=case Real.fromString raw of SOME v=>v|NONE=>raise Fail"invalid SIMPLE decimal output"
             val _=R.scalar actual parsed
         in String.map(fn #"~"=> #"-"| #"E"=> #"e"|c=>c)raw end
       fun index(i,j)="("^Int.toString i^","^Int.toString j^")"
       fun array(name,a)(tokens,count)=
         case tokens of label::loI::loJ::hiI::hiJ::n::rest=>
           let val b=((integer loI,integer loJ),(integer hiI,integer hiJ))
               val positions=K.A.positions b
               val _=if name=label andalso b=K.A.bounds a andalso List.length positions=integer n
                     then()else raise Fail"incorrect SIMPLE array shape"
               val _=emit((if name="theta"then"theta"else"\""^
                 (case name of"u"=>"U"|"v"=>"V"|"r"=>"R"|"z"=>"Z"|"alpha"=>"Alpha"|"rho"=>"Rho"|"s"=>"S"|"p"=>"P"|"q"=>"Q"|other=>other)^"\"")^"\n")
               val _=emit("array ("^index(#1 b)^","^index(#2 b)^") [")
               fun cells [] rest count=(emit"]\n";(rest,count))
                 |cells(z::zs)(i::j::value::rest)count=
                   if z=(integer i,integer j)then
                     (emit("("^index z^","^real value(K.A.sub a z)^")"^(if null zs then""else","));
                      cells zs rest(count+1))
                   else raise Fail"incorrect SIMPLE reference coordinate"
                 |cells _ _ _=raise Fail"truncated SIMPLE state"
           in cells positions rest count end
         |_=>raise Fail"truncated SIMPLE array header"
       val _=emit"\"RESULT \"\n"
       val(tokens,count)=List.foldl(fn(item,acc)=>array item acc)(tokens,0)(K.arrays state)
       val(_,_,_,_,_,_,_,_,_,dt,err)=state
       val _=case tokens of["deltat",d,"error",e]=>
          (emit(real d(BenchLazy.force dt)^"\n");emit(real e(BenchLazy.force err)^"\ndone\n"))
         |_=>raise Fail"incorrect SIMPLE scalar tail"
       val rendered=String.concat(List.rev(!pieces))
       val _=TextIO.output(TextIO.stdOut,rendered)
   in count end
 fun run[stepsText,path]=
   let val steps=BenchInput.between(0,100)(BenchInput.integer stepsText)
       val reference=R.read path
       val(totals,state)=K.compute steps
   in if report then
        Int.toString steps^":"^Int.toString(verifyState steps state reference)
      else let val(expectedStep,values)=parseHeader"SIMPLE-TOTALS-V2"13 reference
               val _=if steps=expectedStep then()else raise Fail"incorrect SIMPLE step reference"
               val _=R.totals values totals
           in Int.toString steps^":13"end
   end
 |run _=raise Fail"expected SIMPLE steps and numerical reference"
end

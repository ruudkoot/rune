structure FloatShowTests=struct
 structure W=Word32
 fun decode word=
   let val exponent=W.toInt(W.andb(W.>>(word,0w23),0wxFF))
       val fraction=W.toInt(W.andb(word,0wx7FFFFF))
       val value=if exponent=0 then Real.fromManExp{man=Real.fromInt fraction,exp= ~149}
         else if exponent=255 then if fraction=0 then Real.posInf else 0.0/0.0
         else Real.fromManExp{man=Real.fromInt(8388608+fraction),exp=exponent-150}
   in if W.andb(word,0wx80000000)=0w0 then value else ~value end
 val input=TextIO.openIn"tests/out/benchmarks/nofib-fluid-originals/float-show.reference"
 fun loop n=case TextIO.inputLine input of NONE=>n|SOME line=>
   let val fields=String.tokens(fn c=>c= #"|"orelse c= #"\n")line
       val(word,expected)=case fields of[word,expected]=>
           (W.fromLargeInt(valOf(IntInf.fromString word)),expected)|_=>raise Fail"oracle row"
       val actual=BenchFluidFloatShow.show(decode word)
   in if actual=expected then loop(n+1)
     else raise Fail("GHC Float Show "^W.toString word^" "^actual^" "^expected)end
 val count=loop 0
 val _=TextIO.closeIn input
 val _=if count=10015 then print"PASS 10015 exact GHC Float Show observations\n"else raise Fail"oracle count"
end

structure BenchNucleic2Oracle=struct
 structure W=Word32
 val absolute=0.0001
 val relative=0.000001
 fun decode word=
   let val exponent=W.toInt(W.andb(W.>>(word,0w23),0wxFF))
       val fraction=W.toInt(W.andb(word,0wx7FFFFF))
       val magnitude=if exponent=0 then Real.fromManExp{man=Real.fromInt fraction,exp= ~149}
         else if exponent=255 then raise Fail"nonfinite source coordinate"
         else Real.fromManExp{man=Real.fromInt(8388608+fraction),exp=exponent-150}
   in if W.andb(word,0wx80000000)=0w0 then magnitude else ~magnitude end
 fun coordinate(actual,expected)=Real.isFinite actual andalso
   Real.abs(actual-expected)<=absolute+relative*Real.abs expected
 fun words stream=case TextIO.inputLine stream of NONE=>raise Fail"truncated nucleic2 oracle"
   |SOME line=>String.tokens Char.isSpace line
 fun integer s=case Int.fromString s of NONE=>raise Fail"bad oracle integer"|SOME n=>n
 fun word s=case W.fromString s of NONE=>raise Fail"bad oracle word"|SOME n=>n
 fun readPoint stream=case words stream of["POINT",x,y,z]=>(decode(word x),decode(word y),decode(word z))
   |_=>raise Fail"bad oracle point"
 fun points stream 0=[]|points stream n=readPoint stream::points stream(n-1)
end

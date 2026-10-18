structure O=BenchNucleic2Oracle
val stream=TextIO.openIn"tests/out/benchmarks/nucleic2-originals/full.reference"
val checked=ref 0
fun one word=
 let val expected=O.decode(O.word word)
     val bound=O.absolute+O.relative*Real.abs expected
     val above=BenchMandelSingle.round(expected+4.0*bound)
     val below=BenchMandelSingle.round(expected-4.0*bound)
 in if O.coordinate(expected,expected)andalso not(O.coordinate(above,expected))andalso
       not(O.coordinate(below,expected))then checked:= !checked+1
    else raise Fail"coordinate fault checker"end
fun loop()=case TextIO.inputLine stream of NONE=>()
 |SOME line=>(case String.tokens Char.isSpace line of["POINT",x,y,z]=>(one x;one y;one z)|_=>();loop())
val _=loop()
val _=TextIO.closeIn stream
val _=if !checked=109800 andalso not(O.coordinate(1.0/0.0,0.0))andalso not(O.coordinate(0.0/0.0,0.0))
 then print("PASS "^Int.toString(!checked)^" coordinate references with positive/negative perturbed-result rejection and nonfinite controls\n")
 else raise Fail"source coordinate fault coverage"

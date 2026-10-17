structure A=BenchParaFn(BenchNeed)
structure B=BenchParaFn(BenchStrict)
fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
fun consume output=String.implode(List.rev(BenchStream.foldl(fn(c,cs)=>c::cs)[]output))
val base="tests/out/benchmarks/para-originals/"
val input=read(base^"source/runtime_files/input-data")
val expected=read(base^"formatted.reference")
val _=if consume(A.formatText(A.chars input))=expected then print"lazy matches\n"else raise Fail "para lazy"
val _=if consume(B.formatText(B.chars input))=expected then print"strict matches\n"else raise Fail "para strict"

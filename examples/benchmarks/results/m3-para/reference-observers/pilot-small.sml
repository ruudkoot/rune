structure A=BenchParaFn(BenchNeed)
structure B=BenchParaFn(BenchStrict)
fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
fun consume expected output=
 let fun loop n stream=case BenchLazy.force stream of BenchStream.Nil=>n=String.size expected
      |BenchStream.Cons(c,rest)=>n<String.size expected andalso
        BenchLazy.force c=String.sub(expected,n)andalso loop(n+1)rest
 in loop 0 output end
val base="tests/out/benchmarks/para-originals/"
val input=read(base^"small.input")
val expected=read(base^"small.reference")
val _=if consume expected(A.formatText(A.chars input))then print"lazy matches\n"else raise Fail "para lazy"
val _=if consume expected(B.formatText(B.chars input))then print"strict matches\n"else raise Fail "para strict"

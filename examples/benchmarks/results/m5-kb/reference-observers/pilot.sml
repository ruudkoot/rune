structure A=BenchSandmarkKBCompletionFn(BenchSandmarkKBRaise)
structure B=BenchSandmarkKBCompletionFn(BenchSandmarkKBOption)
fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
val expected=read"tests/out/benchmarks/kb-sandmark-originals/kb.rules"
val a=A.complete BenchSandmarkKBOrder.greater[]BenchSandmarkKBData.rules
val b=B.complete BenchSandmarkKBOrder.greater[]BenchSandmarkKBData.rules
val _=if String.concat(List.map BenchSandmarkKBTerms.canonicalRule a)=expected then print"raise matches 24 rules\n"
 else raise Fail "KB exception rules"
val _=if String.concat(List.map BenchSandmarkKBTerms.canonicalRule b)=expected then print"option matches 24 rules\n"
 else raise Fail "KB option rules"

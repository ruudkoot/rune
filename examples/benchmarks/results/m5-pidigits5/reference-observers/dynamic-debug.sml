structure DynamicDebug =
struct
 fun file path=let val input=TextIO.openIn path val s=TextIO.inputAll input in TextIO.closeIn input;s end
 fun trial n=
   let val _=print("BEGIN "^Int.toString n^"\n")val _=TextIO.flushOut TextIO.stdOut
       val expected=file("tests/out/benchmarks/pidigits5-originals/digits-"^Int.toString n^".expected")
       val _=print("READ "^Int.toString(String.size expected)^"\n")val _=TextIO.flushOut TextIO.stdOut
       val _=BenchPiDigitsFive.check n expected
   in print "CHECKPASS\n";TextIO.flushOut TextIO.stdOut end
 val _=List.app trial [27,128,256]
end

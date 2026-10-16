structure Pilot =
struct
 fun file path=let val input=TextIO.openIn path val s=TextIO.inputAll input in TextIO.closeIn input;s end
 val _=List.app(fn n=>
  let val start=Time.now()
      val _=BenchPiDigitsFive.check n(file("tests/out/benchmarks/pidigits5-originals/digits-"^Int.toString n^".expected"))
  in print("PASS "^Int.toString n^" seconds="^Time.toString(Time.-(Time.now(),start))^"\n");TextIO.flushOut TextIO.stdOut end)[27,128]
end

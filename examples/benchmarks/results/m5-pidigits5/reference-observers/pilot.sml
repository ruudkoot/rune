structure Pilot =
struct
 fun file path=let val input=TextIO.openIn path val s=TextIO.inputAll input in TextIO.closeIn input;s end
 val _=List.app(fn n=>BenchPiDigitsFive.check n(file("tests/out/benchmarks/pidigits5-originals/digits-"^Int.toString n^".expected")))[0,1,10,11,27,128,256,1000]
 val _=print "PASS complete three-state digits and formatting\n"
end

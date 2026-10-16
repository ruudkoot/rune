structure MandelNeed = BenchMandelTwoFn (structure D = BenchNeed structure P = BenchMandelTwoPoint)
structure MandelStrict = BenchMandelTwoFn (structure D = BenchStrict structure P = BenchMandelTwoPoint)
structure NeedCheck = MandelTreeCheckFn (MandelNeed)
structure StrictCheck = MandelTreeCheckFn (MandelStrict)
structure Pilot =
struct
  fun run n =
    let val path = Int.toString n ^ ".tree"
        val _ = print ("BEGIN lazy " ^ Int.toString n ^ "\n")
        val a = NeedCheck.run n path
        val _ = print ("PASS lazy " ^ Int.toString n ^ ":" ^ Int.toString a ^ "\nBEGIN strict " ^ Int.toString n ^ "\n")
        val b = StrictCheck.run n path
    in print ("PASS strict " ^ Int.toString n ^ ":" ^ Int.toString b ^ "\n") end
  val _ = (List.app run [1, 64, 200]; print "SUMMARY 1 checks, 0 failed\n")
    handle ex => (print ("EXCEPTION " ^ General.exnName ex ^ ": " ^ General.exnMessage ex ^ "\n"); OS.Process.exit OS.Process.failure)
end

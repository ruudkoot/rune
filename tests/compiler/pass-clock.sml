structure PassClockTest =
struct
  fun require (condition, message) = if condition then () else raise Fail message
  fun stage f =
    Pass.stage {name = "clock-probe", showIn = NONE, show = Int.toString,
                check = fn _ => PassClock.checks := !PassClock.checks + 1,
                size = fn _ => (PassClock.sizes := !PassClock.sizes + 1; 1)} f
  val () = Pass.lintGiven := SOME 2
  val result = stage (fn x => stage (fn y => y + 1) x) 41
  val () = require (result = 42 andalso !PassClock.checks = 2,
                    "untimed stages must run and check their results")
  val () = require (!PassClock.reads = 0 andalso !PassClock.sizes = 0,
                    "ordinary stages must not sample clocks or count nodes")
  val () = require (!Pass.depth = 0 andalso !Pass.outer = Time.zeroTime
                    andalso !Pass.sizes = Time.zeroTime andalso !Pass.checks = Time.zeroTime,
                    "ordinary stages must leave timing state alone")
  exception Probe
  val () = (ignore (stage (fn _ => raise Probe) 0); raise Fail "exception lost")
           handle Probe => ()
  val () = require (!PassClock.reads = 0 andalso !Pass.depth = 0,
                    "an untimed exception must not sample a clock")
  val () = Pass.stats := true
  val result = stage (fn x => stage (fn y => y + 1) x) 41
  val () = require (result = 42 andalso !PassClock.reads > 0
                    andalso !PassClock.sizes = 2 andalso !Pass.depth = 0,
                    "requested timing must measure nested stages")
  val () = (ignore (stage (fn _ => raise Probe) 0); raise Fail "exception lost")
           handle Probe => ()
  val () = require (!Pass.depth = 0, "a measured exception must restore depth")
  val () = print "pass clock contract: ok\n"
end

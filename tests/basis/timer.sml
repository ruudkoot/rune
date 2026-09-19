(* requires: Timer Time *)
(* The Timer structure (signature TIMER). Expected properties follow the text
   of https://smlfamily.github.io/Basis/timer.html.

   What a timer reads depends on the machine and its load, so that only
   properties are checked: times are never negative, a timer does not run
   backwards, it grows while the program computes (the page allows a system
   without CPU accounting to return the real time instead, which grows too),
   the relations between checkCPUTimes, checkCPUTimer and checkGCTime that
   the page states as equivalences, and that the total timers started at a
   "system-dependent initialization time", which lies before this test began.
   Readings taken one after the other are compared in the order they were
   taken, which is all that the equivalences allow when the clock moves
   between two calls. *)
structure TestTimer =
struct
  val eqB = T.eq T.bool
  val zero = Time.zeroTime
  (* Times from an int: a host that compiles lib/basis (xc1) cannot type an
     int constant at the LargeInt of lib/basis. *)
  fun secs (n : int) = Time.fromSeconds (LargeInt.fromInt n)
  fun ms (n : int) = Time.fromMilliseconds (LargeInt.fromInt n)

  fun cpu {usr, sys} = Time.+ (usr, sys)
  fun nonNegative {usr, sys} = Time.>= (usr, zero) andalso Time.>= (sys, zero)
  fun notLess ({usr = u1, sys = s1}, {usr = u2, sys = s2}) = Time.>= (u2, u1) andalso Time.>= (s2, s1)
  fun sum (a : {usr : Time.time, sys : Time.time}, b : {usr : Time.time, sys : Time.time}) =
    {usr = Time.+ (#usr a, #usr b), sys = Time.+ (#sys a, #sys b)}
  fun total (times : {nongc : {usr : Time.time, sys : Time.time}, gc : {usr : Time.time, sys : Time.time}}) =
    sum (#nongc times, #gc times)

  (* work n: some computation that allocates *)
  fun work (n : int) : int =
    let fun go (k, acc) = if k = 0 then List.length acc else go (k - 1, (k mod 7) :: List.take (acc, Int.min (List.length acc, 3)))
    in go (n, []) end
  (* burn (enough, seconds): work until enough () holds, for at most that
     many seconds of real time; whether enough () then holds *)
  fun burn (enough : unit -> bool, seconds : int) : bool =
    let
      val start = Time.now ()
      val limit = Time.fromSeconds (LargeInt.fromInt seconds)
      fun go () =
        enough () orelse
        (Time.< (Time.- (Time.now (), start), limit) andalso (ignore (work 20000); go ()))
    in go () end

  (* timers started at the beginning of the test *)
  val earlyCPU : Timer.cpu_timer option ref = ref NONE
  val earlyReal : Timer.real_timer option ref = ref NONE
  val () = T.check ("Timer.startCPUTimer/starts", fn () => (earlyCPU := SOME (Timer.startCPUTimer ()); true))
  val () = T.check ("Timer.startRealTimer/starts", fn () => (earlyReal := SOME (Timer.startRealTimer ()); true))

  (* ---- startCPUTimer, checkCPUTimer: "a CPU timer that measures the time
     the process is computing ... starting at this call"; checkCPUTimer
     "returns the user time (usr) and system time (sys) that have accumulated
     since the timer timer was started" ---- *)
  val () = eqB ("Timer.checkCPUTimer/non-negative", true,
                fn () => nonNegative (Timer.checkCPUTimer (Timer.startCPUTimer ())))
  val () = eqB ("Timer.startCPUTimer/starts-near-zero", true,
                fn () => Time.< (cpu (Timer.checkCPUTimer (Timer.startCPUTimer ())), secs 1))
  val () = eqB ("Timer.checkCPUTimer/grows-while-computing", true,
                fn () => let val t = Timer.startCPUTimer ()
                         in burn (fn () => Time.>= (cpu (Timer.checkCPUTimer t), ms 50), 20) end)
  val () = eqB ("Timer.checkCPUTimer/does-not-go-back", true,
                fn () => let
                           val t = valOf (!earlyCPU)
                           val a = Timer.checkCPUTimer t
                           val _ = work 50000
                           val b = Timer.checkCPUTimer t
                           val c = Timer.checkCPUTimer t
                         in notLess (a, b) andalso notLess (b, c) end)
  val () = eqB ("Timer.startCPUTimer/later-timer-reads-less", true,
                fn () => let
                           val early = valOf (!earlyCPU)
                           val late = Timer.startCPUTimer ()
                           val _ = work 50000
                           val l = Timer.checkCPUTimer late
                           val e = Timer.checkCPUTimer early
                         in notLess (l, e) end)

  (* ---- checkCPUTimes: "The total CPU time used by the program will be the
     sum of these four values"; checkCPUTimer is equivalent to
     {usr = #usr nongc + #usr gc, sys = #sys nongc + #sys gc} ---- *)
  val () = eqB ("Timer.checkCPUTimes/non-negative", true,
                fn () => let val {nongc, gc} = Timer.checkCPUTimes (valOf (!earlyCPU))
                         in nonNegative nongc andalso nonNegative gc end)
  val () = eqB ("Timer.checkCPUTimes/sum-is-checkCPUTimer", true,
                fn () => let
                           val t = valOf (!earlyCPU)
                           val a = total (Timer.checkCPUTimes t)
                           val b = Timer.checkCPUTimer t
                           val c = total (Timer.checkCPUTimes t)
                         in notLess (a, b) andalso notLess (b, c) end)
  val () = eqB ("Timer.checkCPUTimes/does-not-go-back", true,
                fn () => let
                           val t = valOf (!earlyCPU)
                           val a = Timer.checkCPUTimes t
                           val _ = work 50000
                           val b = Timer.checkCPUTimes t
                         in notLess (#nongc a, #nongc b) andalso notLess (#gc a, #gc b) end)
  val () = eqB ("Timer.checkCPUTimes/grows-while-computing", true,
                fn () => let val t = Timer.startCPUTimer ()
                         in burn (fn () => Time.>= (cpu (total (Timer.checkCPUTimes t)), ms 50), 20) end)

  (* ---- checkGCTime: equivalent to #usr (#gc (checkCPUTimes ct)) ---- *)
  val () = eqB ("Timer.checkGCTime/non-negative", true,
                fn () => Time.>= (Timer.checkGCTime (valOf (!earlyCPU)), zero))
  val () = eqB ("Timer.checkGCTime/is-gc-usr", true,
                fn () => let
                           val t = valOf (!earlyCPU)
                           val a = #usr (#gc (Timer.checkCPUTimes t))
                           val g = Timer.checkGCTime t
                           val b = #usr (#gc (Timer.checkCPUTimes t))
                         in Time.<= (a, g) andalso Time.<= (g, b) end)
  val () = eqB ("Timer.checkGCTime/part-of-usr", true,
                fn () => let
                           val t = valOf (!earlyCPU)
                           val _ = work 100000
                           val g = Timer.checkGCTime t
                           val {usr, ...} = Timer.checkCPUTimer t
                         in Time.<= (g, usr) end)
  val () = eqB ("Timer.checkGCTime/does-not-go-back", true,
                fn () => let
                           val t = valOf (!earlyCPU)
                           val a = Timer.checkGCTime t
                           val _ = work 100000
                           val b = Timer.checkGCTime t
                         in Time.<= (a, b) end)

  (* ---- totalCPUTimer: "a CPU timer that measures the time the process is
     computing ... starting at some system-dependent initialization time",
     which comes before this test started its own timer ---- *)
  val () = eqB ("Timer.totalCPUTimer/non-negative", true,
                fn () => nonNegative (Timer.checkCPUTimer (Timer.totalCPUTimer ())))
  val () = eqB ("Timer.totalCPUTimer/includes-earlier-computation", true,
                fn () => let
                           val early = valOf (!earlyCPU)
                           val enough = burn (fn () => Time.>= (cpu (Timer.checkCPUTimer early), ms 100), 20)
                           val e = Timer.checkCPUTimer early
                           val tot = Timer.checkCPUTimer (Timer.totalCPUTimer ())
                         in enough andalso notLess (e, tot) end)
  val () = eqB ("Timer.totalCPUTimer/does-not-go-back", true,
                fn () => let
                           val t = Timer.totalCPUTimer ()
                           val a = Timer.checkCPUTimer t
                           val _ = work 50000
                           val b = Timer.checkCPUTimer t
                         in notLess (a, b) end)

  (* ---- startRealTimer, checkRealTimer: "the amount of (real) time that has
     passed since the timer rt was started" ---- *)
  val () = eqB ("Timer.checkRealTimer/non-negative", true,
                fn () => Time.>= (Timer.checkRealTimer (Timer.startRealTimer ()), zero))
  val () = eqB ("Timer.startRealTimer/starts-near-zero", true,
                fn () => Time.< (Timer.checkRealTimer (Timer.startRealTimer ()), secs 5))
  val () = eqB ("Timer.checkRealTimer/does-not-go-back", true,
                fn () => let
                           val t = valOf (!earlyReal)
                           val a = Timer.checkRealTimer t
                           val b = Timer.checkRealTimer t
                           val c = Timer.checkRealTimer t
                         in Time.<= (a, b) andalso Time.<= (b, c) end)
  (* The time between two readings of Time.now taken after the timer started
     and before it was checked has passed since the timer started (up to the
     resolutions of the two clocks: 2 ms). *)
  val () = eqB ("Timer.checkRealTimer/measures-real-time", true,
                fn () => let
                           val rt = Timer.startRealTimer ()
                           val a = Time.now ()
                           val _ = burn (fn () => Time.>= (Time.- (Time.now (), a), ms 50), 20)
                           val b = Time.now ()
                           val e = Timer.checkRealTimer rt
                         in Time.>= (Time.+ (e, ms 2), Time.- (b, a)) end)
  (* ... and at most the time between readings of Time.now around it *)
  val () = eqB ("Timer.checkRealTimer/at-most-the-time-around", true,
                fn () => let
                           val a = Time.now ()
                           val rt = Timer.startRealTimer ()
                           val _ = burn (fn () => Time.>= (Time.- (Time.now (), a), ms 50), 20)
                           val e = Timer.checkRealTimer rt
                           val b = Time.now ()
                         in Time.<= (e, Time.+ (Time.- (b, a), ms 2)) end)

  (* ---- totalRealTimer: "a wall clock (real) timer that measures how much
     time passes, starting from some system-dependent initialization time" ---- *)
  val () = eqB ("Timer.totalRealTimer/non-negative", true,
                fn () => Time.>= (Timer.checkRealTimer (Timer.totalRealTimer ()), zero))
  val () = eqB ("Timer.totalRealTimer/includes-earlier-time", true,
                fn () => let
                           val early = valOf (!earlyReal)
                           val enough = burn (fn () => Time.>= (Timer.checkRealTimer early, ms 100), 20)
                           val e = Timer.checkRealTimer early
                           val tot = Timer.checkRealTimer (Timer.totalRealTimer ())
                         in enough andalso Time.<= (e, tot) end)
  val () = eqB ("Timer.totalRealTimer/does-not-go-back", true,
                fn () => let
                           val t = Timer.totalRealTimer ()
                           val a = Timer.checkRealTimer t
                           val b = Timer.checkRealTimer t
                         in Time.<= (a, b) end)
end

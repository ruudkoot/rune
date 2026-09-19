(* requires: Timer Time *)
(* uses: spec-sigs/TIMER.sml *)
(* Timer matches TIMER; the timers seen through the signature are those of
   the structure. *)
structure TestTimerSig =
struct
  structure C : SPEC_TIMER = Timer
  val () = T.check ("Timer:TIMER/matches", fn () => true)
  val () = T.check ("Timer:TIMER/cpu_timer-is-Timer.cpu_timer",
                    fn () => let val t : Timer.cpu_timer = C.startCPUTimer ()
                             in Time.>= (#usr (C.checkCPUTimer t), Time.zeroTime)
                                andalso Time.>= (#usr (Timer.checkCPUTimer t), Time.zeroTime)
                             end)
  val () = T.check ("Timer:TIMER/real_timer-is-Timer.real_timer",
                    fn () => let val t : C.real_timer = Timer.startRealTimer ()
                             in Time.>= (C.checkRealTimer t, Time.zeroTime) end)
end

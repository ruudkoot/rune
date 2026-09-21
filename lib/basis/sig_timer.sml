(* Stopwatches: how much processor time and how much wall-clock time have
   passed since a timer was started.

   A timer is started, not read and reset: `startCPUTimer ()` and
   `startRealTimer ()` take a reading of the clocks, and `checkCPUTimer` and
   `checkRealTimer` give the time since, as often as one likes. The two
   `total` timers are the ones that were started when the program was, so
   they measure the whole run.

   Processor time is split into the time the program spent and the time the
   system spent on its behalf, and `checkCPUTimes` separates out what the
   garbage collector took.

   Area: The operating system

   See also: `TIME`, `OS_PROCESS`

   Reading: `TIMER/only-properties-are-checked`. What a timer reads is not a
   value a test can predict; the suite checks that times are not negative,
   that they do not go backwards, and that the equivalences the specification
   states hold. A system that does not account for processor time may report
   real time here. *)
signature TIMER =
sig
  (* The type of a processor-time timer. *)
  type cpu_timer

  (* The type of a wall-clock timer, a `Time.time` in the same way. *)
  type real_timer

  (* `startCPUTimer ()` is a timer that counts processor time from now. *)
  val startCPUTimer : unit -> cpu_timer

  (* `checkCPUTimes t` is the processor time since `t` was started, split into the collector's share and the rest.

     `usr` is the time the program itself ran, `sys` the time the system
     spent for it.

     Limitation: `Timer.checkCPUTimes/no-gc-accounting`. The collector's time
     is not measured on its own: `gc` is zero in both fields and everything
     is reported under `nongc`. *)
  val checkCPUTimes : cpu_timer
                      -> {nongc : {usr : Time.time, sys : Time.time},
                          gc : {usr : Time.time, sys : Time.time}}

  (* `checkCPUTimer t` is the processor time since `t` was started, user and system time apart.

     It counts the collector's share in, where `checkCPUTimes` reports it
     separately. *)
  val checkCPUTimer : cpu_timer -> {usr : Time.time, sys : Time.time}

  (* `checkGCTime t` is the processor time the collector took since `t` was started.

     Limitation: `Timer.checkGCTime/always-zero`. It is always `zeroTime`,
     because the collector's time is not measured on its own. *)
  val checkGCTime : cpu_timer -> Time.time

  (* `totalCPUTimer ()` is the timer that was started when the program was.

     Implementation: `Timer.totalCPUTimer/from-process-start`. The
     "system-dependent initialization time" is the start of the process, so
     the timer's base is zero processor time and what it reports is what the
     whole run has used. *)
  val totalCPUTimer : unit -> cpu_timer

  (* `startRealTimer ()` is a timer that counts wall-clock time from now. *)
  val startRealTimer : unit -> real_timer

  (* `checkRealTimer t` is the wall-clock time since `t` was started. *)
  val checkRealTimer : real_timer -> Time.time

  (* `totalRealTimer ()` is the wall-clock timer that was started when the program was.

     Implementation: `Timer.totalRealTimer/from-initialisation`. It counts
     from the moment the library was initialised, just before the program's
     own code begins. *)
  val totalRealTimer : unit -> real_timer
end

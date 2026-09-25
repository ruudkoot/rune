(* Timer.checkCPUTimer counts the time of garbage collection twice: the user
   time it reports is the user time of the process plus the time of the
   collections, which that user time already includes. It should print two
   user times that are about equal, the second not larger by the GC time.
   Standalone: SML/NJ's own Basis Library. *)
fun ms t = LargeInt.toString (Time.toMilliseconds t) ^ " ms"

(* work that keeps a large structure alive, so that collections cost *)
fun build (0, acc) = acc
  | build (n, acc) = build (n - 1, List.tabulate (20, fn i => i + n) :: acc)
fun churn (0, keep) = keep
  | churn (n, keep) = churn (n - 1, if n mod 100 = 0 then build (2000, []) :: keep else keep)

val timer = Timer.startCPUTimer ()
val start = #utime (Posix.ProcEnv.times ())
val kept = churn (20000, [])
val after = #utime (Posix.ProcEnv.times ())

val {nongc, gc} = Timer.checkCPUTimes timer
val total = Timer.checkCPUTimer timer
val () = print ("user time, from times():             " ^ ms (Time.- (after, start)) ^ "\n")
val () = print ("user time, from Timer.checkCPUTimer: " ^ ms (#usr total) ^ "\n")
val () = print ("  of which nongc: " ^ ms (#usr nongc) ^ ", gc: " ^ ms (#usr gc) ^ "\n")
val () = print ("(kept " ^ Int.toString (length kept) ^ " blocks)\n")

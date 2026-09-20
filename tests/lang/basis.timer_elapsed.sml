(* Timer: what can be said of a clock without knowing how fast the machine
   is: time does not run backwards, and a wait of 50 ms takes at least that. *)
val real = Timer.startRealTimer ()
val cpu = Timer.startCPUTimer ()
fun work (0, acc) = acc
  | work (n, acc) = work (n - 1, acc + n)
val () = print (Int.toString (work (200000, 0) mod 7) ^ "\n")
val {usr, sys} = Timer.checkCPUTimer cpu
val () = print (Bool.toString (Time.>= (usr, Time.zeroTime) andalso Time.>= (sys, Time.zeroTime)) ^ "\n")
val {nongc, gc} = Timer.checkCPUTimes cpu
val () = print (Bool.toString (Time.>= (#usr nongc, usr) andalso Time.compare (#usr gc, Time.zeroTime) = EQUAL) ^ "\n")
val () = print (Bool.toString (Time.compare (Timer.checkGCTime cpu, Time.zeroTime) = EQUAL) ^ "\n")
val before' = Timer.checkRealTimer real
val () = OS.Process.sleep (Time.fromMilliseconds 50)
val after = Timer.checkRealTimer real
val () = print (Bool.toString (Time.>= (after, Time.+ (before', Time.fromMilliseconds 45))) ^ "\n")

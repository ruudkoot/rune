(* Timer: how long something took.

   Implements: TIMER *)
structure Timer =
struct
  type cpu_timer = {user : Time.time, sys : Time.time}
  type real_timer = Time.time

  local
    val user' = _prim "time_user" : unit -> int
    val system' = _prim "time_sys" : unit -> int
    (* the primitives count in microseconds *)
    fun user () = Time.ofMicros (user' ())
    fun system () = Time.ofMicros (system' ())
  in
    fun startCPUTimer () = {user = user (), sys = system ()}
    fun checkCPUTimes {user = u, sys = s} =
      {nongc = {usr = Time.- (user (), u), sys = Time.- (system (), s)},
       gc = {usr = Time.zeroTime, sys = Time.zeroTime}}
    fun checkCPUTimer timer =
      let val {nongc = {usr, sys}, ...} = checkCPUTimes timer
      in {usr = usr, sys = sys} end
    (* The collector's time is not measured on its own. *)
    fun checkGCTime _ = Time.zeroTime
    (* The processor times that the primitives give count from the start of
       the process, the "system-dependent initialization time". *)
    fun totalCPUTimer () = {user = Time.zeroTime, sys = Time.zeroTime}
  end

  fun startRealTimer () = Time.now ()
  fun checkRealTimer start = Time.- (Time.now (), start)
  local
    (* The real time is counted from when the library is initialised, before
       the program's own code runs. *)
    val initialization = Time.now ()
  in
    fun totalRealTimer () = initialization
  end
end

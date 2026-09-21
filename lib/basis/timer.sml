(* Timer: how long something took.

   Implements: TIMER *)
structure Timer =
struct
  (* A timer holds what the clocks read when it started, the collector's
     among them: every time it reports is a difference of two readings. *)
  type cpu_timer = {user : Time.time, sys : Time.time, gcUser : Time.time, gcSys : Time.time}
  type real_timer = Time.time

  local
    val user' = _prim "time_user" : unit -> int
    val system' = _prim "time_sys" : unit -> int
    val gcUser' = _prim "time_gc_user" : unit -> int
    val gcSys' = _prim "time_gc_sys" : unit -> int
    (* the primitives count in microseconds *)
    fun user () = Time.ofMicros (user' ())
    fun system () = Time.ofMicros (system' ())
    fun gcUser () = Time.ofMicros (gcUser' ())
    fun gcSys () = Time.ofMicros (gcSys' ())
  in
    fun startCPUTimer () = {user = user (), sys = system (), gcUser = gcUser (), gcSys = gcSys ()}
    (* The processor time of the collections since the timer started is what
       the VM has added up; the rest of the time is the program's own. *)
    fun checkCPUTimes {user = u, sys = s, gcUser = gu, gcSys = gs} =
      let
        val gcu = Time.- (gcUser (), gu) and gcs = Time.- (gcSys (), gs)
        val allu = Time.- (user (), u) and alls = Time.- (system (), s)
      in
        {nongc = {usr = Time.- (allu, gcu), sys = Time.- (alls, gcs)},
         gc = {usr = gcu, sys = gcs}}
      end
    fun checkCPUTimer timer =
      let val {nongc = {usr, sys}, gc = {usr = gu, sys = gs}} = checkCPUTimes timer
      in {usr = Time.+ (usr, gu), sys = Time.+ (sys, gs)} end
    fun checkGCTime timer = #usr (#gc (checkCPUTimes timer))
    (* The processor times that the primitives give count from the start of
       the process, the "system-dependent initialization time". *)
    fun totalCPUTimer () =
      {user = Time.zeroTime, sys = Time.zeroTime, gcUser = Time.zeroTime, gcSys = Time.zeroTime}
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

(* Timer: how long something took. *)
structure Timer =
struct
  type cpu_timer = {user : Time.time, sys : Time.time}
  type real_timer = Time.time

  local
    val user = _prim "time_user" : unit -> int
    val system = _prim "time_sys" : unit -> int
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
    val totalCPUTimer = startCPUTimer
  end

  fun startRealTimer () = Time.now ()
  fun checkRealTimer start = Time.- (Time.now (), start)
  val totalRealTimer = startRealTimer
end

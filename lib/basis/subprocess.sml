(* Subprocess: children started in a directory, a group and under limits,
   and waited for with what they cost (docs/plans/unit-testing.md, M2).

   Implements: SUBPROCESS *)
structure Subprocess =
struct
  local
    val spawn' = _prim "proc_spawn" : string * string list * string list * int * int list * string * int list -> int
    val wait' = _prim "proc_wait" : int * int -> int list
    val kill' = _prim "proc_kill" : int * int -> int

    fun fd NONE = ~1
      | fd (SOME n) = n
    fun limit NONE = ~1
      | limit (SOME n) = n
    (* the primitive counts in microseconds, which a time is: no IntInf, whose
       cost would depend on the value and make the counts of a program vary *)
    fun microseconds n = Time.ofMicros n
    fun signal n = Posix.Signal.fromWord (SysWord.fromInt n)

    fun statusOf (0, 0) = Posix.Process.W_EXITED
      | statusOf (0, v) = Posix.Process.W_EXITSTATUS (Word8.fromInt v)
      | statusOf (1, v) = Posix.Process.W_SIGNALED (signal v)
      | statusOf (_, v) = Posix.Process.W_STOPPED (signal v)

    fun ended [pid, kind, value, user, system, peak] =
          SOME {pid = pid, status = statusOf (kind, value), user = microseconds user,
                system = microseconds system, peakResident = peak}
      | ended _ = NONE
  in
    type pid = int
    type limits = {addressSpace : int option, cpuTime : int option, fileSize : int option, core : int option}
    val unlimited : limits = {addressSpace = NONE, cpuTime = NONE, fileSize = NONE, core = NONE}

    type ended = {pid : pid, status : Posix.Process.exit_status, user : Time.time,
                  system : Time.time, peakResident : int}

    fun spawn {program, args, env, search, dir, stdin, stdout, stderr, group,
               limits = {addressSpace, cpuTime, fileSize, core} : limits} =
      let
        val flags = (if search then 1 else 0) + (if isSome env then 2 else 0) + (if group then 4 else 0) + 8
        val pid = spawn' (program, args, getOpt (env, []), flags, [fd stdin, fd stdout, fd stderr],
                          getOpt (dir, ""), [limit addressSpace, limit cpuTime, limit fileSize, limit core])
      in
        if pid < 0 then raise RuneError.lastError () else pid
      end

    fun wait pid =
      case ended (wait' (getOpt (pid, ~1), 0)) of
        SOME e => e
      | NONE => raise RuneError.lastError ()

    fun poll pid =
      case wait' (getOpt (pid, ~1), 1) of
        [] => raise RuneError.lastError ()
      | 0 :: _ => NONE
      | r => ended r

    fun kill (pid, s) =
      if kill' (pid, SysWord.toInt (Posix.Signal.toWord s)) < 0 then raise RuneError.lastError () else ()
  end
end

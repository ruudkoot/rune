(* Posix.Process: making processes, waiting for them, and signalling them. *)
structure RunePosixProcess =
struct
  type signal = RunePosixSignal.signal
  type pid = int

  local
    val fork' = _prim "posix_fork" : unit -> int
    val exec' = _prim "posix_exec" : string * string list * int -> int
    val exece' = _prim "posix_exece" : string * string list * string list -> int
    val waitpid' = _prim "posix_waitpid" : int * int -> int list
    val kill' = _prim "posix_kill" : int * int -> int
    val alarm' = _prim "posix_alarm" : int -> int
    val pause' = _prim "posix_pause" : unit -> int
    val exit' = _prim "exit" : int -> 'a
    val const = _prim "posix_const" : string -> int
    val sleep' = _prim "time_sleep" : int -> unit
    fun check r = if r < 0 then raise RuneError.lastError () else r
  in
    fun pidToWord (p : pid) = Word.fromInt p
    fun wordToPid w = Word.toInt w

    datatype waitpid_arg = W_ANY_CHILD | W_CHILD of pid | W_SAME_GROUP | W_GROUP of pid
    datatype exit_status = W_EXITED | W_EXITSTATUS of Word8.word | W_SIGNALED of signal | W_STOPPED of signal
    datatype killpid_arg = K_PROC of pid | K_SAME_GROUP | K_GROUP of pid

    (* "returns NONE in the child and SOME pid in the parent" *)
    fun fork () =
      case check (fork' ()) of
        0 => NONE
      | pid => SOME pid

    fun exec (path, args) = (check (exec' (path, args, 0)); raise RuneError.lastError ())
    fun exece (path, args, env) = (check (exece' (path, args, env)); raise RuneError.lastError ())
    fun execp (path, args) = (check (exec' (path, args, 1)); raise RuneError.lastError ())

    fun exit (status : Word8.word) = exit' (Word8.toInt status)

    val wnohang = const "WNOHANG"
    val wuntraced = const "WUNTRACED"
    datatype waitpid_flag = W_NOHANG | W_UNTRACED
    fun flagBits flags =
      List.foldl (fn (W_NOHANG, acc) => Word.toInt (Word.orb (Word.fromInt acc, Word.fromInt wnohang))
                   | (W_UNTRACED, acc) => Word.toInt (Word.orb (Word.fromInt acc, Word.fromInt wuntraced)))
                 0 flags

    fun pidOf W_ANY_CHILD = ~1
      | pidOf (W_CHILD pid) = pid
      | pidOf W_SAME_GROUP = 0
      | pidOf (W_GROUP pid) = Int.~ pid

    fun statusOf (kind, value) =
      case kind of
        0 => if value = 0 then W_EXITED else W_EXITSTATUS (Word8.fromInt value)
      | 1 => W_SIGNALED value
      | _ => W_STOPPED value

    fun waitpid (arg, flags) =
      case waitpid' (pidOf arg, flagBits flags) of
        [pid, kind, value] => (pid, statusOf (kind, value))
      | _ => raise RuneError.lastError ()

    fun waitpid_nh (arg, flags) =
      case waitpid' (pidOf arg, flagBits (W_NOHANG :: flags)) of
        [0, _, _] => NONE
      | [pid, kind, value] => SOME (pid, statusOf (kind, value))
      | _ => raise RuneError.lastError ()

    fun wait () = waitpid (W_ANY_CHILD, [])

    fun kill (K_PROC pid, signal) = ignore (check (kill' (pid, signal)))
      | kill (K_SAME_GROUP, signal) = ignore (check (kill' (0, signal)))
      | kill (K_GROUP pid, signal) = ignore (check (kill' (Int.~ pid, signal)))

    fun alarm t = Time.ofMicros (check (alarm' (IntInf.toInt (Time.toSeconds t))) * 1000000)
    fun pause () = ignore (pause' ())
    fun sleep t = (sleep' (Time.micros t); Time.zeroTime)
  end
end

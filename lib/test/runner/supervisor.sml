(* The supervisor: children in groups, reaped with what they cost, ended
   for their time or their output, and the scheduler's admission. *)
structure Supervisor :> SUPERVISOR =
struct
  type command = {program : string, args : string list, env : string list, dir : string,
                  stdin : string, stdout : string, stderr : string, timeout : Time.time, cap : int,
                  cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
                  failedLast : bool, deps : int list}
  datatype outcome = Exited of int | Signalled of int | TimedOut | Capped | Cancelled | Failed of string
  type result = {outcome : outcome, wall : Time.time, user : Time.time, system : Time.time,
                 peakResident : int, outputBytes : int, leaked : bool}

  fun outcomeName (Exited n) = "exit " ^ Int.toString n
    | outcomeName (Signalled s) = "signal " ^ Int.toString s
    | outcomeName TimedOut = "timeout"
    | outcomeName Capped = "output cap"
    | outcomeName Cancelled = "cancelled"
    | outcomeName (Failed m) = "not started: " ^ m

  fun size path = Position.toInt (OS.FileSys.fileSize path) handle OS.SysErr _ => 0

  (* a file's descriptor, by number, for Subprocess; and the descriptor to close *)
  fun openIn path = Posix.FileSys.openf (path, Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
  fun create path = Posix.FileSys.creat (path, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr,
                                                                      Posix.FileSys.S.irgrp, Posix.FileSys.S.iroth])
  fun number fd = SysWord.toInt (Posix.FileSys.fdToWord fd)

  val term = Posix.Signal.term
  val kill = Posix.Signal.kill
  val probe = Posix.Signal.fromWord 0w0
  (* the grace a group has between TERM and KILL *)
  val grace = Time.fromSeconds 2

  datatype state = Waiting | Running of {pid : int, start : Time.time, killedAt : Time.time option, why : outcome option}
                 | Done of bool

  fun signalGroup (pid, s) = (Subprocess.kill (pid, s); true) handle OS.SysErr _ => false

  fun start (c : command) =
    let
      val i = openIn (#stdin c)
      val out = create (#stdout c)
      val err = create (#stderr c)
      val pid =
        Subprocess.spawn {program = #program c, args = #args c, env = SOME (#env c), search = false,
                          dir = SOME (#dir c), stdin = SOME (number i), stdout = SOME (number out),
                          stderr = SOME (number err), group = true,
                          limits = {addressSpace = NONE, cpuTime = NONE, fileSize = if #cap c > 0 then SOME (#cap c) else NONE,
                                    core = SOME 0}}
        handle e => (Posix.IO.close i; Posix.IO.close out; Posix.IO.close err; raise e)
    in
      Posix.IO.close i; Posix.IO.close out; Posix.IO.close err; pid
    end

  fun run {commands : command vector, cpus, memory, finished, tick} =
    let
      val n = Vector.length commands
      val plan =
        Scheduler.plan (Vector.map (fn (c : command) =>
                                      {cost = #cost c, cpus = #cpus c, memory = #memory c, pools = #pools c,
                                       exclusive = #exclusive c, failedLast = #failedLast c, deps = #deps c})
                                   commands)
      val sched = Scheduler.start plan
      val state = Array.array (n, Waiting)
      val running : (int * int) list ref = ref []   (* pid, index *)
      val lastLook = ref (Runtime.clock ())
      fun command i = Vector.sub (commands, i)
      fun nothing () = {outcome = Cancelled, wall = Time.zeroTime, user = Time.zeroTime, system = Time.zeroTime,
                        peakResident = 0, outputBytes = 0, leaked = false}
      (* a job ended: told, and the jobs that waited for it cancelled when
         it did not end well *)
      fun finish (i, r) =
        let val ok = finished (i, r)
        in
          Array.update (state, i, Done ok);
          List.app (fn j => (Array.update (state, j, Done false); ignore (finished (j, nothing ()))))
                   (Scheduler.ended (sched, i, ok))
        end
      fun admit () =
        let
          fun launch i =
            (let val pid = start (command i)
             in Array.update (state, i, Running {pid = pid, start = Runtime.clock (), killedAt = NONE, why = NONE});
                running := (pid, i) :: !running
             end)
            handle OS.SysErr (m, _) => finish (i, {outcome = Failed m, wall = Time.zeroTime, user = Time.zeroTime,
                                                          system = Time.zeroTime, peakResident = 0, outputBytes = 0,
                                                          leaked = false})
        in
          List.app launch (Scheduler.admit (sched, {cpus = cpus, memory = memory}))
        end
      fun reap () =
        if null (!running) then false
        else
          case Subprocess.poll NONE of
            NONE => false
          | SOME {pid, status, user, system, peakResident} =>
              (case List.find (fn (p, _) => p = pid) (!running) of
                 NONE => true   (* a child this loop did not start *)
               | SOME (_, i) =>
                   let
                     val () = running := List.filter (fn (p, _) => p <> pid) (!running)
                     val (start, why) = case Array.sub (state, i) of
                                          Running {start, why, ...} => (start, why)
                                        | _ => (Runtime.clock (), NONE)
                     (* the group outlived its leader: kill the rest *)
                     val leaked = signalGroup (pid, probe) andalso (ignore (signalGroup (pid, kill)); true)
                     val c = command i
                     val outcome =
                       case why of
                         SOME w => w
                       | NONE =>
                           case status of
                             Posix.Process.W_EXITED => Exited 0
                           | Posix.Process.W_EXITSTATUS w => Exited (Word8.toInt w)
                           | Posix.Process.W_SIGNALED s => Signalled (SysWord.toInt (Posix.Signal.toWord s))
                           | Posix.Process.W_STOPPED s => Signalled (SysWord.toInt (Posix.Signal.toWord s))
                     val bytes = size (#stdout c) + size (#stderr c)
                     (* output that reached the cap is the cap, however the process
                        ended: a shell reports its child's SIGXFSZ as an exit status *)
                     val outcome = if #cap c > 0 andalso bytes >= #cap c andalso not (isSome why) then Capped else outcome
                     val r = {outcome = outcome, wall = Time.- (Runtime.clock (), start), user = user, system = system,
                              peakResident = peakResident, outputBytes = bytes, leaked = leaked}
                   in
                     finish (i, r); true
                   end)
      fun watch () =
        let
          val now = Runtime.clock ()
          val look = Time.> (Time.- (now, !lastLook), Time.fromMilliseconds 50)
          val () = if look then lastLook := now else ()
          fun one (_, i) =
            case Array.sub (state, i) of
              Running {pid, start, killedAt, why} =>
                (case (why, killedAt) of
                   (NONE, _) =>
                     let
                       val c = command i
                       val reason =
                         if Time.> (Time.- (now, start), #timeout c) then SOME TimedOut
                         else if look andalso #cap c > 0 andalso size (#stdout c) + size (#stderr c) > #cap c then SOME Capped
                         else NONE
                     in
                       case reason of
                         NONE => ()
                       | SOME w => (ignore (signalGroup (pid, term));
                                    Array.update (state, i, Running {pid = pid, start = start, killedAt = SOME now,
                                                                     why = SOME w}))
                     end
                 | (SOME _, SOME k) => if Time.> (Time.- (now, k), grace) then ignore (signalGroup (pid, kill)) else ()
                 | _ => ())
            | _ => ()
        in
          List.app one (!running)
        end
      fun busy () = not (Scheduler.finished sched)
      fun loop () =
        if not (busy ()) then ()
        else
          (admit ();
           if reap () then ()
           else (watch (); tick (length (!running)); OS.Process.sleep (Time.fromMilliseconds 2));
           loop ())
    in
      loop ()
      handle e =>
        (List.app (fn (pid, _) => ignore (signalGroup (pid, kill))) (!running);
         List.app (fn (pid, _) => ignore (Subprocess.wait (SOME pid)) handle OS.SysErr _ => ()) (!running);
         raise e)
    end
end

(* A run of commands: directories, the environment, verdicts, retention
   and the history. *)
structure Run :> RUN =
struct
  type command = {program : string, args : string list, env : string list option, dir : string option,
                  stdin : string option, timeout : Time.time, cap : int, cpus : int, memory : int,
                  pools : string list, exclusive : bool, after : string list,
                  judge : Supervisor.result * {stdout : string, stderr : string} -> (string * string) option}

  (* merge sort, by a strict order *)
  fun sort less xs =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if less (y, x) then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (x :: y :: rest) = let val (a, b) = split rest in (x :: a, y :: b) end
        | split xs = (xs, [])
      fun go [] = []
        | go [x] = [x]
        | go xs = let val (a, b) = split xs in merge (go a, go b) end
    in go xs end

  fun index names =
    let
      val order = Vector.fromList (sort (fn (a, b) => Vector.sub (names, a) < Vector.sub (names, b))
                                        (List.tabulate (Vector.length names, fn i => i)))
      fun find p =
        let
          fun go (lo, hi) =
            if lo >= hi then NONE
            else
              let val mid = (lo + hi) div 2
                  val i = Vector.sub (order, mid)
              in case String.compare (p, Vector.sub (names, i)) of
                   EQUAL => SOME i
                 | LESS => go (lo, mid)
                 | GREATER => go (mid + 1, hi)
              end
        in go (0, Vector.length order) end
    in find end

  fun lines file =
    let val s = TextIO.openIn file
    in String.fields (fn c => c = #"\n") (TextIO.inputAll s) before TextIO.closeIn s end
    handle IO.Io _ => []

  fun tail (n, file) =
    let
      val ls = lines file
      val ls = case rev ls of "" :: rest => rev rest | _ => ls
      val k = length ls
    in String.concatWith "\n" (List.drop (ls, Int.max (0, k - n))) end

  fun ending {stdout, stderr} =
    case (tail (12, stderr), tail (12, stdout)) of
      ("", "") => ""
    | ("", out) => "\n" ^ out
    | (err, _) => "\n" ^ err

  fun exitZero (r : Supervisor.result, files) =
    case (#outcome r, #leaked r) of
      (Supervisor.Exited 0, false) => NONE
    | (Supervisor.Exited 0, true) => SOME ("LEAK", "passed, but left processes behind")
    | (Supervisor.Exited n, _) => SOME ("FAIL", "exit " ^ Int.toString n ^ ending files)
    | (Supervisor.Signalled s, _) => SOME ("CRASH", "ended by signal " ^ Int.toString s ^ ending files)
    | (Supervisor.TimedOut, _) => SOME ("TIMEOUT", "ran past its time" ^ ending files)
    | (Supervisor.Capped, _) => SOME ("FAIL", "its output passed its cap")
    | (Supervisor.Cancelled, _) => SOME ("SKIP", "a test it waits for did not pass")
    | (Supervisor.Failed m, _) => SOME ("ERROR", "not started: " ^ m)

  fun shell (script, cpus) =
    {program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = SOME ".", stdin = NONE,
     timeout = Time.fromSeconds 3600, cap = 0, cpus = cpus, memory = 0, pools = [], exclusive = false, after = [],
     judge = exitZero}

  (* ---- files and directories *)
  fun isLink p = OS.FileSys.isLink p handle OS.SysErr _ => false
  fun isDir p = OS.FileSys.isDir p handle OS.SysErr _ => false
  fun entries path =
    let
      val d = OS.FileSys.openDir path
      fun go acc = case OS.FileSys.readDir d of NONE => acc | SOME n => go (n :: acc)
    in go [] before OS.FileSys.closeDir d end
    handle OS.SysErr _ => []
  fun rmTree path =
    if isLink path then OS.FileSys.remove path
    else if isDir path then (List.app (fn n => rmTree (path ^ "/" ^ n)) (entries path); OS.FileSys.rmDir path)
    else OS.FileSys.remove path handle OS.SysErr _ => ()
  fun treeBytes path =
    if isLink path then 0
    else if isDir path then List.foldl (fn (n, s) => s + treeBytes (path ^ "/" ^ n)) 0 (entries path)
    else (Position.toInt (OS.FileSys.fileSize path) handle OS.SysErr _ => 0)
  fun mkdirs path =
    let
      fun go (_, []) = ()
        | go (pre, a :: rest) =
            let val p = if pre = "" then (if a = "" then "/" else a) else if pre = "/" then "/" ^ a else pre ^ "/" ^ a
            in (if a = "" orelse isDir p then () else OS.FileSys.mkDir p); go (p, rest) end
    in go ("", String.fields (fn c => c = #"/") path) end

  val accept = ref false

  (* the runs kept in the directory of runs, this one among them *)
  val keepRuns = 5

  (* a word as the shell reads it back *)
  fun quote w =
    if w <> "" andalso CharVector.all (fn c => Char.isAlphaNum c orelse Char.contains "/._-=+:,@%" c) w then w
    else "'" ^ String.translate (fn #"'" => "'\\''" | c => str c) w ^ "'"

  fun pad5 i = StringCvt.padLeft #"0" 5 (Int.toString i)
  fun safe path = String.translate (fn #"/" => "__" | #" " => "_" | c => str c) path

  (* the runner's environment, without what would make a make inside a job
     part of the runner's own make, or force colour: MAKEFLAGS keeps the
     variables set on make's command line, and loses its jobs and its
     jobserver *)
  fun makeflags kv =
    let
      val words = String.tokens (fn c => c = #" ") (String.extract (kv, size "MAKEFLAGS=", NONE))
      val kept = List.filter (fn w => not (String.isPrefix "-j" w orelse String.isPrefix "--jobserver" w)) words
    in if List.all (fn w => w = "--") kept then NONE else SOME ("MAKEFLAGS=" ^ String.concatWith " " kept) end
  fun defaultEnv () =
    List.mapPartial (fn kv => if String.isPrefix "MAKEFLAGS=" kv then makeflags kv
                              else if List.exists (fn p => String.isPrefix p kv)
                                                  ["MAKELEVEL=", "MFLAGS=", "FORCE_COLOR=", "CLICOLOR_FORCE="] then NONE
                              else SOME kv)
                    (Posix.ProcEnv.environ ())

  fun run {tests, root, out, history, cpus, memory, keep, reader} =
    let
      val stamp = Date.fmt "%Y%m%d-%H%M%S" (Date.fromTimeLocal (Time.now ()))
                  ^ "-" ^ SysWord.fmt StringCvt.DEC (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
      val runDir = out ^ "/" ^ stamp
      (* the runs before, newest first by their stamps: the last few stay *)
      val () = mkdirs out
      val earlier = List.filter (fn n => size n > 15 andalso Char.isDigit (String.sub (n, 0))) (entries out)
      val earlier = List.foldl (fn (x, acc) => let fun ins [] = [x] | ins (y :: ys) = if x > y then x :: y :: ys else y :: ins ys
                                               in ins acc end) [] earlier
      val () = List.app (fn n => rmTree (out ^ "/" ^ n)) (List.drop (earlier, Int.min (length earlier, keepRuns - 1)))
      val () = mkdirs (runDir ^ "/j")
      (* the run's directory and the tree's, as a job finds them *)
      val absRun = OS.FileSys.fullPath runDir
      val absRoot = OS.FileSys.fullPath root
      val hist = ref (History.read history)
      val (pending, runnable) = List.partition (fn (_, m : Test.meta, _) => isSome (#pending m)) tests
      val runnable = Vector.fromList runnable
      val n = Vector.length runnable
      val index = index (Vector.map #1 runnable)
      val env = defaultEnv ()
      fun jobDir i = runDir ^ "/j/" ^ pad5 i
      fun place d = if String.isPrefix "/" d then d else if d = "." then absRoot else absRoot ^ "/" ^ d
      val commands =
        Vector.mapi (fn (i, (path, meta : Test.meta, c : command)) =>
                       let
                         (* no more CPUs than the run has, and the job told how many *)
                         val n = Int.max (1, Int.min (cpus, getOpt (#cpus meta, #cpus c)))
                       in
                       mkdirs (jobDir i);
                        {program = #program c, args = #args c,
                         env = ("RUNE_TEST_CPUS=" ^ Int.toString n) :: ("RUNE_TEST_RUN=" ^ absRun)
                               :: ("RUNE_TEST_ROOT=" ^ absRoot)
                               :: (if !accept then ["RUNE_TEST_ACCEPT=1"] else []) @ getOpt (#env c, env),
                         dir = case #dir c of NONE => jobDir i | SOME d => place d,
                         stdin = getOpt (#stdin c, "/dev/null"), stdout = jobDir i ^ "/stdout",
                         stderr = jobDir i ^ "/stderr", timeout = getOpt (#timeout meta, #timeout c), cap = #cap c,
                         cost = getOpt (History.cost (!hist, path), 1.0), cpus = n,
                         memory = getOpt (#memory meta, #memory c), pools = #pools c, exclusive = #exclusive c,
                         failedLast = History.failedLast (!hist, path),
                         deps = List.mapPartial index (#after c)} : Supervisor.command
                       end)
                    runnable
      val report = Report.start {reader = reader, events = runDir ^ "/events.jsonl", total = length tests}
      val freed = ref 0 and kept = ref 0
      val () =
        List.app (fn (path, meta : Test.meta, _) =>
                    Report.test (report, {path = path, verdict = "SKIP", reason = valOf (#pending meta), wall = Time.zeroTime,
                                          user = Time.zeroTime, system = Time.zeroTime, peakResident = 0, outputBytes = 0,
                                          kept = [], command = "", rerun = ""}))
                 pending
      fun finished (i, r : Supervisor.result) =
        let
          val (path, _, c) = Vector.sub (runnable, i)
          val sc = Vector.sub (commands, i)
          val files = {stdout = #stdout sc, stderr = #stderr sc}
          val cancelled = #outcome r = Supervisor.Cancelled
          val verdict = if cancelled then SOME ("SKIP", "a test it waits for did not pass") else #judge c (r, files)
          val bytes = treeBytes (jobDir i)
          val keptDirs =
            if cancelled orelse (not (isSome verdict) andalso not keep) then (freed := !freed + bytes; rmTree (jobDir i); [])
            else
              let val target = runDir ^ "/" ^ (if isSome verdict then "failed/" else "passed/") ^ safe path
              in kept := !kept + bytes; mkdirs (OS.Path.dir target); OS.FileSys.rename {old = jobDir i, new = target}; [target] end
              handle OS.SysErr _ => [jobDir i]
          val (v, reason) = getOpt (verdict, ("PASS", ""))
        in
          if cancelled then ()
          else hist := History.record (!hist, {path = path, wall = Time.toReal (#wall r), passed = not (isSome verdict)});
          not (isSome verdict) before Report.test (report, {path = path, verdict = v, reason = reason, wall = #wall r, user = #user r,
                                system = #system r, peakResident = #peakResident r, outputBytes = #outputBytes r,
                                kept = keptDirs,
                                command = "cd " ^ (if #dir sc = jobDir i then (case keptDirs of [d] => d | _ => #dir sc)
                                                   else #dir sc)
                                          ^ " && RUNE_TEST_ROOT=" ^ quote absRoot ^ " RUNE_TEST_RUN="
                                          ^ quote absRun ^ " " ^ String.concatWith " " (List.map quote (#args c)),
                                rerun = "bin/rune-test run '" ^ path ^ "'"})
        end
      (* Ctrl-C raises Interrupt in the loop, which ends every group *)
      val _ = Runtime.catchInterrupt ()
      val interrupted =
        (Supervisor.run {commands = commands, cpus = cpus, memory = memory, finished = finished,
                         tick = fn running => Report.tick (report, running)}; false)
        handle SML90.Interrupt => true
      val () = History.write (history, !hist) handle IO.Io _ => () | OS.SysErr _ => ()
      val ok = Report.finish (report, {cpus = cpus, freed = !freed, keptBytes = !kept})
    in
      ok andalso not interrupted
    end
end

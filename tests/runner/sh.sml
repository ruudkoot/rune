(* What the commands of the inventory do with files and processes, as the
   scripts they replace did with the shell: read and compare files, and run
   a program with its streams in files, in a directory, for at most a time,
   to its exit status. *)
structure Sh =
struct
  fun env (name, default) = case OS.Process.getEnv name of SOME v => if v = "" then default else v | NONE => default
  (* the tree's directory and the run's, as the runner gives them *)
  val root = env ("RUNE_TEST_ROOT", OS.FileSys.getDir ())
  val run = env ("RUNE_TEST_RUN", OS.FileSys.getDir ())
  fun fromRoot p = if String.isPrefix "/" p then p else root ^ "/" ^ p

  (* a word as the shell reads it back *)
  fun quote w =
    if w <> "" andalso CharVector.all (fn c => Char.isAlphaNum c orelse Char.contains "/._-=+:,@%" c) w then w
    else "'" ^ String.translate (fn #"'" => "'\\''" | c => str c) w ^ "'"

  fun say s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)
  fun exists f = OS.FileSys.access (f, []) handle OS.SysErr _ => false
  fun isDir f = OS.FileSys.isDir f handle OS.SysErr _ => false
  fun read f = (let val s = TextIO.openIn f in TextIO.inputAll s before TextIO.closeIn s end) handle IO.Io _ => ""
  fun write (f, text) = let val s = TextIO.openOut f in TextIO.output (s, text); TextIO.closeOut s end
  fun append (f, text) = let val s = TextIO.openAppend f in TextIO.output (s, text); TextIO.closeOut s end
  fun lines s = List.filter (fn l => l <> "") (String.fields (fn c => c = #"\n") s)
  fun firstLine f = case String.fields (fn c => c = #"\n") (read f) of l :: _ => l | [] => ""
  fun firstNonEmpty f = case lines (read f) of l :: _ => l | [] => ""
  (* a file's words, as $(cat FILE) gives them, or none *)
  fun words f = if exists f then String.tokens Char.isSpace (read f) else []
  (* cmp -s: both are there, and the same *)
  fun same (a, b) = exists a andalso exists b andalso read a = read b
  fun basename p = let val f = OS.Path.file p in case OS.Path.ext f of SOME "sml" => OS.Path.base f | _ => f end

  fun entries path =
    let
      val d = OS.FileSys.openDir path
      fun go acc = case OS.FileSys.readDir d of NONE => acc | SOME n => go (n :: acc)
    in go [] before OS.FileSys.closeDir d end
    handle OS.SysErr _ => []
  fun rmTree path =
    if (OS.FileSys.isLink path handle OS.SysErr _ => false) then OS.FileSys.remove path
    else if isDir path then (List.app (fn n => rmTree (path ^ "/" ^ n)) (entries path); OS.FileSys.rmDir path)
    else OS.FileSys.remove path handle OS.SysErr _ => ()
  fun mkdirs path =
    let
      fun go (_, []) = ()
        | go (pre, a :: rest) =
            let val p = if pre = "" then (if a = "" then "/" else a) else if pre = "/" then "/" ^ a else pre ^ "/" ^ a
            in (if a = "" orelse isDir p then () else OS.FileSys.mkDir p); go (p, rest) end
    in go ("", String.fields (fn c => c = #"/") path) end

  (* merge sort of strings *)
  fun sort xs =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if y < x then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (x :: y :: rest) = let val (a, b) = split rest in (x :: a, y :: b) end
        | split xs = (xs, [])
      fun go [] = []
        | go [x] = [x]
        | go xs = let val (a, b) = split xs in merge (go a, go b) end
    in go xs end

  (* the files of a directory with a suffix, by name, with the directory *)
  fun glob (dir, suffix) =
    List.map (fn n => dir ^ "/" ^ n) (sort (List.filter (fn n => String.isSuffix suffix n) (entries dir)))

  (* execEnv ENVF: run CMD in the environment ENVF makes of this one (its
     program first: on PATH when it has no directory, and from the root
     when its path is relative and DIR is another directory)
     in DIR, its streams to and from files ("" for /dev/null; stderr may be
     the file of stdout), for at most TIMEOUT seconds (0 for no limit); its
     exit status as the shell gives it: 128 and the signal for a signal,
     and 124 for the time *)
  fun execEnv envf {cmd, dir, stdin, stdout, stderr, timeout} =
    let
      val mode = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.irgrp,
                                        Posix.FileSys.S.iroth]
      fun openIn "" = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
        | openIn f = Posix.FileSys.openf (f, Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
      fun openOut "" = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_WRONLY, Posix.FileSys.O.flags [])
        | openOut f = Posix.FileSys.creat (f, mode)
      val i = openIn stdin
      val out = openOut stdout
      val err = if stderr = stdout andalso stdout <> "" then out else openOut stderr
      fun n fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
      (* a program named without a directory is looked for on PATH; in the
         root, a relative one keeps its name, since a wrapper of bin/ finds
         the library by it and the library's paths reach what it compiles *)
      val search = not (CharVector.exists (fn c => c = #"/") (hd cmd))
      val program = if search orelse not (isSome dir) then hd cmd else fromRoot (hd cmd)
      val pid =
        Subprocess.spawn {program = program, args = cmd, env = SOME (envf (Posix.ProcEnv.environ ())), search = search, dir = dir, stdin = SOME (n i),
                          stdout = SOME (n out), stderr = SOME (n err), group = true, limits = Subprocess.unlimited}
      val () = (Posix.IO.close i; Posix.IO.close out; if stderr = stdout andalso stdout <> "" then () else Posix.IO.close err)
      fun code status =
        case status of
          Posix.Process.W_EXITED => 0
        | Posix.Process.W_EXITSTATUS w => Word8.toInt w
        | Posix.Process.W_SIGNALED s => 128 + SysWord.toInt (Posix.Signal.toWord s)
        | Posix.Process.W_STOPPED s => 128 + SysWord.toInt (Posix.Signal.toWord s)
      val start = Runtime.clock ()
      fun waitFor () =
        case Subprocess.poll (SOME pid) of
          SOME {status, ...} => code status
        | NONE =>
            if Time.toSeconds (Time.- (Runtime.clock (), start)) >= LargeInt.fromInt timeout then
              ((Subprocess.kill (pid, Posix.Signal.kill) handle OS.SysErr _ => ());
               ignore (Subprocess.wait (SOME pid)); 124)
            else (OS.Process.sleep (Time.fromMilliseconds 20); waitFor ())
    in
      if timeout <= 0 then code (#status (Subprocess.wait (SOME pid))) else waitFor ()
    end

  fun exec x = execEnv (fn e => e) x

  (* an environment with a variable set, and without some *)
  fun setEnv (k, v) env = (k ^ "=" ^ v) :: List.filter (fn kv => not (String.isPrefix (k ^ "=") kv)) env
  fun unsetEnv ks env = List.filter (fn kv => not (List.exists (fn k => String.isPrefix (k ^ "=") kv) ks)) env

  (* what runevm --count says at exit, from its standard error *)
  fun countOf f =
    String.concatWith "\n" (List.mapPartial (fn l => if String.isPrefix "runevm: count: " l
                                                     then SOME (String.extract (l, size "runevm: count: ", NONE)) else NONE)
                                            (lines (read f)))

  (* a directory to run a program of tests/lang in: tests/out for what it
     writes at fixed paths, and tests/lang for what it reads *)
  fun scratch dir =
    (mkdirs (dir ^ "/tests/out");
     if exists (dir ^ "/tests/lang") then () else Posix.FileSys.symlink {old = root ^ "/tests/lang", new = dir ^ "/tests/lang"})

  (* where two files first differ, for a failure *)
  fun difference (a, b) =
    let
      fun go (n, x :: xs, y :: ys) = if x = y then go (n + 1, xs, ys) else SOME (n, x, y)
        | go (n, x :: _, []) = SOME (n, x, "(nothing)")
        | go (n, [], y :: _) = SOME (n, "(nothing)", y)
        | go (_, [], []) = NONE
    in
      case go (1, String.fields (fn c => c = #"\n") (read a), String.fields (fn c => c = #"\n") (read b)) of
        SOME (n, x, y) => "line " ^ Int.toString n ^ ": " ^ x ^ " / " ^ y
      | NONE => "the same"
    end

  (* the judge of a command of the inventory: it prints FAIL lines for what
     it found, and exits with 0 *)
  fun failLines (r : Supervisor.result, files as {stdout, ...}) =
    case #outcome r of
      Supervisor.Exited 0 =>
        (case List.filter (fn l => String.isPrefix "FAIL " l) (lines (read stdout)) of
           [] => NONE
         | ls => SOME ("FAIL", String.concatWith "\n" (List.take (ls, Int.min (30, length ls)))))
    | _ => Run.exitZero (r, files)
end

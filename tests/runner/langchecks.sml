(* Shared compiler/runtime fixture verdicts, separated from inventory creation. *)
structure LangChecks =
struct
  fun env (name, default) = case OS.Process.getEnv name of SOME v => if v = "" then default else v | NONE => default
  fun exists f = OS.FileSys.access (f, []) handle OS.SysErr _ => false
  fun read f = (let val s = TextIO.openIn f in TextIO.inputAll s before TextIO.closeIn s end) handle IO.Io _ => ""
  fun write (f, text) = let val s = TextIO.openOut f in TextIO.output (s, text); TextIO.closeOut s end
  (* with --accept, a golden file that differs is written, by one way only *)
  fun accept (writes, file, text) =
    if writes andalso !Run.accept then (write (file, text); SOME ("ACCEPTED", "wrote " ^ file)) else NONE
  fun firstLine s = case String.fields (fn c => c = #"\n") s of l :: _ => l | [] => ""
  (* the first line, with its end, as head -1 gives it *)
  fun headLine s = case CharVector.findi (fn (_, c) => c = #"\n") s of
                     SOME (i, _) => String.substring (s, 0, i + 1)
                   | NONE => s

  (* where two texts first differ, for a failure *)
  fun firstDifference (expected, actual) =
    let
      fun go (n, e :: es, a :: as') = if e = a then go (n + 1, es, as') else SOME (n, e, a)
        | go (n, e :: _, []) = SOME (n, e, "(nothing)")
        | go (n, [], a :: _) = SOME (n, "(nothing)", a)
        | go (_, [], []) = NONE
      fun lines s = String.fields (fn c => c = #"\n") s
    in
      case go (1, lines expected, lines actual) of
        SOME (n, e, a) => "\nfirst at line " ^ Int.toString n ^ ":\n  expected: " ^ e ^ "\n  actual:   " ^ a
      | NONE => ""
    end

  (* the programs of a directory, by name *)
  fun compileJudge (writes, name) (r : Supervisor.result, files as {stderr, ...}) =
    case #outcome r of
      Supervisor.Exited 0 =>
        let
          val cerr = read stderr
          val cwarn = "tests/lang/" ^ name ^ ".cwarn"
        in
          if exists cwarn then
            if cerr = read cwarn then NONE
            else case accept (writes, cwarn, cerr) of
                   SOME a => SOME a
                 | NONE => SOME ("FAIL", "compiler warnings differ from " ^ cwarn ^ firstDifference (read cwarn, cerr))
          else if cerr = "" then NONE
          else SOME ("FAIL", "unexpected compiler output: " ^ firstLine cerr)
        end
    | Supervisor.Exited _ => SOME ("FAIL", "compile error: " ^ firstLine (read stderr))
    | _ => Run.exitZero (r, files)

  fun errorJudge (writes, name) (r : Supervisor.result, files as {stderr, ...}) =
    case #outcome r of
      Supervisor.Exited 0 => SOME ("FAIL", "expected a compile error but compilation succeeded")
    | Supervisor.Exited _ =>
        let
          val expected = "tests/errors/" ^ name ^ ".expected"
          (* as $(cat FILE) gives it: without the newlines at its end *)
          val text = let fun drop (#"\n" :: cs) = drop cs | drop cs = cs
                     in String.implode (rev (drop (rev (String.explode (read expected))))) end
          val line = firstLine (read stderr)
          (* what --accept writes: the line without its place and "error: " *)
          fun message l =
            case CharVector.findi (fn (_, c) => c = #" ") l of
              SOME (i, _) => if String.isPrefix " error: " (String.extract (l, i, NONE))
                             then String.extract (l, i + size " error: ", NONE) else l
            | NONE => l
        in
          if exists expected andalso String.isSubstring text line then NONE
          else case accept (writes, expected, message line ^ "\n") of
                 SOME a => SOME a
               | NONE => if not (exists expected) then SOME ("FAIL", "missing " ^ expected)
                         else SOME ("FAIL", "error message mismatch: " ^ line ^ "\n  expected it to contain: " ^ text)
        end
    | _ => Run.exitZero (r, files)

  fun expectedCode name =
    let val f = "tests/lang/" ^ name ^ ".exitcode"
    in if exists f then getOpt (Int.fromString (read f), ~1) else 0 end

  fun runJudge (writes, name) (r : Supervisor.result, files as {stdout, stderr}) =
    let
      val base = "tests/lang/" ^ name
      val dir = OS.Path.dir stdout
      (* the first of the checks that fails, in run-tests.sh's order *)
      fun first [] = NONE
        | first ((fails, why) :: rest) = if fails () then SOME ("FAIL", why ()) else first rest
    in
      case #outcome r of
        Supervisor.Exited code =>
          (* the same in a run of the host compilers' bytes: the stack way's run *)
          if exists (dir ^ "/same") then NONE
          else
            let
              val err = read stderr
              val out = read stdout
              val expected = read (base ^ ".expected")
              val restoring = exists (base ^ ".restore")
              val img = dir ^ "/tests/out/" ^ name ^ ".img"
              fun rcode () = getOpt (Int.fromString (read (dir ^ "/restored.code")), ~1)
            in
              first
                [(fn () => code <> expectedCode name,
                  fn () => "exit code " ^ Int.toString code ^ ", expected " ^ Int.toString (expectedCode name) ^ ": "
                           ^ firstLine err),
                 (fn () => not (exists (base ^ ".expected")), fn () => "missing " ^ base ^ ".expected"),
                 (fn () => out <> expected andalso not (isSome (accept (writes, base ^ ".expected", out))),
                  fn () => "stdout differs from " ^ base ^ ".expected" ^ firstDifference (expected, out)),
                 (fn () => exists (base ^ ".stderr") andalso err <> read (base ^ ".stderr"),
                  fn () => "stderr differs from " ^ base ^ ".stderr" ^ firstDifference (read (base ^ ".stderr"), err)),
                 (fn () => exists (base ^ ".stderr-head") andalso headLine err <> read (base ^ ".stderr-head"),
                  fn () => "runtime error differs from " ^ base ^ ".stderr-head: " ^ firstLine err),
                 (fn () => restoring andalso not (exists img), fn () => "no tests/out/" ^ name ^ ".img to restore"),
                 (fn () => restoring andalso rcode () <> 0,
                  fn () => "--restore exited " ^ Int.toString (rcode ()) ^ ": " ^ firstLine (read (dir ^ "/restored.err"))),
                 (fn () => restoring andalso read (dir ^ "/restored") <> read (base ^ ".restore"),
                  fn () => "restored stdout differs from " ^ base ^ ".restore"
                           ^ firstDifference (read (base ^ ".restore"), read (dir ^ "/restored")))]
            end
      | _ => Run.exitZero (r, files)
    end

end

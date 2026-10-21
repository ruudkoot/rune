(* Mutation adequacy: each target has a baseline producer, and each sampled
   site is an ordinary supervised job. A broken controller is an error, never
   evidence that a mutant was killed. The mutation producer is already SML. *)
structure Mutants =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  val targets = [("list", "List"), ("listpair", "ListPair"), ("char", "Char"), ("string", "String"),
    ("substring", "Substring"), ("int", "Int"), ("intn_fn", "Int8"), ("intinf", "IntInf"),
    ("word", "Word"), ("wordn_fn", "Word8"), ("array", "Array"), ("arrayslice", "ArraySlice"),
    ("array2", "Array2"), ("byte", "Byte")]
  fun selected () = List.filter (fn (name, _) => String.isSubstring (env ("MUTANT_FILTER", "")) name) targets
  fun positive key fallback = case Int.fromString (env (key, fallback)) of SOME n =>
         (need (n > 0, key ^ " must be positive"); n) | NONE => raise Failed (key ^ " must be an integer")
  fun samples () = positive "MUTANTS_PER_FILE" "20"
  fun directory () = run ^ "/mutants"
  fun compiler () = MatrixModel.find (env ("RUNE", fromRoot "bin/rune"))
  fun vm () = MatrixModel.find (env ("RUNEVM", fromRoot "bin/runevm"))
  val limits = {addressSpace = NONE, cpuTime = SOME 900, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
  fun execute log args = Children.exec limits (fn e => e)
    {cmd = args, dir = SOME root, stdin = "", stdout = log, stderr = log, timeout = 900}
  fun compile lib source output =
    let val () = rmTree output
        val log = output ^ ".cerr"
        val status = execute log ([compiler ()] @ (if lib = "" then [] else ["--lib", lib, "--library", "test/property/basis"])
                                         @ [source, "-o", output])
    in if status = 0 then (need (exists output andalso OS.FileSys.fileSize output > 0,
                                      "compiler exited zero without bytecode"); true)
       else if status = 1 andalso String.isSubstring "error:" (read log) then false
       else raise Failed ("compiler failed: " ^ Int.toString status ^ ": " ^ firstNonEmpty log) end
  fun link (old, new) = Posix.FileSys.symlink {old = old, new = new}
  fun library dir basis =
    (mkdirs (dir ^ "/test"); link (fromRoot "lib/random", dir ^ "/random");
     link (fromRoot "lib/test/property", dir ^ "/test/property"); link (basis, dir ^ "/basis"))
  fun passLabels output = Sh.sort (HostLaws.unique (List.map #1
      (List.filter (fn (_, (v, _)) => v = "PASS") (HostLaws.verdicts output))))
  fun sampled total per =
    let val step = Int.max (1, (total + per - 1) div per)
        fun go k = if k > total then [] else k :: go (k + step)
    in go 1 end
  (* Preserve the original per-law idle deadline, in the outer job's process
     group. The job supervisor owns all descendants and output limits. *)
  fun attempt rbc st last log =
    let val mode = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr]
        val out = Posix.FileSys.creat (log, mode)
        val input = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
        fun fd n = SysWord.toInt (Posix.FileSys.fdToWord n)
        val environment = setEnv ("RUNE_PROPERTY_AT", st) o setEnv ("RUNE_PROPERTY_AFTER", last)
        val pid = Subprocess.spawn {program = vm (), args = [vm (), rbc], search = false, dir = SOME root,
          env = SOME (environment (Posix.ProcEnv.environ ())), stdin = SOME (fd input), stdout = SOME (fd out), stderr = SOME (fd out),
          group = false, limits = {addressSpace = SOME (positive "LAWS_MEMORY" "4096" * 1024 * 1024),
                                 cpuTime = NONE, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}}
        val () = (Posix.IO.close out; Posix.IO.close input)
        val timeout = Time.fromSeconds (LargeInt.fromInt (positive "LAWS_TIMEOUT" "30"))
        fun watch (seen, since) = case Subprocess.poll (SOME pid) of SOME {status, ...} => SOME status
          | NONE =>
            let val () = OS.Process.sleep (Time.fromMilliseconds 100)
                val count = length (List.filter (String.isPrefix "LAW ") (lines (read log)))
                val now = Runtime.clock ()
            in if count <> seen then watch (count, now)
               else if Time.< (Time.- (now, since), timeout) then watch (seen, since)
               else (Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)), Posix.Signal.kill);
                     ignore (Subprocess.wait (SOME pid)); NONE) end
    in (watch (0, Runtime.clock ()), read log) end
  fun runProgram rbc st log baseline =
    let fun loop (last, tries, prior) =
          let val (status, output) = attempt rbc st last log
              val results = List.filter (fn line => String.isPrefix "PASS " line orelse String.isPrefix "FAIL " line) (lines output)
              val laws = List.filter (String.isPrefix "LAW ") (lines output)
              val final = List.exists (String.isPrefix "laws: ") (lines output)
              val normal = case status of SOME Posix.Process.W_EXITED => true
                | SOME (Posix.Process.W_EXITSTATUS 0w1) => List.exists (String.isPrefix "FAIL ") results
                | _ => false
          in if final then (need (normal, "law child failed after its summary"); prior @ results)
             else if null laws then raise Failed "law framework failed before its first law"
             else
               let val label = case String.tokens Char.isSpace (List.last laws) of ["LAW", label] => label
                                 | _ => raise Failed "malformed law marker"
                   val () = need (last <> label andalso tries < 50, "law recovery made no progress")
                   val () = need (not baseline, "baseline law stopped: " ^ label)
               in loop (label, tries + 1, prior @ results @ ["STOPPED " ^ label]) end
          end
    in String.concat (List.map (fn line => line ^ "\n") (loop ("", 0, []))) end
  fun run lib st name baseline =
    let val dir = directory ()
        val files = List.filter (fn file => String.isSubstring ("@" ^ st ^ "\"") (read file)) (glob (dir ^ "/programs", ".sml"))
        val () = need (not (null files), "no law program for " ^ st)
        fun one file =
          let val rbc = dir ^ "/runs/" ^ name ^ "." ^ basename file ^ ".rbc"
          in if not (compile lib file rbc) then NONE else
               let val output = runProgram rbc st (rbc ^ ".run") baseline
               in rmTree rbc; SOME output end end
        val outputs = List.map one files
    in if List.exists (not o isSome) outputs then NONE else SOME (String.concat (List.map valOf outputs)) end
  fun prepare () =
    let val dir = directory ()
        val () = rmTree dir
        val () = mkdirs (dir ^ "/runs")
        val () = mkdirs (dir ^ "/programs")
        val status = execute (dir ^ "/runedoc.log") [MatrixModel.find (env ("RUNEDOC", fromRoot "bin/runedoc")),
                              "--lib", "lib", "--library", "basis", "--laws", dir ^ "/programs"]
        val () = need (status = 0, "runedoc --laws failed")
        val () = need (compile "" (fromRoot "tools/mutate/mutate.sml") (dir ^ "/mutate.rbc"), "mutation producer does not compile")
        val () = library (dir ^ "/base-lib") (fromRoot "lib/basis")
    in () end
  fun baseline (file, st) () =
    let val dir = directory ()
        val output = case run (dir ^ "/base-lib") st ("base-" ^ st) true of SOME output => output
                          | NONE => raise Failed ("baseline does not compile: " ^ st)
        val pass = passLabels output
        val () = need (not (null pass), "baseline has no passing laws: " ^ st)
        val () = write (dir ^ "/base-" ^ st ^ ".result", output)
        val () = write (dir ^ "/base-" ^ st ^ ".pass", String.concat (List.map (fn name => name ^ "\n") pass))
        val log = dir ^ "/sites-" ^ file ^ ".txt"
        val status = execute log [vm (), dir ^ "/mutate.rbc", "lib/basis/" ^ file ^ ".sml"]
        val () = need (status = 0, "mutation-site producer failed")
        val sites = lines (read log)
        val () = List.app (fn (i, line) => need (String.isPrefix (Int.toString (i + 1) ^ " ") line,
                                          "malformed mutation-site listing")) (ListPair.zip (List.tabulate (length sites, fn i => i), sites))
    in () end
  fun classify baseline output =
    let val passed = passLabels output
        val missing = List.filter (fn name => not (List.exists (fn present => present = name) passed)) baseline
    in if null missing then ("SURVIVED", []) else ("KILLED", missing) end
  fun mutant (file, st) ordinal () =
    let val dir = directory ()
        val sites = lines (read (dir ^ "/sites-" ^ file ^ ".txt"))
        val ks = sampled (length sites) (samples ())
    in if ordinal >= length ks then say "UNUSED mutation slot\n" else
      let val k = List.nth (ks, ordinal)
          val name = file ^ "-" ^ Int.toString k
          val lib = dir ^ "/libs/" ^ name
          val () = rmTree lib
          val () = mkdirs (lib ^ "/basis")
          val () = List.app (fn name => if name = file ^ ".sml" then () else
                    link (fromRoot ("lib/basis/" ^ name), lib ^ "/basis/" ^ name)) (entries (fromRoot "lib/basis"))
          val source = lib ^ "/basis/" ^ file ^ ".sml"
          val status = execute source [vm (), dir ^ "/mutate.rbc", "lib/basis/" ^ file ^ ".sml", Int.toString k]
          val () = need (status = 0 andalso exists source andalso OS.FileSys.fileSize source > 0, "mutation producer failed")
          val () = mkdirs (lib ^ "/test")
          val () = link (fromRoot "lib/random", lib ^ "/random")
          val () = link (fromRoot "lib/test/property", lib ^ "/test/property")
          val (verdict, killers) = case run lib st name false of NONE => ("STILLBORN", [])
            | SOME output => (write (dir ^ "/runs/" ^ name ^ ".result", output);
                              classify (lines (read (dir ^ "/base-" ^ st ^ ".pass"))) output)
          val site = case String.tokens Char.isSpace (List.nth (sites, k - 1)) of _ :: rest => String.concatWith " " rest | _ => ""
          val result = verdict ^ " " ^ file ^ " " ^ Int.toString k ^ " " ^ site
                         ^ (if null killers then "" else " by " ^ String.concatWith " " killers) ^ "\n"
          val () = write (dir ^ "/runs/" ^ name ^ ".verdict", result)
          val () = rmTree lib
      in say result end
    end
  fun final () =
    let val dir = directory ()
        val results = List.concat (List.map (lines o read) (glob (dir ^ "/runs", ".verdict")))
        val results = sort results
        val () = write (dir ^ "/results.txt", String.concat (List.map (fn line => line ^ "\n") results))
        fun summary (file, st) =
          let val selected = List.filter (fn line => case String.tokens Char.isSpace line of _ :: f :: _ => f = file | _ => false) results
              val ks = sampled (length (lines (read (dir ^ "/sites-" ^ file ^ ".txt")))) (samples ())
              val () = need (length selected = length ks, "missing mutant verdict for " ^ file)
              fun count status = length (List.filter (String.isPrefix (status ^ " ")) selected)
          in file ^ " (" ^ st ^ ", " ^ Int.toString (length (lines (read (dir ^ "/base-" ^ st ^ ".pass"))))
             ^ " laws pass): " ^ Int.toString (count "KILLED") ^ " of " ^ Int.toString (length selected - count "STILLBORN")
             ^ " mutants killed, " ^ Int.toString (count "SURVIVED") ^ " survived, " ^ Int.toString (count "STILLBORN") ^ " stillborn\n" end
        val text = String.concat (List.map summary (selected ()))
        val () = write (dir ^ "/summary.txt", text)
        val () = say text
        val public = fromRoot "tests/out/mutants"
        val () = rmTree public
        val () = mkdirs public
        val () = List.app (fn name => write (public ^ "/" ^ name, read (dir ^ "/" ^ name))) ["results.txt", "summary.txt"]
    in () end
  fun protect f () = f () handle Failed why => (say ("FAIL mutation controller: " ^ why ^ "\n"); Posix.Process.exit 0w1)
  fun target file = case List.find (fn (name, _) => name = file) targets of SOME pair => pair | NONE => raise Failed "unknown mutation target"
  fun command ["mutants-prepare"] = SOME (protect prepare)
    | command ["mutants-baseline", file] = SOME (protect (baseline (target file)))
    | command ["mutant", file, i] = SOME (protect (mutant (target file) (case Int.fromString i of SOME n => n | NONE => raise Failed "invalid mutation slot")))
    | command ["mutants-final"] = SOME (protect final)
    | command ["mutants-verdict", file, i] = SOME (protect (fn () =>
        let val sites = lines (read (directory () ^ "/sites-" ^ file ^ ".txt"))
            val ks = sampled (length sites) (samples ())
            val ordinal = case Int.fromString i of SOME n => n | NONE => raise Failed "invalid mutation slot"
        in if ordinal >= length ks then say "UNUSED mutation slot\n" else
           let val path = directory () ^ "/runs/" ^ file ^ "-" ^ Int.toString (List.nth (ks, ordinal)) ^ ".verdict"
           in need (exists path, "missing mutant verdict"); say (read path) end end))
    | command _ = NONE
  fun job (name, args, after, judge) = Test.it name {program = "/bin/sh", args = ["sh", "-c",
       "exec \"$RUNE_TEST_ROOT\"/bin/rune-doc-check " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 14400, cap = 0, cpus = 1,
       memory = 4500, pools = [], exclusive = false, after = after, judge = judge} : Run.command Test.tree
  fun mutantJudge (result, files) = case failLines (result, files) of SOME why => SOME why | NONE =>
    if String.isPrefix "SURVIVED " (read (#stdout files)) then SOME ("FAIL", firstNonEmpty (#stdout files)) else
    if String.isPrefix "UNUSED " (read (#stdout files)) then SOME ("SKIP", "fewer mutation sites than sample slots") else NONE
  fun tree () =
    let val targets = selected ()
        fun jobs (file, _) = job ("baseline-" ^ file, ["mutants-baseline", file], ["mutants/prepare"], failLines)
              :: List.concat (List.tabulate (samples (), fn i =>
                 let val name = file ^ "/" ^ Int.toString (i + 1)
                 in [job (name, ["mutant", file, Int.toString i], ["mutants/baseline-" ^ file], failLines),
                     job (name ^ "/verdict", ["mutants-verdict", file, Int.toString i], ["mutants/" ^ name], mutantJudge)] end))
        val after = List.concat (List.map (fn (file, _) => List.tabulate (samples (), fn i => "mutants/" ^ file ^ "/" ^ Int.toString (i + 1))) targets)
    in Test.tag "test-mutants" (Test.tag "covers:tools/mutate/*" (Test.tag "covers:lib/basis/*"
       (Test.describe "mutants" (job ("prepare", ["mutants-prepare"], [], failLines) :: List.concat (List.map jobs targets)
                                  @ [job ("final", ["mutants-final"], after, failLines)])))) end
  fun main args =
    let fun parse ([], changes, jobs) = (changes, jobs)
          | parse ("-j" :: value :: rest, changes, _) = parse (rest, changes, value)
          | parse ("-n" :: value :: rest, changes, jobs) = parse (rest, ("MUTANTS_PER_FILE", value) :: changes, jobs)
          | parse ([filter], changes, jobs) = (need (not (String.isPrefix "-" filter), "unknown mutation option");
                                              (("MUTANT_FILTER", filter) :: changes, jobs))
          | parse _ = raise Failed "usage: rune-doc-check mutants [-j N] [-n PER_FILE] [FILTER]"
        val (changes, jobs) = parse (args, [], "1")
        val () = need (case Int.fromString jobs of SOME n => n > 0 | NONE => false, "invalid mutation job count")
        val environment = List.foldl (fn ((name, value), e) => setEnv (name, value) e) (Posix.ProcEnv.environ ()) changes
        val program = fromRoot "bin/runevm"
    in Posix.Process.exece (program, [program, fromRoot "bin/rune-test.rbc", "run", "--tier", "test-mutants", "-j", jobs], environment) end
end

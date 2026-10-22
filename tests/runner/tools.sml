(* The tools' suites on the runner (docs/plans/unit-testing.md, M10): what
   tests/ir/run-ir-tests.sh, tests/doc/run-doc-tests.sh,
   tests/lib/run-lib-tests.sh, tests/flexrec/run.sh, bin/rune-scenarios units,
   tests/compiler/run-tests.py, tests/runtime/run-limits.py and
   tests/runtime/run-gc-log.py did, a job for each case where the cases are
   apart, each a command of bin/rune-test that prints a line FAIL for what
   it finds. `--accept` (RUNE_TEST_ACCEPT) writes the expected files of the
   IR's dumps and of the documentation's tests, as their --update did.

   tests/deps, tests/dynamic, tests/buildfile and tests/install are
   scenarios whose steps build on one another, written in the shell with
   their sources: each is a job that runs its script. *)
structure Tools =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")
  fun contains (f, text) = String.isSubstring text (read f)
  fun hasLine (f, prefix) = List.exists (fn l => String.isPrefix prefix l) (lines (read f))
  (* the PASS and FAIL check of the suites: a line PASS and no line FAIL *)
  fun passes f = hasLine (f, "PASS") andalso not (hasLine (f, "FAIL"))
  fun noFail f = not (hasLine (f, "FAIL"))
  fun first ext l = case lines (read l) of x :: _ => x | [] => ""

  (* ---- tests/ir *)
  fun irOne src =
    let
      (* the name, without .sml or .mid *)
      val n = let val f = OS.Path.file src in if String.isSuffix ".mid" f then String.substring (f, 0, size f - 4) else basename src end
      val out = run ^ "/ir"
      val () = mkdirs out
      fun f ext = out ^ "/" ^ n ^ ext
      val line1 = case String.fields (fn c => c = #"\n") (read src) of l :: _ => l | [] => ""
      fun marker m = if String.isPrefix ("(* " ^ m ^ ": ") line1 andalso String.isSuffix " *)" line1
                     then SOME (String.substring (line1, size m + 5, size line1 - size m - 8)) else NONE
      val input = if String.isSuffix ".mid" src then ["--read-mid", src] else ["--no-prelude", "-o", f ".rbc", src]
      fun rune flags = exec {cmd = ["bin/rune-stack", "--lint", "--mid-roundtrip"] @ flags @ input, dir = NONE, stdin = "",
                             stdout = f ".out", stderr = f ".err", timeout = 0}
      val expected = "tests/ir/" ^ n ^ ".expected"
    in
      case (marker "fail", marker "dump") of
        (SOME msg, _) =>
          if rune [] = 0 then fail ("ir." ^ n ^ ": accepted, where it should stop with: " ^ msg)
          else if contains (f ".err", msg) then ()
          else fail ("ir." ^ n ^ ": stopped with: " ^ firstLine (f ".err"))
      | (NONE, SOME dump) =>
          if rune (String.tokens Char.isSpace dump) <> 0 then fail ("ir." ^ n ^ ": rune failed: " ^ firstLine (f ".err"))
          else if same (f ".out", expected) then ()
          else if accepting then (write (expected, read (f ".out")); say ("ACCEPTED " ^ expected ^ "\n"))
          else fail ("ir." ^ n ^ ": the dump differs from " ^ expected ^ ": " ^ difference (expected, f ".out"))
      | _ => fail ("ir." ^ n ^ ": its first line names no dump")
    end

  (* ---- tests/doc *)
  fun sameDoc (what, got, want) =
    if same (got, want) then ()
    else if accepting then write (want, read got)
    else fail ("doc: " ^ what ^ " (diff " ^ want ^ " " ^ got ^ "): " ^ difference (want, got))

  (* where run-doc-tests.sh wrote, since a site's links to its sources are
     relative to where it is *)
  val docOut = "tests/out/doc"

  fun docOne n =
    let
      val out = docOut
      val () = mkdirs out
      val src = "tests/doc/" ^ n ^ ".sml"
      fun t ext = "tests/doc/" ^ n ^ ext
      fun o' ext = out ^ "/" ^ n ^ ext
      (* the options of runedoc beside --page and --dump-ir: NAME.args *)
      val extra = words (t ".args")
      (* the diagnostics: compared when expected, else there must be none *)
      fun diag (got, want) =
        if exists want then sameDoc (OS.Path.file want, got, want)
        else if size (read got) > 0 then fail ("doc: " ^ n ^ " printed diagnostics and has no " ^ OS.Path.file want ^ ": " ^ firstLine got)
        else ()
    in
      if exists (t ".ir") orelse exists (t ".diag") then
        (ignore (exec {cmd = ["bin/runedoc"] @ extra @ ["--dump-ir", src], dir = NONE, stdin = "", stdout = o' ".ir", stderr = o' ".diag", timeout = 0});
         if exists (t ".ir") then sameDoc (n ^ ".ir", o' ".ir", t ".ir") else ();
         diag (o' ".diag", t ".diag"))
      else ();
      if exists (t ".md") then
        (ignore (exec {cmd = ["bin/runedoc"] @ extra @ ["--page", src], dir = NONE, stdin = "", stdout = o' ".md", stderr = o' ".md.diag", timeout = 0});
         sameDoc (n ^ ".md", o' ".md", t ".md");
         diag (o' ".md.diag", t ".md.diag"))
      else ()
    end

  fun docLib n =
    let
      val out = docOut
      val () = mkdirs out
      val lib = "tests/doc/" ^ n ^ ".lib"
      fun t ext = "tests/doc/" ^ n ^ ".lib" ^ ext
      fun o' ext = out ^ "/" ^ n ^ ext
      val site = out ^ "/" ^ n ^ ".site"
      val suite = (if isDir (lib ^ "/tests") then ["--tests", lib ^ "/tests"] else [])
                  @ (if exists (lib ^ "/ANNOTATIONS") then ["--annotations", lib ^ "/ANNOTATIONS"] else [])
                  @ (if exists (lib ^ "/LAW-SKIPS") then ["--law-skips", lib ^ "/LAW-SKIPS"] else [])
      val where' = (if exists (lib ^ "/ON-BASIS") then ["--lib", "lib", "--library", "./tests/doc/" ^ n ^ ".lib"]
                    else ["--lib", "tests/doc", "--library", n ^ ".lib"])
                   @ (if exists (lib ^ "/BASIS-DOCS") then "--basis-docs" :: words (lib ^ "/BASIS-DOCS") else [])
      val () = rmTree site
      val _ = exec {cmd = ["bin/runedoc"] @ where' @ suite @ ["--out", site, "--title", n], dir = NONE, stdin = "", stdout = "",
                    stderr = o' ".lib.diag", timeout = 0}
      (* find . -type f | sort, in the C locale *)
      fun tree dir = List.concat (List.map (fn e => let val p = dir ^ "/" ^ e
                                                    in if isDir p then List.map (fn x => e ^ "/" ^ x) (tree p) else [e] end)
                                           (entries dir))
      val () = write (o' ".lib.files", String.concat (List.map (fn p => "./" ^ p ^ "\n") (sort (if isDir site then tree site else []))))
      val () = sameDoc (n ^ ".lib.diag", o' ".lib.diag", t ".diag")
      val () = sameDoc (n ^ ".lib.files", o' ".lib.files", t ".files")
      fun optional (ext, text) = if exists (t ext) then (write (o' (".lib" ^ ext), text ()); sameDoc (n ^ ".lib" ^ ext, o' (".lib" ^ ext), t ext)) else ()
      val () = optional (".notes", fn () => read (site ^ "/notes.tsv"))
      val () = optional (".members", fn () => read (site ^ "/members.json"))
      val () = optional (".md", fn () => String.concat (List.map read (glob (site ^ "/sig", ".md"))))
      val () = optional (".types", fn () => read (site ^ "/types.md"))
      val () = optional (".structures", fn () => read (site ^ "/structures.md"))
      fun programs (ext, flag) =
        if exists (t ext) then
          let val d = out ^ "/" ^ n ^ ext
          in
            rmTree d;
            ignore (exec {cmd = ["bin/runedoc"] @ where' @ [flag, d], dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 0});
            write (o' (".lib" ^ ext), String.concat (List.map read (glob (d, ".sml"))));
            sameDoc (n ^ ".lib" ^ ext, o' (".lib" ^ ext), t ext)
          end
        else ()
      val () = programs (".examples", "--examples")
      val () = programs (".laws", "--laws")
    in
      if isDir (lib ^ "/tests") then
        (ignore (exec {cmd = ["bin/runedoc", "--tests", lib ^ "/tests", "--labels"], dir = NONE, stdin = "", stdout = o' ".lib.labels",
                       stderr = o' ".lib.labels", timeout = 0});
         ignore (exec {cmd = ["bin/runedoc", "--lib", "tests/doc", "--library", n ^ ".lib", "--tests", lib ^ "/tests", "--check-coverage"],
                       dir = NONE, stdin = "", stdout = o' ".lib.cover", stderr = o' ".lib.cover", timeout = 0});
         sameDoc (n ^ ".lib.labels", o' ".lib.labels", t ".labels");
         sameDoc (n ^ ".lib.cover", o' ".lib.cover", t ".cover"))
      else ()
    end

  (* The overview of several libraries, docs/lib/README.md. *)
  fun docOverview () =
    let
      val out = docOut ^ "/overview"
      val err = docOut ^ "/overview.err"
      val args = ["bin/runedoc", "--lib", "tests/doc/overview", "--overview", out,
                  "--library-page", "red", "red",
                  "--library-page", "blue", "blue"]
      val () = rmTree out
      val () = mkdirs out
      val code = exec {cmd = args, dir = NONE, stdin = "", stdout = "", stderr = err, timeout = 0}
      val () =
        if code <> 0 orelse size (read err) > 0 then
          fail ("doc: overview: runedoc failed: " ^ firstLine err)
        else ()
      val () = sameDoc ("overview.md", out ^ "/README.md", "tests/doc/overview.md")
      val code2 = exec {cmd = args @ ["--check"], dir = NONE, stdin = "", stdout = "", stderr = err, timeout = 0}
    in
      if code2 <> 0 orelse size (read err) > 0 then
        fail ("doc: overview: --check failed: " ^ firstLine err)
      else ()
    end

  (* ---- tests/lib *)
  val libOut = run ^ "/lib"

  (* compile FILE with the libraries, and run it from the root: the check on
     its output, or a FAIL line *)
  fun libProgram (n, flags, src) =
    let
      val () = mkdirs libOut
      fun f ext = libOut ^ "/" ^ n ^ ext
      val () = mkdirs (OS.Path.dir (f ".rbc"))
    in
      if exec {cmd = ["bin/rune"] @ flags @ [src, "-o", f ".rbc"], dir = NONE, stdin = "", stdout = f ".cerr", stderr = f ".cerr",
               timeout = 0} <> 0
      then (fail ("lib." ^ n ^ ": does not compile: " ^ firstLine (f ".cerr")); NONE)
      else (ignore (exec {cmd = ["bin/runevm", f ".rbc"], dir = NONE, stdin = "", stdout = f ".out", stderr = f ".out", timeout = 0});
            SOME (f ".out"))
    end

  fun libCheck (kind, n, flags, src) =
    case libProgram (n, flags, src) of
      NONE => ()
    | SOME out =>
        let
          fun field (prefix, expected) =
            case List.find (fn l => String.isPrefix prefix l) (lines (read out)) of
              SOME l => (case String.tokens Char.isSpace l of _ :: x :: _ => x = String.concat (String.tokens Char.isSpace (read expected))
                                                           | _ => false)
            | NONE => false
          val ok =
            case kind of
              "passes" => passes out
            | "nofail" => noFail out
            | "fingerprint" => noFail out andalso field ("fingerprint", "tests/lib/property/fingerprint.expected")
            | "frozen" => noFail out andalso field ("frozen", "tests/lib/property/frozen.expected")
            | "mutants" => noFail out andalso not (hasLine (out, "SURVIVED"))
            | _ => false
        in if ok then () else fail ("lib." ^ n ^ ": " ^ kind ^ " (see " ^ out ^ ")") end

  (* toy and toy2, libraries of a library root of their own: their use, a
     program listed by hand, --basis-deps, --basis-check, _prim, a library
     written on itself, and runedoc on a library written on another *)
  fun libToy () =
    let
      val out = libOut ^ "/toy"
      val root' = out ^ "/root"
      val () = (rmTree out; mkdirs root')
      val () = Posix.FileSys.symlink {old = root ^ "/lib/basis", new = root' ^ "/basis"}
      val () = List.app (fn x => Posix.FileSys.symlink {old = root ^ "/tests/lib/" ^ x, new = root' ^ "/" ^ x})
                        ["toy", "toy2", "prim", "cycle1", "cycle2"]
      fun rune (args, log) = exec {cmd = ["bin/rune", "--lib", root'] @ args, dir = NONE, stdin = "", stdout = log, stderr = log,
                                   timeout = 0}
      fun use n lib =
        if rune (["--library", lib, "tests/lib/" ^ n ^ ".sml", "-o", out ^ "/" ^ n ^ ".rbc"], out ^ "/" ^ n ^ ".cerr") = 0
           andalso exec {cmd = ["bin/runevm", out ^ "/" ^ n ^ ".rbc"], dir = NONE, stdin = "", stdout = out ^ "/" ^ n ^ ".out",
                         stderr = out ^ "/" ^ n ^ ".out", timeout = 0} = 0
           andalso same (out ^ "/" ^ n ^ ".out", "tests/lib/" ^ n ^ ".expected")
        then () else fail ("lib." ^ n ^ ": its output is not tests/lib/" ^ n ^ ".expected")
      val () = use "use-toy" "toy"
      val () = use "use-toy2" "toy2"
      val () = if rune ([root' ^ "/toy/toy.sml", "tests/lib/use-toy.sml", "-o", out ^ "/use-toy-listed.rbc"], out ^ "/listed.cerr") = 0
                  andalso same (out ^ "/use-toy-listed.rbc", out ^ "/use-toy.rbc") then ()
               else fail "lib.listed: a library's files listed by hand do not make the same bytecode"
      val _ = rune (["--library", "toy2", "--basis-deps", "tests/lib/use-toy2.sml"], out ^ "/deps.txt")
      val deps = lines (read (out ^ "/deps.txt"))
      fun at suffix = List.filter (fn (_, l) => String.isSuffix suffix l) (ListPair.zip (List.tabulate (length deps, fn i => i), deps))
      val () = case (at "toy/toy.sml", at "toy2/toy2.sml") of
                 ([(i, _)], [(j, _)]) =>
                   if i < j andalso not (List.exists (fn l => String.isSubstring "extra.sml" l) deps) then ()
                   else fail "lib.deps: --basis-deps lists the files out of order, or one it should not"
               | _ => fail "lib.deps: --basis-deps does not list each library's file once"
      val () = if rune (["--library", "toy", "--library", "toy2", "--basis-check"], out ^ "/check.txt") = 0 then ()
               else fail "lib.toy: --basis-check"
      val () = if rune (["--library", "prim", "tests/lib/use-prim.sml", "-o", out ^ "/use-prim.rbc"], out ^ "/prim.cerr") <> 0
                  andalso contains (out ^ "/prim.cerr", "_prim is only allowed") then ()
               else fail "lib.prim: a library may use _prim"
      val () = if rune (["--library", "cycle1", "tests/lib/use-toy.sml", "-o", out ^ "/cycle.rbc"], out ^ "/cycle.cerr") <> 0
                  andalso contains (out ^ "/cycle.cerr", "is written on itself") then ()
               else fail "lib.cycle: a library written on itself is no error"
    in
      if exec {cmd = ["bin/runedoc", "--lib", root', "--library", "toy2", "--out", out ^ "/toy2.site", "--title", "toy2"], dir = NONE,
               stdin = "", stdout = out ^ "/runedoc.log", stderr = out ^ "/runedoc.log", timeout = 0} = 0 then ()
      else fail "lib.runedoc: runedoc does not document a library written on another"
    end

  (* lib/random's known answers: tests/lib/random/reference.c's *)
  fun libRandomKat () =
    let
      val () = mkdirs libOut
      fun f x = libOut ^ "/" ^ x
    in
      if exec {cmd = [env ("CC", "cc"), "-O2", "-o", f "random-reference", "tests/lib/random/reference.c"], dir = NONE, stdin = "",
               stdout = f "random-cc.log", stderr = f "random-cc.log", timeout = 0} <> 0
         orelse exec {cmd = [f "random-reference"], dir = NONE, stdin = "", stdout = f "random-kat.expected", stderr = "", timeout = 0} <> 0
      then fail "lib.random-kat: the reference does not build or run"
      else
        case libProgram ("random-kat", ["--library", "random"], "tests/lib/random/kat.sml") of
          NONE => ()
        | SOME out => if same (out, f "random-kat.expected") then () else fail "lib.random-kat: the known answers differ"
    end

  fun libBasisCheck lib =
    let val log = libOut ^ "/" ^ String.translate (fn #"/" => "-" | c => str c) lib ^ "-check.txt"
    in
      mkdirs libOut;
      if exec {cmd = ["bin/rune", "--library", lib, "--basis-check"], dir = NONE, stdin = "", stdout = log, stderr = log, timeout = 0} = 0
      then () else fail ("lib." ^ lib ^ ": --basis-check (see " ^ log ^ ")")
    end

  (* the examples of a library's documentation: each signature's program
     must print PASS and no FAIL; with GUARDED, a library may have none *)
  fun libExamples (lib, guarded) =
    let
      val tag = String.translate (fn #"/" => "-" | c => str c) lib
      val ex = libOut ^ "/" ^ tag ^ "-examples"
      val () = (rmTree ex; mkdirs ex)
    in
      if exec {cmd = ["bin/runedoc", "--lib", "lib", "--library", lib, "--examples", ex], dir = NONE, stdin = "",
               stdout = ex ^ "/runedoc.log", stderr = ex ^ "/runedoc.log", timeout = 0} <> 0
      then fail ("lib." ^ lib ^ ": runedoc --examples failed: " ^ firstLine (ex ^ "/runedoc.log"))
      else
        case glob (ex, ".sml") of
          [] => if guarded then () else fail ("lib." ^ lib ^ ": its documentation has no examples")
        | fs =>
            List.app (fn src =>
                        let val p = String.substring (src, 0, size src - 4)
                        in
                          if exec {cmd = ["bin/rune", "--library", lib, src, "-o", p ^ ".rbc"], dir = NONE, stdin = "", stdout = p ^ ".cerr",
                                   stderr = p ^ ".cerr", timeout = 0} = 0
                             andalso (ignore (exec {cmd = ["bin/runevm", p ^ ".rbc"], dir = NONE, stdin = "", stdout = p ^ ".out",
                                                    stderr = p ^ ".out", timeout = 0}); passes (p ^ ".out"))
                          then ()
                          else fail ("lib." ^ lib ^ ": the examples of " ^ basename src ^ " (see " ^ p ^ ".out)")
                        end)
                     fs
    end

  (* Check.laws, and RUNE_PROPERTY_ONLY *)
  fun libLaws () =
    case libProgram ("property-laws", ["--library", "test/property/basis"], "tests/lib/property/laws.sml") of
      NONE => ()
    | SOME out =>
        let
          val ls = lines (read out)
          val only = libOut ^ "/property-laws-only.out"
          val () = ignore (exec {cmd = ["/bin/sh", "-c", "RUNE_PROPERTY_ONLY=TEST.nth/law-1@List exec bin/runevm " ^ libOut ^ "/property-laws.rbc"],
                                 dir = NONE, stdin = "", stdout = only, stderr = only, timeout = 0})
        in
          if length (List.filter (fn l => String.isPrefix "LAW " l) ls) = 2 andalso hasLine (out, "laws: 2 pass, 0 fail")
             andalso hasLine (only, "laws: 1 pass, 0 fail") andalso hasLine (only, "PASS TEST.nth")
          then () else fail "lib.property-laws: Check.laws"
        end

  (* a test of a library of docs/plans/repl.md, run from the root *)
  fun libSuite (lib, src) =
    let
      val first = case String.fields (fn c => c = #"\n") (read src) of l :: _ => l | [] => ""
      val extras = if String.isPrefix "(* libraries: " first andalso String.isSuffix " *)" first
                   then List.concat (List.map (fn l => ["--library", l])
                                              (String.tokens Char.isSpace (String.substring (first, 14, size first - 17))))
                   else []
    in libCheck ("passes", lib ^ "-" ^ basename src, ["--library", lib] @ extras, src) end

  fun libInterop lib =
    let val log = libOut ^ "/" ^ lib ^ "-interop.txt"
    in
      mkdirs libOut;
      if exec {cmd = [fromRoot "bin/rune-protocol-check", "interop", lib, fromRoot "bin/rune", fromRoot "bin/runevm", libOut ^ "/" ^ lib ^ "-interop"], dir = NONE,
               stdin = "", stdout = log, stderr = log, timeout = 0} = 0
      then () else fail ("lib." ^ lib ^ ": the interop (see " ^ log ^ ")")
    end

  (* ---- tests/flexrec *)
  val flexModes =
    [("binding", [0, 0, 0, 0, 0]), ("declaration", [1, 0, 0, 0, 0]), ("topdec-monomorphic", [1, 1, 1, 2, 0]),
     ("topdec", [1, 1, 1, 1, 0]), ("program", [1, 1, 1, 1, 1])]
  val flexPrograms = ["same_let", "next_dec", "in_structure", "two_types", "after_semicolon"]

  fun flexrecOne (mode, p, how) =
    let
      val out = run ^ "/flexrec"
      val () = mkdirs out
      val want = case List.find (fn (m, _) => m = mode) flexModes of
                   SOME (_, ws) => (case List.find (fn (q, _) => q = p) (ListPair.zip (flexPrograms, ws)) of
                                      SOME (_, w) => w | NONE => ~1)
                 | NONE => ~1
      (* the bytecode of each build its own: two jobs may run at once *)
      val rbc = out ^ "/" ^ p ^ "." ^ mode ^ "." ^ how ^ ".rbc"
      val err = out ^ "/" ^ p ^ "." ^ mode ^ "." ^ how ^ ".err"
      val code = exec {cmd = ["bin/rune", "--flex-records=" ^ mode] @ (if how = "units" then ["--units", "--no-cache"] else [])
                             @ ["tests/flexrec/" ^ p ^ ".sml", "-o", rbc], dir = NONE, stdin = "", stdout = err, stderr = err, timeout = 0}
      val name = "flexrec." ^ mode ^ "." ^ p ^ " (" ^ how ^ ")"
    in
      case want of
        1 =>
          if code <> 0 then fail (name ^ ": refused: " ^ firstLine err)
          else
            let
              val printed = rbc ^ ".out"
              val _ = exec {cmd = ["bin/runevm", rbc], dir = NONE, stdin = "", stdout = printed, stderr = "", timeout = 0}
              val got = String.concatWith "\n" (lines (read printed))
            in if got = (if p = "two_types" then "1two" else "1") then () else fail (name ^ ": printed " ^ got) end
      | w =>
          let val reason = if w = 2 then "type mismatch" else "unresolved flexible record"
          in if code <> 0 andalso contains (err, reason) then () else fail (name ^ ": not refused with " ^ reason) end
    end

  fun flexrecRepl p =
    let
      val out = run ^ "/flexrec"
      val () = mkdirs out
      val f = out ^ "/" ^ p ^ ".repl"
      val () = write (out ^ "/" ^ p ^ ".in", "use \"tests/flexrec/" ^ p ^ ".sml\";\n")
      val _ = exec {cmd = ["/bin/sh", "-c", "RUNE_CACHE= exec bin/rune-repl --no-init"], dir = NONE, stdin = out ^ "/" ^ p ^ ".in",
                    stdout = f, stderr = f, timeout = 120}
      val ls = lines (read f)
      val ok =
        if p = "after_semicolon" then contains (f, "unresolved flexible record")
        else List.exists (fn l => String.isSuffix "1" l orelse String.isSuffix "1two" l) ls
             andalso not (List.exists (fn l => String.isSubstring "error" l) ls)
    in if ok then () else fail ("flexrec.repl." ^ p) end

  (* ---- tests/compiler: the compiler's output and its budgets *)
  fun compilerProtection rune =
    let
      val dir = run ^ "/compiler/" ^ String.translate (fn #"/" => "_" | c => str c) rune
      val () = (rmTree dir; mkdirs dir)
      fun f x = dir ^ "/" ^ x
      fun r (args, limit) =
        exec {cmd = ["/bin/sh", "-c", (case limit of SOME n => "ulimit -f " ^ Int.toString n ^ "; " | NONE => "")
                                       ^ "ulimit -c 0; exec \"$0\" \"$@\"", fromRoot rune] @ args,
              dir = SOME dir, stdin = "", stdout = f "out", stderr = f "err", timeout = 60}
      fun check (what, ok) = if ok then () else fail ("compiler." ^ what)
      val () = write (f "input.sml", "val _ = print \"42\\n\"\n")
      val () = write (f "second.sml", "val answer = 42\n")
      val input = read (f "input.sml") and second = read (f "second.sml")
      fun refusedSame dest =
        r (["-o", dest, "input.sml", "second.sml"], NONE) <> 0 andalso contains (f "err", "output must differ")
        andalso read (f "input.sml") = input andalso read (f "second.sml") = second
      val () = check ("overlap", List.all refusedSame ["input.sml", dir ^ "/./input.sml", "second.sml"])
      val () = Posix.FileSys.symlink {old = f "input.sml", new = f "alias.sml"}
      val () = Posix.FileSys.link {old = f "input.sml", new = f "hard.sml"}
      val () = check ("aliases", List.all (fn a => r (["-o", a, "input.sml"], NONE) <> 0 andalso contains (f "err", "output must differ")
                                                   andalso read (f "input.sml") = input) ["alias.sml", "hard.sml"])
      (* atomic output: a file the size limit stops, or a compile that fails,
         leaves the old file *)
      val () = OS.FileSys.remove (f "alias.sml")
      val () = OS.FileSys.remove (f "hard.sml")
      val () = write (f "output.rbc", "previous bytecode")
      val () = write (f "input.sml", "val _ = print \"" ^ CharVector.tabulate (8192, fn _ => #"x") ^ "\"")
      val () = check ("atomic: limited", r (["-o", "output.rbc", "input.sml"], SOME 1) <> 0 andalso read (f "output.rbc") = "previous bytecode")
      val () = check ("atomic: written", r (["-o", "output.rbc", "input.sml"], NONE) = 0 andalso String.isPrefix "RUNE" (read (f "output.rbc")))
      val written = read (f "output.rbc")
      val () = write (f "input.sml", "val x = missingName")
      val () = check ("atomic: failed", r (["-o", "output.rbc", "input.sml"], NONE) <> 0 andalso read (f "output.rbc") = written)
      val () = check ("budgets: arguments",
                      List.all (fn flag => List.all (fn bad => r ([flag ^ "=" ^ bad, "input.sml"], NONE) <> 0
                                                               andalso contains (f "err", "requires a positive integer"))
                                                    ["", "0", "-1", "+1", "1x", "1.5", "999999999999999999999999"])
                               ["--type-work", "--match-work"])
      val () = write (f "input.sml", "val f = fn true => 1 | false => 2")
      fun tc flag = r (["--no-prelude", "--typecheck-only", flag, "input.sml"], NONE)
      val () = check ("budgets: match", tc "--match-work=1" <> 0 andalso contains (f "err", "match analysis exceeds 1 steps")
                                        andalso tc "--match-work=1000" = 0)
      val () = check ("budgets: type", tc "--type-work=1" <> 0 andalso contains (f "err", "type inference exceeds 1 steps")
                                       andalso tc "--type-work=10000" = 0)
      (* f applied n times: MLton's regression exponential, a type of 2^n
         nodes as a tree *)
      fun applied n = "fun f x = x\nfun g y = " ^ String.concat (List.tabulate (n, fn _ => "f ")) ^ "y\nval _ = g 3\n"
      (* types shared while inferred and, hash-consed, once translated: at
         32 applications some 300 steps of inference and 6400 of
         translation *)
      val () = write (f "input.sml", applied 32)
      val () =
        check ("budgets: shared types",
               r (["--no-prelude", "--typecheck-only", "--type-work=1000", "input.sml"], NONE) = 0
               andalso r (["--no-prelude", "--type-work=20000", "-o", "output.rbc", "input.sml"], NONE) = 0)
      (* the translation has a budget of its own, a step for each node of
         each type it converts, and of a big type each shared node once: at
         128 applications some 1200 steps of inference and 32000 of
         translation *)
      val () = write (f "input.sml", applied 128)
      val () =
        check ("budgets: translation",
               r (["--no-prelude", "--type-work=4000", "-o", "output.rbc", "input.sml"], NONE) <> 0
               andalso contains (f "err", "type translation exceeds 4000 steps")
               andalso r (["--no-prelude", "--type-work=100000", "-o", "output.rbc", "input.sml"], NONE) = 0)
      (* --pass-stats=elab: a line for each top-level declaration, its time by
         context and operation adding up to its total, and its counters, which
         do not depend on the machine (docs/ir.md, The elaborator's counters) *)
      val () = write (f "input.sml", "signature A = sig type t val x : t end\n"
                                     ^ "signature B = sig structure P : A structure Q : A sharing P = Q\n"
                                     ^ "  type u sharing type u = P.t end where type u = int\n"
                                     ^ "functor F (X : A) = struct val y = X.x datatype d = D of X.t end\n"
                                     ^ "functor G (Y : A) = struct structure S = F (Y) val z = S.y end\n"
                                     ^ "structure M = struct type t = int val x = 3 end\n"
                                     ^ "structure N = G (M)\n"
                                     ^ "val v = N.z + 1\n")
      val () = check ("pass-stats=elab: compiled",
                      r (["--no-prelude", "--typecheck-only", "--pass-stats=elab", "input.sml"], NONE) = 0)
      val elab = List.map (String.tokens Char.isSpace) (List.filter (String.isPrefix "elab ") (lines (read (f "err"))))
      fun fieldsOf l = List.mapPartial (fn w => case String.fields (fn c => c = #"=") w of [k, v] => SOME (k, v) | _ => NONE)
                                       (if length l > 4 then List.drop (l, 4) else [])
      (* input.sml's declarations, each by its first line and with the
         counters of its last *)
      val mine = List.mapPartial (fn _ :: at :: kind :: name :: _ =>
                                       if String.isPrefix "input.sml:" at then SOME (kind ^ " " ^ name) else NONE
                                   | _ => NONE) elab
      val names = List.foldl (fn (n, ns) => if List.exists (fn x => x = n) ns then ns else ns @ [n]) [] mine
      fun counters name =
        case List.filter (fn _ :: at :: kind :: n :: _ => String.isPrefix "input.sml:" at andalso kind ^ " " ^ n = name
                           | _ => false) elab of
          [] => []
        | ls => fieldsOf (List.last ls)
      fun get name k = Option.map #2 (List.find (fn (k', _) => k' = k) (counters name))
      fun number v = getOpt (IntInf.fromString v, ~1)
      fun adds l =
        let
          val fs = fieldsOf l
          val cells = List.foldl (fn ((k, v), s) =>
                                     case String.fields (fn c => c = #".") k of
                                       context :: _ :: _ =>
                                         if List.exists (fn c => c = context) ["top", "fundecl", "appcode", "appcheck"]
                                         then s + number v else s
                                     | _ => s) 0 fs
        in
          case List.find (fn (k, _) => k = "total") fs of SOME (_, t) => number t = cells | NONE => false
        end
      val () = check ("pass-stats=elab: the declarations",
                      names = ["signature A", "signature B", "functor F", "functor G", "structure M", "structure N", "core -"])
      val () = check ("pass-stats=elab: the deferred line last",
                      case List.rev elab of (_ :: a :: b :: c :: _) :: _ => [a, b, c] = ["-", "deferred", "-"] | _ => false)
      val () = check ("pass-stats=elab: the times add up", List.all adds elab)
      val () = check ("pass-stats=elab: signature B",
                      List.map (get "signature B") ["share.types", "share.structures", "where", "inst"]
                      = [SOME "2", SOME "1", SOME "1", SOME "2"])
      val () = check ("pass-stats=elab: functor G",
                      List.map (get "functor G") ["fundecl", "app.check", "app.code", "match"] = [SOME "1", SOME "1", NONE, SOME "1"])
      val () = check ("pass-stats=elab: structure N",
                      List.map (get "structure N") ["app.code", "app.depth", "app.check"] = [SOME "2", SOME "2", NONE])
      val () = check ("pass-stats=elab: another kind refused",
                      r (["--no-prelude", "--typecheck-only", "--pass-stats=types", "input.sml"], NONE) <> 0
                      andalso contains (f "err", "--pass-stats= requires elab"))
      (* --pass-stats accounts for the whole compile (docs/plans/performance.md, M1):
         a line `pass NAME: N nodes, T s` per stage, then
         `total: T s processor time, S s in the stages (P%)`, the process's
         processor time from its start and the sum of the outermost stages.
         The stages must add up to the total, to within the rounding of the
         lines and a share of the total that the host's clock needs, and the
         process must have taken no more than the total, but for what the VM
         does after the last line (it exits). A piece of the compile that no
         stage times shows here. The share is 2%, and 15% on SML/NJ's
         builds, whose processor time counts the collector's twice (its
         Timer.checkCPUTimer adds the collector's time to a user time that
         holds it already): a total may be more than what the process took,
         and a minor collection in the driver's code, between two stages, is
         a gap -- on SML/NJ 110.99.9 1 to 5% of this compile on a quiet
         machine and up to 10% at a load of 30 to 40, under 1% with an
         allocation area of 4 MB. A gap cannot be more than the time counted
         twice, the collector's, 14 to 17% of SML/NJ's total here; the other
         hosts, which compile the same code, hold every stage to 2%. A share,
         not a fixed margin: a loaded machine makes the compile longer. *)
      fun children () = let val {cutime, cstime, ...} = Posix.ProcEnv.times () in Time.toReal (Time.+ (cutime, cstime)) end
      fun split sep s =
        let val (a, b) = Substring.position sep (Substring.full s)
        in if Substring.isEmpty b then NONE else SOME (Substring.string a, Substring.string (Substring.triml (size sep) b)) end
      fun stage l =
        case split ": " l of
          SOME (name, rest) =>
            (case split ", " rest of
               SOME (nodes, secs) =>
                 if String.isPrefix "pass " name andalso String.isSuffix " nodes" nodes andalso String.isSuffix " s" secs
                    andalso not (String.isSubstring ", " secs)
                 then Option.map (fn t => (String.extract (name, 5, NONE), t)) (Real.fromString (String.substring (secs, 0, size secs - 2)))
                 else NONE
             | NONE => NONE)
        | NONE => NONE
      val start = children ()
      val code = r (["--target=stack", "--pass-stats", "-o", "sigs.rbc", fromRoot "tests/perf/compile-sigs.sml"], NONE)
      val process = children () - start
      val ls = lines (read (f "err"))
      val stages = List.mapPartial stage (if null ls then [] else List.take (ls, length ls - 1))
      val names = List.map #1 stages
      val added = List.foldl (fn ((_, t), s) => s + t) 0.0 stages
      val n = real (length stages)
      val (total, inside) =
        case (if null ls then [] else String.tokens Char.isSpace (List.last ls)) of
          "total:" :: t :: "s" :: "processor" :: "time," :: i :: _ => (Real.fromString t, Real.fromString i)
        | _ => (NONE, NONE)
    in
      check ("pass-stats: compiled", code = 0);
      check ("pass-stats: a stage per line", length stages = length ls - 1);
      check ("pass-stats: the stages",
             List.all (fn w => List.exists (fn x => x = w) names)
                      ["startup", "lex", "select", "parse", "elaborate", "translate", "mid", "midcanon", "lower", "stack", "emit",
                       "stats"]);
      check ("pass-stats: no stage below zero", List.all (fn (_, t) => t >= 0.0) stages);
      case (total, inside) of
        (SOME total, SOME inside) =>
          (check ("pass-stats: the stages add up to the line", Real.abs (added - inside) <= 0.0005 * n + 0.001);
           check ("pass-stats: the stages add up to the compile",
                  total - added <= 0.001 * n + (if String.isSubstring "smlnj" rune then 0.15 else 0.02) * total);
           check ("pass-stats: the process took no more than the total", process <= 1.10 * total + 0.05))
      | _ => check ("pass-stats: the last line is the total", false)
    end

  (* ---- tests/runtime: limits saved with an image and stricter on restore *)
  fun limits (rune, vm) =
    let
      val dir = run ^ "/limits/" ^ String.translate (fn #"/" => "_" | c => str c) vm
      val () = (rmTree dir; mkdirs dir)
      fun f x = dir ^ "/" ^ x
      fun vmRun args = exec {cmd = [vm] @ args, dir = SOME dir, stdin = "", stdout = f "out", stderr = f "err", timeout = 60}
      fun compile src = (write (f "limits.sml", src);
                         exec {cmd = [fromRoot rune, "-o", f "limits.rbc", f "limits.sml"], dir = SOME dir, stdin = "",
                               stdout = f "cerr", stderr = f "cerr", timeout = 60} = 0)
      fun check (what, ok) = if ok then () else fail ("limits." ^ what ^ ": " ^ firstLine (f "err"))
      val img = f "limits.img"
      val prog1 = String.concatWith "\n"
        ["datatype tree = Leaf | Node of tree * tree",
         "fun make 0 = Leaf | make n = let val t = make (n - 1) in Node (t, t) end",
         "val left = make 4",
         "val right = make 4",
         "val phase = Runtime.save \"" ^ img ^ "\"",
         "val () = case phase of Runtime.Saved => print \"saved\\n\"",
         "                    | Runtime.Restored => print (Bool.toString (left = right) ^ \"\\n\")", ""]
    in
      if not (compile prog1) then fail ("limits: does not compile: " ^ firstLine (f "cerr"))
      else
        List.app (fn (budget, status) =>
                    (check ("save at " ^ Int.toString budget, vmRun ["--equality-work", Int.toString budget, f "limits.rbc"] = 0
                                                             andalso read (f "out") = "saved\n");
                     let val code = vmRun ["--restore", img]
                     in
                       if status = 2 then check ("restore at " ^ Int.toString budget,
                                                 code = 2 andalso String.isPrefix "runevm: equality work limit exceeded\n" (read (f "err")))
                       else (check ("restore at " ^ Int.toString budget, code = 0 andalso read (f "out") = "true\n");
                             check ("restore, stricter", vmRun ["--equality-work", "1", "--restore", img] = 2
                                                         andalso contains (f "err", "equality work limit exceeded")))
                     end))
                 [(10, 2), (1000, 0)];
      if not (compile (String.concatWith "\n"
                         ["val phase = Runtime.save \"" ^ img ^ "\"",
                          "val xs = List.tabulate (100, fn i => i)",
                          "val () = Runtime.collect ()",
                          "val () = print ((if #heapSize (Runtime.stats ()) <= 65536 then \"limited:\" else \"unlimited:\")",
                          "                ^ Int.toString (List.length xs) ^ \"\\n\")", ""]))
      then fail ("limits: the second program does not compile: " ^ firstLine (f "cerr"))
      else
        (check ("heap limit kept", vmRun ["--heap-limit", "65536", "--heap-fill", "1", f "limits.rbc"] = 0
                                   andalso read (f "out") = "limited:100\n");
         check ("heap limit restored", vmRun ["--restore", img] = 0 andalso read (f "out") = "limited:100\n");
         check ("heap limit stricter", vmRun ["--heap-limit", "4096", "--restore", img] = 2 andalso contains (f "err", "heap limit exceeded")))
    end

  (* ---- tests/runtime: the collector's log, a line for each collection *)
  val gcColumns = String.tokens Char.isSpace
    "seq kind vmgc bytes objects instrs boxes box_bytes used_before copied copied_objs promoted slots live_slots frames other_roots cards_dirty cards_scanned remembered live_after heap_size pause_ns cpu_ns rss_bytes t_ns cards_young fields_scanned"

  fun gcLog (rune, vm) =
    let
      val dir = run ^ "/gc-log/" ^ String.translate (fn #"/" => "_" | c => str c) vm
      val () = (rmTree dir; mkdirs dir)
      fun f x = dir ^ "/" ^ x
      fun vmRun (args, n) = exec {cmd = [vm] @ args, dir = NONE, stdin = "", stdout = f (n ^ ".out"), stderr = f (n ^ ".err"), timeout = 120}
      exception Bad of string
      fun need (ok, what) = if ok then () else raise Bad what
      fun ints s = List.mapPartial Int.fromString (String.tokens (fn c => not (Char.isDigit c)) s)
      (* the numbers after a text in a file, as the test's regular expressions find them *)
      fun after (file, text) =
        case List.find (fn l => String.isSubstring text l) (lines (read file)) of
          SOME l => ints (Substring.string (Substring.triml (size text) (#2 (Substring.position text (Substring.full l)))))
        | NONE => raise Bad ("no line with " ^ text ^ " in " ^ file)
      fun count file = case after (file, "runevm: count: ") of i :: b :: ob :: _ => (i, b, ob) | _ => raise Bad "no count"
      (* runevm: N collections, anywhere *)
      fun collections file =
        let
          fun scan s =
            if Substring.isEmpty s then NONE
            else
              let val (_, rest) = Substring.position "runevm: " s
              in
                if Substring.isEmpty rest then NONE
                else
                  let
                    val rest = Substring.triml (size "runevm: ") rest
                    val (digits, tail) = Substring.splitl Char.isDigit rest
                  in
                    if not (Substring.isEmpty digits) andalso Substring.isPrefix " collections" tail
                    then Int.fromString (Substring.string digits) else scan rest
                  end
              end
        in
          case scan (Substring.full (read file)) of
            SOME n => n
          | NONE => raise Bad ("no count of collections in " ^ file)
        end
      fun rows ls = List.map (String.tokens Char.isSpace) (List.filter (fn l => not (String.isPrefix "#" l)) (List.drop (ls, 2)))
      fun col (row, name) =
        let fun go (c :: cs, x :: xs) = if c = name then x else go (cs, xs) | go _ = raise Bad ("no " ^ name)
        in go (gcColumns, row) end
      fun num (row, name) = case Int.fromString (col (row, name)) of SOME n => n | NONE => raise Bad (name ^ " is no number")
      val src = String.concatWith "\n"
        ["fun build 0 acc = acc | build n acc = build (n - 1) (n :: acc)",
         "fun loop 0 keep = keep",
         "  | loop k keep = loop (k - 1) (List.length (build 2000 []) :: build 20 keep)",
         "val kept = loop 300 []",
         "val () = print (Int.toString (List.foldl op+ 0 kept) ^ \"\\n\")", ""]
      val () = write (f "gclog.sml", src)
      fun check () =
        let
          val () = need (exec {cmd = [rune, "-o", f "gclog.rbc", f "gclog.sml"], dir = NONE, stdin = "", stdout = f "cerr",
                               stderr = f "cerr", timeout = 60} = 0, "does not compile: " ^ firstLine (f "cerr"))
          val () = need (vmRun (["--count", "--nursery", "0", "--heap-size", "65536", f "gclog.rbc"], "plain") = 0
                         andalso vmRun (["--count", "--stats", "--nursery", "0", "--heap-size", "65536", "--gc-log", f "gclog.log",
                                         f "gclog.rbc"], "logged") = 0, "a run failed: " ^ firstLine (f "logged.err"))
          val () = need (same (f "plain.out", f "logged.out"), "the log changed the output")
          val c = count (f "plain.err")
          val () = need (count (f "logged.err") = c, "the log changed --count")
          val n = collections (f "logged.err")
          val ls = String.fields (fn ch => ch = #"\n") (read (f "gclog.log"))
          val ls = case rev ls of "" :: rest => rev rest | _ => ls
          val () = need (hd ls = "# rune-gc-log 1 nursery=0 heap=65536 fill=50 limit=0", "the log's first line: " ^ hd ls)
          val () = need (String.tokens Char.isSpace (List.nth (ls, 1)) = "#" :: gcColumns, "the log's columns")
          val rs = rows ls
          val () = need (length rs = n andalso n > 1, "the rows are not the collections")
          fun each (_, [], _) = ()
            | each (seq, r :: rest, prev) =
                (need (length r = length gcColumns andalso col (r, "kind") = "full", "a row: " ^ String.concatWith " " r);
                 need (num (r, "seq") = seq, "a row's seq");
                 need (num (r, "copied") = num (r, "live_after") andalso num (r, "live_after") <= num (r, "heap_size"), "copied, live_after, heap_size");
                 need (num (r, "live_slots") <= num (r, "slots") andalso num (r, "pause_ns") >= 0, "slots, pause_ns");
                 need (List.all (fn k => num (r, k) = 0) ["promoted", "cards_dirty", "cards_scanned", "remembered"], "a full pass promoted");
                 case prev of
                   SOME p => need (List.all (fn k => num (r, k) >= num (p, k)) ["vmgc", "bytes", "objects", "instrs", "t_ns"], "a row went back")
                 | NONE => ();
                 each (seq + 1, rest, SOME r))
          val () = each (1, rs, NONE)
          val () = need (num (hd rs, "vmgc") = 1, "the first row's vmgc")
          val () = need (num (List.last rs, "vmgc") < length rs, "no collection grew the heap in two passes")
          val endLine = List.nth (ls, length ls - 2)
          val () = need (String.isPrefix "# end bytes " endLine, "the end line: " ^ endLine)
          val () = case ints endLine of
                     b :: ob :: i :: _ :: _ :: cs :: _ => need ((i, b, ob) = c andalso cs = n, "the end line's counts")
                   | _ => raise Bad "the end line"
          val () = need (String.isPrefix "# wall_ns " (List.last ls), "the last line")
          (* with a nursery *)
          val () = need (vmRun (["--count", "--stats", "--nursery", "16384", "--nursery-max", "0", "--heap-size", "65536", "--gc-log",
                                 f "nursery.log", f "gclog.rbc"], "nursery") = 0, "the nursery's run failed")
          val () = need (same (f "plain.out", f "nursery.out"), "the nursery changed the output")
          val () = need (count (f "nursery.err") = c, "the nursery changed --count")
          val n2 = collections (f "nursery.err")
          val (minors, fulls, promoted) =
            case after (f "nursery.err", "runevm: nursery 16384 bytes: ") of m :: fu :: p :: _ => (m, fu, p) | _ => raise Bad "no nursery line"
          val ls2 = String.fields (fn ch => ch = #"\n") (read (f "nursery.log"))
          val ls2 = case rev ls2 of "" :: rest => rev rest | _ => ls2
          val () = need (hd ls2 = "# rune-gc-log 1 nursery=16384 heap=65536 fill=50 limit=0", "the nursery log's first line")
          val rs2 = rows ls2
          val () = need (length rs2 = n2 andalso n2 = minors + fulls andalso minors > 1 andalso fulls > 1, "minor and full passes")
          val () = need (List.foldl (fn (r, s) => s + num (r, "promoted")) 0 rs2 = promoted andalso promoted > 0, "promoted")
          val () = List.app (fn (seq, r) =>
                               (need (num (r, "seq") = seq, "a nursery row's seq");
                                if col (r, "kind") = "minor" then
                                  (need (num (r, "copied") = num (r, "promoted") andalso num (r, "promoted") <= num (r, "used_before"), "a minor pass's copy");
                                   need (num (r, "cards_dirty") <= num (r, "cards_scanned") andalso num (r, "cards_young") <= num (r, "cards_dirty"), "cards"))
                                else need (col (r, "kind") = "full" andalso num (r, "promoted") = 0 andalso num (r, "copied") <= num (r, "live_after"),
                                           "a full pass in the nursery's log")))
                            (ListPair.zip (List.tabulate (length rs2, fn i => i + 1), rs2))
        in
          need (vmRun (["--gc-log", dir, f "gclog.rbc"], "refused") = 2 andalso contains (f "refused.err", "--gc-log")
                andalso read (f "refused.out") = "", "an unwritable log is not refused")
        end
    in
      check () handle Bad m => fail ("gc-log " ^ vm ^ ": " ^ m)
    end

  (* ---- the palette: compile the test with the palette it measures *)
  fun contrast planted =
    let
      val dir = run ^ (if planted then "/colour/fault" else "/colour/contrast")
      val () = mkdirs dir
      val log = dir ^ "/compile.err"
      val fault = dir ^ "/fault.sml"
      val () = if planted then write (fault,
        "structure Color = struct\n  open Color\n"
        ^ "  val table = map (fn (\"error\", _, d, l) => (\"error\", \"30\", d, l) | row => row) table\nend\n") else ()
      val sources = ["lib/compiler/util/color.sml"] @ (if planted then [fault] else []) @ ["tests/color/contrast.sml"]
    in
      if exec {cmd = ["bin/rune", "--library", "json"] @ sources @ ["-o", dir ^ "/contrast.rbc"],
               dir = NONE, stdin = "", stdout = log, stderr = log, timeout = 120} <> 0
      then fail ("colour: does not compile: " ^ firstLine log)
      else
        let val status = exec {cmd = ["bin/runevm", dir ^ "/contrast.rbc"], dir = NONE, stdin = "", stdout = dir ^ "/output",
                               stderr = dir ^ "/error", timeout = 120}
        in
          if planted then
            if status = 1 andalso String.isSubstring "FAIL auto" (read (dir ^ "/output")) then ()
            else fail "colour: black text on a black background did not fail its contrast check"
          else if status = 0 then ()
          else fail ("colour: " ^ read (dir ^ "/output") ^ read (dir ^ "/error"))
        end
    end

  (* The foundational build-file generator is called by separate makes.
     They must be able to publish identical files at once. Each round
     starts eight generators before waiting for any of them. *)
  fun generators script =
    let
      val dir = run ^ "/generators"
      val () = (rmTree dir; mkdirs (dir ^ "/scripts"))
      val programs = [("rune", "polyml-build.sml"), ("runedoc", "runedoc-polyml-build.sml"),
                      ("runeopt", "runeopt-polyml-build.sml"), ("runeisa", "runeisa-polyml-build.sml"),
                      ("runeffi", "runeffi-polyml-build.sml")]
      val () = List.app (fn n => (mkdirs (OS.Path.dir (dir ^ "/" ^ n));
                                  write (dir ^ "/" ^ n, read (fromRoot n))))
                         (List.map (fn (name, _) => name ^ ".build") programs @
                          ["lib/compiler/internal.build", "lib/compiler/frontend.build", "lib/compiler/util.build"])
      val () = write (dir ^ "/scripts/build-files.sh", read (fromRoot "scripts/build-files.sh"))
      val script = fromRoot script
      val log = dir ^ "/reference.log"
      val reference = exec {cmd = ["/bin/sh", script, dir], dir = SOME dir, stdin = "", stdout = log, stderr = log, timeout = 60}
      val wanted = sort (List.concat (List.map (fn (name, polyml) =>
        [name ^ ".mlb", name ^ ".cm", polyml, name ^ "-mlkit.mlb"]) programs))
      val actual = sort (entries (dir ^ "/build"))
      val expected = List.map (fn n => (n, read (dir ^ "/build/" ^ n))) wanted
      val null = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
      fun number fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
      fun round r =
        let
          fun start i =
            let
              val log = dir ^ "/" ^ Int.toString r ^ "-" ^ Int.toString i ^ ".log"
              val out = Posix.FileSys.creat (log, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
              val pid = Subprocess.spawn {program = "/bin/sh", args = ["sh", script, dir], env = NONE, search = false,
                (* Keep writers in the job's group so the supervisor can
                   stop every writer if this regression times out. *)
                dir = SOME dir, stdin = SOME (number null), stdout = SOME (number out), stderr = SOME (number out), group = false,
                limits = {addressSpace = SOME (64 * 1024 * 1024), cpuTime = SOME 30, fileSize = SOME (1024 * 1024), core = SOME 0}}
              val () = Posix.IO.close out
            in (pid, log) end
          val children = List.tabulate (8, start)
          val () = List.app (fn (pid, log) =>
            case #status (Subprocess.wait (SOME pid)) of
              Posix.Process.W_EXITED => ()
            | _ => fail ("build generators: concurrent invocation failed: " ^ firstLine log)) children
        in
          List.app (fn (n, text) => if exists (dir ^ "/build/" ^ n) andalso read (dir ^ "/build/" ^ n) = text then ()
                    else fail ("build generators: changed " ^ n)) expected
        end
    in
      if reference <> 0 then fail ("build generators: reference generation: " ^ firstLine log)
      else if actual <> wanted orelse List.exists (fn (_, text) => text = "") expected then
        fail "build generators: incomplete program/host output matrix"
      else List.app round [1, 2, 3, 4];
      Posix.IO.close null
    end

  (* ---- the tree *)
  fun job (path, args, after, memory, timeout) =
    Test.it path
      {program = "/bin/sh",
       args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = memory,
       pools = [], exclusive = false, after = after, judge = failLines} : Run.command Test.tree

  fun command args =
    case args of
      ["ir-one", src] => SOME (fn () => irOne src)
    | ["doc-one", n] => SOME (fn () => docOne n)
    | ["doc-lib", n] => SOME (fn () => docLib n)
    | ["doc-overview"] => SOME docOverview
    | ["lib-toy"] => SOME libToy
    | ["lib-random-kat"] => SOME libRandomKat
    | ["lib-check", kind, n, lib, src] => SOME (fn () => libCheck (kind, n, ["--library", lib], src))
    | ["lib-basis-check", lib] => SOME (fn () => libBasisCheck lib)
    | ["lib-examples", lib, guarded] => SOME (fn () => libExamples (lib, guarded = "guarded"))
    | ["lib-laws"] => SOME libLaws
    | ["lib-suite", lib, src] => SOME (fn () => libSuite (lib, src))
    | ["lib-interop", lib] => SOME (fn () => libInterop lib)
    | ["flexrec-one", mode, p, how] => SOME (fn () => flexrecOne (mode, p, how))
    | ["flexrec-repl", p] => SOME (fn () => flexrecRepl p)
    | ["compiler", rune] => SOME (fn () => compilerProtection rune)
    | ["limits", rune, vm] => SOME (fn () => limits (rune, vm))
    | ["gc-log", rune, vm] => SOME (fn () => gcLog (rune, vm))
    | ["colour-contrast"] => SOME (fn () => contrast false)
    | ["colour-contrast-fault"] => SOME (fn () => contrast true)
    | ["build-generators"] => SOME (fn () => generators "scripts/gen-build-files.sh")
    | ["build-generators", script] => SOME (fn () => generators script)
    | _ => NONE

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val replLibs = ["unicode", "json", "terminal", "digest", "jsonrpc", "dap", "pretty", "markdown", "zmtp", "jupyter", "lsp", "language/c", "ffi/model", "ffi/marshal", "ffi/runtime", "ffi/win32/common"]
  val native = case OS.Process.getEnv "NATIVE_HOST" of SOME v => v = "yes" | NONE => exists "bin/runevm-native"

  val tree =
    Test.describe ""
      [tagged ["check", "quick"]
         (Test.resources {cpus = 2, memory = 256} (job ("compiler/build-generators", ["build-generators"], [], 256, 120))),
       tagged ["check", "test-diagnostics", "covers:tests/color/*"]
         (Test.describe "colour" [job ("contrast", ["colour-contrast"], [], 300, 300),
                                  job ("planted-fault", ["colour-contrast-fault"], [], 300, 300)]),
       tagged ["check", "test-ir", "covers:tests/ir/*"]
         (Test.describe "ir" (List.map (fn s => job (basename s, ["ir-one", s], [], 300, 600))
                                       (glob ("tests/ir", ".sml") @ glob ("tests/ir", ".mid")))),
       tagged ["check", "test-doc", "quick", "docs", "covers:tests/doc/*"]
         (Test.describe "doc"
            (job ("overview", ["doc-overview"], [], 300, 600)
             :: List.map (fn s => job (basename s, ["doc-one", basename s], [], 300, 600)) (glob ("tests/doc", ".sml"))
             @ List.map (fn d => let val n = String.substring (d, 0, size d - 4)
                                 in job (d, ["doc-lib", n], [], 300, 600) end)
                        (List.filter (fn d => String.isSuffix ".lib" d andalso isDir ("tests/doc/" ^ d)) (sort (entries "tests/doc"))))),
       tagged ["check", "test-lib", "quick", "covers:tests/lib/*", "covers:lib/random/*", "covers:lib/test/property/*"]
         (Test.describe "lib"
            ([job ("toy", ["lib-toy"], [], 300, 600),
              Test.requires ["cc"] (job ("random-kat", ["lib-random-kat"], [], 300, 600)),
              job ("random-props", ["lib-check", "nofail", "random-props", "test/unit", "tests/lib/random/props.sml"], [], 300, 600),
              job ("random-check", ["lib-basis-check", "random"], [], 300, 600),
              job ("random-examples", ["lib-examples", "random", "unguarded"], [], 300, 600),
              job ("property-core", ["lib-check", "fingerprint", "property-core", "test/property/basis", "tests/lib/property/core.sml"], [], 300, 600),
              job ("property-shrink", ["lib-check", "passes", "property-shrink", "test/property/basis", "tests/lib/property/shrink.sml"], [], 300, 600),
              job ("property-instances", ["lib-check", "frozen", "property-instances", "test/property/basis", "tests/lib/property/instances.sml"], [], 300, 600),
              job ("property-mutants", ["lib-check", "mutants", "property-mutants", "test/property/basis", "tests/lib/property/mutants.sml"], [], 300, 600),
              job ("property-laws", ["lib-laws"], [], 300, 600),
              job ("unit-core", ["lib-check", "passes", "unit-core", "test/unit", "tests/lib/unit/core.sml"], [], 300, 600),
              job ("runner-props", ["lib-check", "passes", "runner-props", "test/runner", "tests/lib/runner/props.sml"], [], 300, 600)]
             @ List.concat (List.map (fn lib => let val t = String.translate (fn #"/" => "-" | c => str c) lib
                                                in [job (t ^ "-check", ["lib-basis-check", lib], [], 300, 600),
                                                    job (t ^ "-examples", ["lib-examples", lib, "guarded"], [], 300, 600)] end)
                                     ["test/property", "test/property/basis", "test/unit", "test/runner"])
             @ List.concat (List.map (fn lib =>
                                        List.map (fn s => job (lib ^ "/" ^ basename s, ["lib-suite", lib, s], [], 500, 600))
                                                 (glob ("tests/lib/" ^ lib, ".sml"))
                                        @ (if lib="zmtp" orelse lib="jupyter"
                                           then [Test.requires ["python3"] (job (lib ^ "/@interop", ["lib-interop", lib], [], 500, 600))]
                                           else [])
                                        @ [job (lib ^ "/@check", ["lib-basis-check", lib], [], 300, 600),
                                           job (lib ^ "/@examples", ["lib-examples", lib, "guarded"], [], 300, 600)])
                                     replLibs))),
       tagged ["check", "test-incremental", "covers:tests/flexrec/*"]
         (Test.describe "flexrec"
            (List.concat (List.map (fn (mode, _) =>
                                      List.concat (List.map (fn p => List.map (fn how => job (mode ^ "." ^ p ^ "." ^ how,
                                                                                              ["flexrec-one", mode, p, how], [], 300, 600))
                                                                                ["whole", "units"])
                                                            flexPrograms))
                                   flexModes)
             @ List.map (fn p => job ("repl." ^ p, ["flexrec-repl", p], [], 500, 600)) ["next_dec", "two_types", "after_semicolon"])),
       tagged ["check", "covers:tests/compiler/*"]
         (Test.describe "compiler"
            (tagged ["test"] (job ("stack", ["compiler", "bin/rune-stack"], [], 300, 600))
             :: List.map (fn h => Test.requires [h] (tagged ["test-all"] (job (h, ["compiler", "bin/rune-" ^ h], [], 500, 600))))
                         ["mlton", "smlnj-legacy", "smlnj32", "smlnj-dev", "polyml", "mlkit"])),
       tagged ["check", "covers:tests/runtime/*"]
         (Test.describe "limits"
            ([tagged ["test"] (job ("stack", ["limits", "bin/rune-stack", "bin/runevm-stack"], [], 300, 600)),
              tagged ["test-register"] (job ("register", ["limits", "bin/rune", "bin/runevm"], [], 300, 600))]
             @ (if native then [tagged ["test-native"] (job ("native", ["limits", "bin/rune-stack", "bin/runevm-native"], [], 500, 600))]
                else []))),
       tagged ["check", "covers:tests/runtime/*"]
         (Test.describe "gc-log"
            ([tagged ["test"] (job ("stack", ["gc-log", "bin/rune-stack", "bin/runevm-stack"], [], 300, 600)),
              tagged ["test-register"] (job ("register", ["gc-log", "bin/rune", "bin/runevm"], [], 300, 600))]
             @ (if native then [tagged ["test-native"] (job ("native", ["gc-log", "bin/rune-stack", "bin/runevm-native"], [], 500, 600))]
                else [])))]
end

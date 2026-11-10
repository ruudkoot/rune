(* The tests of rhc's Core (tests/hs/core; the haskell98 roadmap, M8), a
   family of its own until the hs family of M2 takes them: each a command of
   bin/rune-test that prints a line FAIL for what it finds.

   A test is a file of Core text whose first line says what to do, as a test
   of tests/ir does:
     ; run: FLAGS     bin/rhc --lint=3 FLAGS --read-core FILE runs it; what it
                      prints is NAME.expected, and the status NAME.exitcode, 0
                      where there is none. A run that prints nothing fails.
     ; dump: FLAGS    the same, for what is not a run: a dump of a stage
     ; fail: MESSAGE  bin/rhc refuses it, with MESSAGE on standard error.
   At level 3 every program is printed, read back and printed again, so
   print, read, print is the identity on every test. Besides the files:
   every rule of CoreLint has its fault, lint-RULE.core, refused with its
   message; programs from the generator of D55 pass CoreLint and run to an
   outcome, a value or a bottom; and a silent run is judged a failure. *)
structure HsCore =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")
  fun contains (f, text) = String.isSubstring text (read f)
  val dir = "tests/hs/core"
  val rhc = "bin/rhc"

  fun nameOf src = let val f = OS.Path.file src in if String.isSuffix ".core" f then String.substring (f, 0, size f - 5) else f end

  (* what the first line of src asks: the marker and what follows it *)
  fun marker src =
    let
      val line1 = firstLine src
      fun after m = if String.isPrefix ("; " ^ m ^ ":") line1
                    then SOME (String.extract (line1, size m + 3, NONE)) else NONE
    in
      case (after "run", after "dump", after "fail") of
        (SOME flags, _, _) => SOME ("run", flags)
      | (_, SOME flags, _) => SOME ("dump", flags)
      | (_, _, SOME msg) => SOME ("fail", String.extract (msg, if String.isPrefix " " msg then 1 else 0, NONE))
      | _ => NONE
    end

  (* the status a test wants: NAME.exitcode, or 0 *)
  fun wanted n =
    let val f = dir ^ "/" ^ n ^ ".exitcode"
    in if exists f then (case Int.fromString (firstLine f) of SOME k => k | NONE => ~1) else 0 end

  (* what is wrong with a run that printed `out`, where `expected` is wanted:
     NONE where nothing is; a run that printed nothing has failed, whatever
     is expected, as jitOne holds (tests/runner/oracles.sml) *)
  fun judgeRun (out : string, expected : string) : string option =
    if out = "" then SOME "the run printed nothing"
    else if out <> expected then SOME "what it printed differs from its .expected"
    else NONE

  fun one src =
    let
      val n = nameOf src
      val outDir = run ^ "/hs-core"
      val () = mkdirs outDir
      fun f ext = outDir ^ "/" ^ n ^ ext
      val expected = dir ^ "/" ^ n ^ ".expected"
      fun rhcRun flags = exec {cmd = [rhc, "--lint=3"] @ flags @ ["--read-core", src], dir = NONE, stdin = "",
                               stdout = f ".out", stderr = f ".err", timeout = 600}
    in
      case marker src of
        SOME ("fail", msg) =>
          if rhcRun [] = 0 then fail ("hs.core." ^ n ^ ": accepted, where it should stop with: " ^ msg)
          else if contains (f ".err", msg) then ()
          else fail ("hs.core." ^ n ^ ": stopped with: " ^ firstLine (f ".err"))
      | SOME (kind, flags) =>
          let
            val status = rhcRun (String.tokens Char.isSpace flags)
            val want = wanted n
          in
            if status <> want then
              fail ("hs.core." ^ n ^ ": status " ^ Int.toString status ^ " where " ^ Int.toString want ^ " is wanted: "
                    ^ firstLine (f ".err"))
            else if accepting andalso not (same (f ".out", expected)) then
              (write (expected, read (f ".out")); say ("ACCEPTED " ^ expected ^ "\n"))
            else if kind = "run" then
              (case judgeRun (read (f ".out"), read expected) of
                 NONE => ()
               | SOME why => fail ("hs.core." ^ n ^ ": " ^ why ^ ": " ^ difference (expected, f ".out")))
            else if same (f ".out", expected) then ()
            else fail ("hs.core." ^ n ^ ": the dump differs from " ^ expected ^ ": " ^ difference (expected, f ".out"))
          end
      | NONE => fail ("hs.core." ^ n ^ ": its first line is no ; run:, ; dump: or ; fail:")
    end

  (* every rule of CoreLint has its fault, lint-RULE.core, which names it;
     every lint- file is a rule's *)
  fun rules () =
    let
      val outDir = run ^ "/hs-core"
      val () = mkdirs outDir
      val listed = outDir ^ "/rules.out"
      val status = exec {cmd = [rhc, "--lint-rules"], dir = NONE, stdin = "", stdout = listed, stderr = listed, timeout = 60}
      val names = lines (read listed)
      val faults = List.filter (String.isPrefix "lint-") (List.map nameOf (glob (dir, ".core")))
      fun named r = "lint-" ^ r
    in
      if status <> 0 orelse null names then fail ("hs.core.@rules: rhc --lint-rules: " ^ firstLine listed)
      else
        (List.app (fn r =>
                     if not (List.exists (fn x => x = named r) faults) then fail ("hs.core.@rules: the rule " ^ r ^ " has no fault, " ^ dir ^ "/lint-" ^ r ^ ".core")
                     else case marker (dir ^ "/" ^ named r ^ ".core") of
                            SOME ("fail", msg) =>
                              if String.isPrefix ("[" ^ r ^ "]") msg then ()
                              else fail ("hs.core.@rules: " ^ named r ^ ".core is not refused by [" ^ r ^ "]")
                          | _ => fail ("hs.core.@rules: " ^ named r ^ ".core is no ; fail: test"))
                  names;
         List.app (fn x => if List.exists (fn r => named r = x orelse String.isPrefix (named r ^ "-") x) names then ()
                           else fail ("hs.core.@rules: " ^ x ^ ".core is the fault of no rule"))
                  faults)
    end

  (* programs of the generator, seeds 1 to n: each passes CoreLint at level
     3 and runs to a value or to the bottom it may hold, never further *)
  fun generated n =
    let
      val outDir = run ^ "/hs-core/generated"
      val () = mkdirs outDir
      fun seed s =
        let
          val src = outDir ^ "/" ^ Int.toString s ^ ".core"
          fun f ext = outDir ^ "/" ^ Int.toString s ^ ext
        in
          if exec {cmd = [rhc, "--generate-core=" ^ Int.toString s], dir = NONE, stdin = "", stdout = src, stderr = f ".gerr",
                   timeout = 60} <> 0
          then fail ("hs.core.@generated: seed " ^ Int.toString s ^ ": no program: " ^ firstLine (f ".gerr"))
          else
            let val status = exec {cmd = [rhc, "--lint=3", "--steps=5000000", "--read-core", src], dir = NONE, stdin = "",
                                   stdout = f ".out", stderr = f ".err", timeout = 120}
            in
              if status = 0 andalso read (f ".err") = "" then ()
              else if status = 1 andalso read (f ".err") = "rhc: bottom: ErrorCall: bottom\n" then ()
              else fail ("hs.core.@generated: seed " ^ Int.toString s ^ ": status " ^ Int.toString status ^ ": "
                         ^ firstLine (f ".err") ^ " (" ^ src ^ ")")
            end
        end
      fun go s = if s > n then () else (seed s; go (s + 1))
    in go 1 end

  (* the judge of a run holds a silent one a failure, and a right one not *)
  fun silent () =
    (case judgeRun ("", "") of
       SOME _ => ()
     | NONE => fail "hs.core.@silent: a run that printed nothing passed";
     case judgeRun ("1\n", "1\n") of
       NONE => ()
     | SOME why => fail ("hs.core.@silent: a right run failed: " ^ why))

  fun command args =
    case args of
      ["hs-core-one", src] => SOME (fn () => one src)
    | ["hs-core-rules"] => SOME rules
    | ["hs-core-generated", n] => SOME (fn () => generated (getOpt (Int.fromString n, 16)))
    | ["hs-core-silent"] => SOME silent
    | _ => NONE

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val tree =
    tagged ["check", "test-rhc", "covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:rhc.build",
            "covers:tests/hs/core/*", "covers:tests/runner/hscore.sml"]
      (Test.describe "hs/core"
         (List.map (fn s => Tools.job (nameOf s, ["hs-core-one", s], [], 300, 600)) (glob (dir, ".core"))
          @ [Tools.job ("@rules", ["hs-core-rules"], [], 100, 120),
             Tools.job ("@generated", ["hs-core-generated", "32"], [], 300, 1200),
             Tools.job ("@silent", ["hs-core-silent"], [], 100, 60)]))
end

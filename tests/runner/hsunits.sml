(* rhc in units (the haskell98 roadmap's M21; docs/testing.md, rhc in
   units): rhc's entries in the store alone, RhcStore with a client of its
   own and no compiler, compiled with Pickle and UnitStore and nothing else
   (tests/hs/units/store.sml), as Rune's own store is tested
   (tests/lib/compiler/store.sml); and a unit's Mid text naming another
   unit's global (tests/hs/units/named.sml). *)
structure HsUnits =
struct
  open Sh

  val out = run ^ "/hs-units"

  (* what the store's test is compiled from: the store's own closure,
     RhcStore and the test *)
  val storeSources =
    ["lib/compiler/util/ordmap.sml", "lib/compiler/util/inttable.sml", "lib/compiler/state_sig.sml",
     "lib/compiler/state.sml", "lib/compiler/util/pickle.sml", "lib/compiler/driver/unitstore.sml",
     "src/rhc/store.sml", "tests/hs/units/store.sml"]

  fun store () =
    let
      val () = mkdirs out
      val rbc = out ^ "/store-tests.rbc"
      val log = out ^ "/store-tests.compile"
      val ran = out ^ "/store-tests.out"
    in
      if exec {cmd = [fromRoot "bin/rune", "--library", "test/unit"] @ List.map fromRoot storeSources @ ["-o", rbc],
               dir = NONE, stdin = "", stdout = log, stderr = log, timeout = 600} <> 0
      then say ("FAIL hs.units.store: the test does not compile: " ^ firstLine log ^ "\n")
      else if exec {cmd = [fromRoot "bin/runevm", rbc], dir = NONE, stdin = "", stdout = ran, stderr = ran, timeout = 300} = 0
      then ()
      else say ("FAIL hs.units.store: " ^ String.concatWith "; " (List.filter (fn l => not (String.isPrefix "PASS " l))
                                                                              (lines (read ran))) ^ "\n")
    end

  (* a unit's Mid text naming another unit's global (MidText.parseWith's
     named), built on Mid's layer of the compiler as rhc is
     (tests/hs/units/named.build) *)
  fun named () =
    let
      val () = mkdirs out
      val rbc = out ^ "/named.rbc"
      val log = out ^ "/named.compile"
      val ran = out ^ "/named.out"
    in
      if exec {cmd = [fromRoot "bin/rune", "--build", fromRoot "tests/hs/units/named.build", "-o", rbc],
               dir = NONE, stdin = "", stdout = log, stderr = log, timeout = 900} <> 0
      then say ("FAIL hs.units.named: the test does not compile: " ^ firstLine log ^ "\n")
      else if exec {cmd = [fromRoot "bin/runevm", rbc], dir = NONE, stdin = "", stdout = ran, stderr = ran, timeout = 300} = 0
      then ()
      else say ("FAIL hs.units.named: " ^ String.concatWith "; " (List.filter (fn l => not (String.isPrefix "PASS " l))
                                                                              (lines (read ran))) ^ "\n")
    end

  (* A run test of hs/core with its files as units, the files its flags
     read (lib/base.core) and the test, each after rhc's runtime's unit,
     compiled apart and linked (M21c; rhc --units): what it prints is its
     .expected, and it ends as its .exitcode says, every bottom one bottom *)
  fun coreOne src =
    let
      val n = HsCore.nameOf src
      (* named as the test is, which is the program's name on the VM *)
      val () = mkdirs (out ^ "/core")
      val o' = out ^ "/core/" ^ n
      val flags = case HsCore.marker src of SOME ("run", f) => String.tokens Char.isSpace f | _ => []
      val (dir, args) = HsCore.whereRuns (src, o', flags @ ["--read-core", src])
      val rbc = o' ^ ".rbc"
    in
      if exec {cmd = [fromRoot "bin/rhc", "--lint=2", "--units"] @ args @ ["-o", rbc], dir = dir, stdin = "",
               stdout = o' ^ ".compile", stderr = o' ^ ".compile", timeout = 600} <> 0
      then say ("FAIL hs.units.core." ^ n ^ ": does not compile in units: " ^ firstLine (o' ^ ".compile") ^ "\n")
      else
        let
          val status = exec {cmd = [fromRoot "bin/runevm", rbc], dir = dir, stdin = HsCore.stdinOf n,
                             stdout = o' ^ ".out", stderr = o' ^ ".err", timeout = 300}
          val want = HsCore.wanted n
        in
          if status <> want andalso (want = 0 orelse status = 0) then
            say ("FAIL hs.units.core." ^ n ^ ": status " ^ Int.toString status ^ " where " ^ Int.toString want
                 ^ " is wanted: " ^ firstLine (o' ^ ".err") ^ "\n")
          else
            case HsCore.judgeRun (read (o' ^ ".out"), read (HsCore.dir ^ "/" ^ n ^ ".expected")) of
              NONE => ()
            | SOME why => say ("FAIL hs.units.core." ^ n ^ ": " ^ why ^ "\n")
        end
    end

  (* the run tests of hs/core a VM runs *)
  fun coreTests () =
    List.filter (fn s => case (HsCore.marker s, HsCore.interpreterOnly s) of (SOME ("run", _), NONE) => true | _ => false)
                (glob (HsCore.dir, ".core"))

  (* A program of units kept in a store and edited (M21's done-when, the
     warm path): base.core, lib.core and app.core of tests/hs/units/warm,
     copies edited in a directory of the job's. Each step says which units
     it compiles and which it takes from the store (--show-units), links
     what a compile without the store links, byte for byte past the
     header, and prints what it should: nothing edited takes every unit; a
     body's edit compiles its unit alone; a type's edit compiles its users
     too; a unit put before app.core that declares a name app.core takes
     compiles app.core, which takes it from there (H1: the latest unit's);
     and without it again app.core is taken, its first entry's *)
  fun warmWith (whole : bool) =
    let
      val d = out ^ (if whole then "/warm-whole" else "/warm")
      val () = (rmTree d; mkdirs d)
      fun f x = d ^ "/" ^ x
      fun copy (src, dst) = write (f dst, read (fromRoot src))
      val () = (copy ("tests/hs/core/lib/base.core", "base.core"); copy ("tests/hs/units/warm/lib.core", "lib.core");
                copy ("tests/hs/units/warm/app.core", "app.core"); copy ("tests/hs/units/warm/mid.core", "mid.core"))
      fun edit (file, old, new) =
        let
          val t = read (f file)
          fun go i = if i + size old > size t then NONE
                     else if String.substring (t, i, size old) = old then SOME i else go (i + 1)
        in
          case go 0 of
            SOME i => write (f file, String.substring (t, 0, i) ^ new ^ String.extract (t, i + size old, NONE))
          | NONE => say ("FAIL hs.units.warm: the edit of " ^ file ^ " finds no " ^ old ^ "\n")
        end
      fun bytes p = (let val i = BinIO.openIn p in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
                    handle IO.Io _ => ""
      fun rhc (args, log) =
        exec {cmd = [fromRoot "bin/rhc", "--lint=2", "--units"] @ (if whole then ["--link=whole"] else []) @ args, dir = SOME d,
              stdin = "", stdout = log, stderr = log, timeout = 600}
      fun step (label, files, want : (string * string) list, prints : string) =
        let
          val reads = List.concat (List.map (fn x => ["--read-core", x]) files)
          val wlog = f (label ^ ".warm")
          val warmed = rhc (["--store", "st", "--show-units"] @ reads @ ["-o", "w.rbc"], wlog) = 0
          val cold = rhc (reads @ ["-o", "c.rbc"], f (label ^ ".cold")) = 0
          val said = List.mapPartial (fn l => if String.isPrefix "rhc: unit " l
                                              then case String.tokens (fn c => c = #" " orelse c = #":") (String.extract (l, 10, NONE)) of
                                                     n :: what :: _ => SOME (n, what)
                                                   | _ => NONE
                                              else if String.isPrefix "rhc: link: " l
                                              then case String.tokens (fn c => c = #" ") (String.extract (l, 11, NONE)) of
                                                     what :: _ => SOME ("link", what)
                                                   | _ => NONE
                                              else NONE)
                                     (lines (read wlog))
          fun shown xs = String.concatWith ", " (List.map (fn (n, w) => n ^ " " ^ w) xs)
          val _ = exec {cmd = [fromRoot "bin/runevm", f "w.rbc"], dir = SOME d, stdin = "", stdout = f (label ^ ".out"),
                        stderr = f (label ^ ".err"), timeout = 300}
          val w = bytes (f "w.rbc")
          val c = bytes (f "c.rbc")
        in
          if not warmed then say ("FAIL hs.units.warm: " ^ label ^ ": does not compile: " ^ firstLine wlog ^ "\n")
          else if not cold then say ("FAIL hs.units.warm: " ^ label ^ ": does not compile without the store\n")
          else
            ((if said = want then () else say ("FAIL hs.units.warm: " ^ label ^ ": " ^ shown said ^ ", where "
                                               ^ shown want ^ " is wanted\n"));
             (if size w > 12 andalso String.extract (w, 12, NONE) = String.extract (c, 12, NONE) then ()
              else say ("FAIL hs.units.warm: " ^ label ^ ": the program from the store is not the one without it\n"));
             (if read (f (label ^ ".out")) = prints then ()
              else say ("FAIL hs.units.warm: " ^ label ^ ": printed " ^ firstLine (f (label ^ ".out")) ^ "\n"));
             (* with --link=whole, a whole compile's of the same files *)
             if not whole then ()
             else if exec {cmd = [fromRoot "bin/rhc", "--lint=2"] @ reads @ ["-o", "j.rbc"], dir = SOME d, stdin = "",
                           stdout = f (label ^ ".whole"), stderr = f (label ^ ".whole"), timeout = 600} <> 0
             then say ("FAIL hs.units.warm: " ^ label ^ ": the files do not compile whole\n")
             else
               let val j = bytes (f "j.rbc")
               in
                 if size j > 12 andalso String.extract (w, 12, NONE) = String.extract (j, 12, NONE) then ()
                 else say ("FAIL hs.units.warm: " ^ label ^ ": the program is not the whole compile's of the same files\n")
               end)
        end
      val three = ["base.core", "lib.core", "app.core"]
      (* what a unit compiled says, and the runtime's unit taken: with
         --link=whole a unit is checked, the runtime's always, and the link
         compiled or taken from its memo *)
      val made = if whole then "checked" else "compiled"
      val rt = if whole then ("rhc-runtime", "checked") else ("rhc-runtime", "taken")
      fun link what = if whole then [("link", what)] else []
      fun all what = (if whole andalso what = "taken" then [rt] else [("rhc-runtime", what)])
                     @ List.map (fn n => (n, what)) ["base", "lib", "app"]
    in
      step ("cold", three, all made @ link "compiled", "18\n");
      step ("again", three, all "taken" @ link "taken", "18\n");
      edit ("lib.core", "(prim int_add m m)", "(prim int_mul m 3)");
      step ("body", three, [rt, ("base", "taken"), ("lib", made), ("app", "taken")] @ link "compiled", "27\n");
      edit ("lib.core", "(data Shape () (Square Int) (Rect Int Int))", "(data Shape () (Square Int) (Rect Int Int) (Tri Int))");
      step ("type", three, [rt, ("base", "taken"), ("lib", made), ("app", made)] @ link "compiled", "27\n");
      (* a name two units define is one no joined program holds: with
         --link=whole a program's names are a whole program's, as a Haskell
         program's are, qualified by their modules *)
      if whole then ()
      else step ("latest", ["base.core", "lib.core", "mid.core", "app.core"],
                 [rt, ("base", "taken"), ("lib", "taken"), ("mid", made), ("app", made)] @ link "compiled", "9\n");
      step ("without", three, all "taken" @ link "taken", "27\n")
    end
  fun warm () = warmWith false
  fun warmWhole () = warmWith true

  (* the ABI facts of an interface (H9), tests/hs/units/abi: a newtype its
     unit makes a box, which a unit that gives it all its arguments takes as
     a box too, and a value of one unit named as a constructor of another,
     taken as the value; compiled as units, it prints what Core's
     interpreter prints *)
  fun abi () =
    let
      val () = mkdirs out
      val files = ["tests/hs/core/lib/base.core", "tests/hs/units/abi/lib.core", "tests/hs/units/abi/app.core"]
      val reads = List.concat (List.map (fn f => ["--read-core", fromRoot f]) files)
      val rbc = out ^ "/abi.rbc"
    in
      if exec {cmd = [fromRoot "bin/rhc", "--lint=2", "--units"] @ reads @ ["-o", rbc], dir = NONE, stdin = "",
               stdout = out ^ "/abi.compile", stderr = out ^ "/abi.compile", timeout = 600} <> 0
      then say ("FAIL hs.units.abi: does not compile in units: " ^ firstLine (out ^ "/abi.compile") ^ "\n")
      else
        (ignore (exec {cmd = [fromRoot "bin/runevm", rbc], dir = NONE, stdin = "", stdout = out ^ "/abi.out",
                       stderr = out ^ "/abi.err", timeout = 300});
         if read (out ^ "/abi.out") = "42\n" then ()
         else say ("FAIL hs.units.abi: printed " ^ firstLine (out ^ "/abi.out") ^ " where 42 is wanted: "
                   ^ firstLine (out ^ "/abi.err") ^ "\n"))
    end

  (* rhc's driver over a program of Haskell in units (M21f): Main and Lib
     of tests/hs/units/drive, copies edited, each step with the library's
     unit, Lib's, Main's and the link compiled or taken as it should, what
     it prints, and its program byte for byte the whole compile's of the
     same files (`rhc Main.hs`): nothing edited takes everything; a body's
     edit of Lib compiles Lib and the link alone, Main taken by its reads'
     fingerprints; an export added to Lib that Main does not read compiles
     Lib alone too; a type's edit of a value Main reads compiles Main. A
     step that takes the library's unit parses none of its modules (the
     log's "rhc: parsed" line, RhcGraph.scan) *)
  fun drive () =
    let
      val d = out ^ "/drive"
      val () = (rmTree d; mkdirs d)
      fun f x = d ^ "/" ^ x
      val () = (write (f "Lib.hs", read (fromRoot "tests/hs/units/drive/Lib.hs"));
                write (f "Main.hs", read (fromRoot "tests/hs/units/drive/Main.hs")))
      fun edit (file, old, new) =
        let
          val t = read (f file)
          fun go i = if i + size old > size t then NONE
                     else if String.substring (t, i, size old) = old then SOME i else go (i + 1)
        in
          case go 0 of
            SOME i => write (f file, String.substring (t, 0, i) ^ new ^ String.extract (t, i + size old, NONE))
          | NONE => say ("FAIL hs.units.drive: the edit of " ^ file ^ " finds no " ^ old ^ "\n")
        end
      fun bytes p = (let val i = BinIO.openIn p in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
                    handle IO.Io _ => ""
      fun has (l, s) = String.isSubstring s l
      fun step (label, want : (string * string) list, prints) =
        let
          val log = f (label ^ ".log")
          val ok = exec {cmd = [fromRoot "bin/rhc", "--lint=2", "--store", "st", "--show-units", "Main.hs", "-o", "w.rbc"],
                         dir = SOME d, stdin = "", stdout = log, stderr = log, timeout = 900} = 0
          val whole = exec {cmd = [fromRoot "bin/rhc", "--lint=2", "Main.hs", "-o", "j.rbc"], dir = SOME d, stdin = "",
                            stdout = f (label ^ ".whole"), stderr = f (label ^ ".whole"), timeout = 900} = 0
          val text = read log
          (* what the log says of a unit: "unit NAME: compiled" or "taken" *)
          fun says (unit, what) =
            if unit = "link" then has (text, "rhc: link: " ^ what)
            else if unit = "library" then has (text, "rhc: unit haskell98:") andalso
                                          List.exists (fn l => has (l, "rhc: unit haskell98:") andalso has (l, ": " ^ what))
                                                      (lines text)
            else has (text, "rhc: unit " ^ unit ^ ": " ^ what)
          val _ = exec {cmd = [fromRoot "bin/runevm", f "w.rbc"], dir = SOME d, stdin = "", stdout = f (label ^ ".out"),
                        stderr = f (label ^ ".err"), timeout = 300}
          val w = bytes (f "w.rbc")
          val j = bytes (f "j.rbc")
          val parsed = List.find (fn l => String.isPrefix "rhc: parsed " l) (lines text)
        in
          if not ok then say ("FAIL hs.units.drive: " ^ label ^ ": does not compile: " ^ firstLine log ^ "\n")
          else if not whole then say ("FAIL hs.units.drive: " ^ label ^ ": does not compile whole\n")
          else
            (List.app (fn (u, what) => if says (u, what) then ()
                                       else say ("FAIL hs.units.drive: " ^ label ^ ": " ^ u ^ " not " ^ what ^ "\n")) want;
             if read (f (label ^ ".out")) = prints then ()
             else say ("FAIL hs.units.drive: " ^ label ^ ": printed " ^ firstLine (f (label ^ ".out")) ^ "\n");
             if not (List.exists (fn w => w = ("library", "taken")) want) then ()
             else (case parsed of
                     NONE => say ("FAIL hs.units.drive: " ^ label ^ ": the log says nothing of what was parsed\n")
                   | SOME l => if has (l, " haskell98:") then
                                 say ("FAIL hs.units.drive: " ^ label ^ ": the library's unit is taken, its modules parsed: " ^ l ^ "\n")
                               else ());
             if size w > 12 andalso String.extract (w, 12, NONE) = String.extract (j, 12, NONE) then ()
             else say ("FAIL hs.units.drive: " ^ label ^ ": the program is not the whole compile's\n"))
        end
    in
      (* the library's unit from bin/rhc's snapshot (bin/rhc.layer) *)
      step ("cold", [("library", "taken"), ("Lib", "compiled"), ("Main", "compiled"), ("link", "compiled")], "hello\n42\n");
      step ("again", [("library", "taken"), ("Lib", "taken"), ("Main", "taken"), ("link", "taken")], "hello\n42\n");
      edit ("Lib.hs", "double x = x + x", "double x = 2 * x");
      step ("body", [("library", "taken"), ("Lib", "compiled"), ("Main", "taken"), ("link", "compiled")], "hello\n42\n");
      edit ("Lib.hs", "module Lib (double, greeting) where", "module Lib (double, greeting, triple) where\n\ntriple :: Int -> Int\ntriple x = 3 * x");
      step ("export", [("library", "taken"), ("Lib", "compiled"), ("Main", "taken")], "hello\n42\n");
      edit ("Lib.hs", "double :: Int -> Int", "double :: Integer -> Integer");
      step ("type", [("library", "taken"), ("Lib", "compiled"), ("Main", "compiled"), ("link", "compiled")], "hello\n42\n")
    end

  (* the verdict a log's word gives, its letters: `taken`, `compiled` *)
  fun wordOf w = case String.tokens (not o Char.isAlpha) w of x :: _ => x | [] => w

  (* E13's holes (the haskell98 roadmap's *What a cache hit must satisfy*,
     H1 to H8; E13's two GHC cases among them): each case of
     tests/hs/units/holes a program and its steps, each step a directory of
     modules written over the last step's and `want`, what the program
     prints or `refused`, and `units`, if there, what the units' compile
     must say of a unit, a line each: `NAME compiled` or `NAME taken`
     (`link` the link). At each step the units' compile through one store
     (`--units --store`) and the whole compile of the same files both give
     what is wanted, and where they compile, the same program byte for
     byte. A hole planted (tests/runner/hsmutantlist.sml, HU01 to HU09,
     HU11) takes a unit whose compile would now refuse or make another
     program, or one a step's `units` says is compiled, and its case
     fails. M22's SCC keys: h8-group (a type group across a cycle's
     members hashed as one; a body edited in a cycle compiles no client)
     and h8-split (a cycle split, its client taken: a usage names no unit
     under the link of C) *)
  val holesDir = "tests/hs/units/holes"
  fun holeCases () = sort (List.filter (fn n => isDir (fromRoot (holesDir ^ "/" ^ n))) (entries (fromRoot holesDir)))

  (* a case's states: the k-th its steps 1 to k's modules (.hs and .lhs),
     the later a module's text the one it has, less those a step's `rm`
     names, a file a line; the k-th step's want, and what its `units` says
     of the units, a line each, `NAME compiled` or `NAME taken` (`link`
     the link), which holds in the order of the steps *)
  fun statesOf name : (string * (string * string) list * string * string list) list =
    let
      val src = fromRoot (holesDir ^ "/" ^ name)
      val steps = sort (List.filter (fn n => isDir (src ^ "/" ^ n)) (entries src))
      fun go ([], _, acc) = List.rev acc
        | go (s :: rest, files, acc) =
            let
              val mine = List.map (fn p => (OS.Path.file p, read p)) (glob (src ^ "/" ^ s, ".hs") @ glob (src ^ "/" ^ s, ".lhs"))
              val gone = String.tokens Char.isSpace (read (src ^ "/" ^ s ^ "/rm"))
              val files' = mine @ List.filter (fn (n, _) => not (List.exists (fn (m, _) => m = n) mine)
                                                            andalso not (List.exists (fn m => m = n) gone)) files
            in go (rest, files', (s, files', read (src ^ "/" ^ s ^ "/want"), lines (read (src ^ "/" ^ s ^ "/units"))) :: acc) end
    in go (steps, [], []) end

  (* one state in d, through the store d/st: the units' compile and the
     whole compile give its want, a refusal for the same reason, and where
     they compile, the same program byte for byte; false where they do
     not, said *)
  fun stateHolds (family, d, label, files, want, units) =
    let
      fun f x = d ^ "/" ^ x
      val () = List.app (fn n => if (String.isSuffix ".hs" n orelse String.isSuffix ".lhs" n)
                                    andalso not (List.exists (fn (m, _) => m = n) files)
                                 then OS.FileSys.remove (f n) else ()) (entries d)
      val () = List.app (fn (n, text) => write (f n, text)) files
      fun bytes p = (let val i = BinIO.openIn p in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
                    handle IO.Io _ => ""
      fun compiles (cmd, log) = exec {cmd = cmd, dir = SOME d, stdin = "", stdout = f log, stderr = f log, timeout = 900} = 0
      val warm = compiles ([fromRoot "bin/rhc", "--store", "st", "--show-units", "Main.hs", "-o", "w.rbc"], "warm.log")
      (* the same through a store of its own, each hit judged by every
         usage asked, as before issue 37's A and B (RHC_HIT=asked) *)
      val asked = compiles (["env", "RHC_HIT=asked", fromRoot "bin/rhc", "--store", "st-asked", "--show-units", "Main.hs",
                             "-o", "a.rbc"], "asked.log")
      val whole = compiles ([fromRoot "bin/rhc", "Main.hs", "-o", "j.rbc"], "whole.log")
      fun units' () = String.concatWith "; " (List.filter (fn l => String.isPrefix "rhc: unit" l orelse String.isPrefix "rhc: link" l)
                                                         (lines (read (f "warm.log"))))
      (* a line of a step's `units`: NAME and what its log says of it *)
      fun says (u, log) =
        case String.tokens Char.isSpace u of
          ["link", what] => String.isSubstring ("rhc: link: " ^ what) log
        | [name, what] => String.isSubstring ("rhc: unit " ^ name ^ ": " ^ what) log
        | _ => false
      fun no why = (say ("FAIL " ^ family ^ ": " ^ label ^ ": " ^ why ^ "\n"); false)
      (* what a compile's log says of each unit and the link: taken,
         compiled, named, a line each *)
      fun verdicts log =
        List.mapPartial
          (fn l =>
             if String.isPrefix "rhc: unit " l orelse String.isPrefix "rhc: link: " l then
               case String.tokens Char.isSpace l of
                 "rhc:" :: "unit" :: name :: what :: _ => SOME (name ^ " " ^ wordOf what)
               | "rhc:" :: "link:" :: what :: _ => SOME ("link " ^ wordOf what)
               | _ => NONE
             else NONE)
          (lines (read (f log)))
      val alike = verdicts "warm.log" = verdicts "asked.log" andalso warm = asked
      (* the units' refusal, which the whole compile's must say too: a unit
         taken that should not be may make a link that does not check *)
      fun refusal () =
        let val marker = ": error: "
        in
          case List.find (String.isSubstring marker) (lines (read (f "warm.log"))) of
            SOME l => Substring.string (Substring.triml (size marker) (#2 (Substring.position marker (Substring.full l))))
          | NONE => firstLine (f "warm.log")
        end
    in
      if not alike then
        no ("a unit is taken or made otherwise than where every usage is asked: "
            ^ String.concatWith ", " (verdicts "warm.log") ^ "; asked: " ^ String.concatWith ", " (verdicts "asked.log"))
      else if want = "refused\n" then
        if warm then no ("the units' compile takes what the whole compile "
                         ^ (if whole then "takes too, where a refusal is wanted" else "refuses: " ^ firstLine (f "whole.log"))
                         ^ " (" ^ units' () ^ ")")
        else if whole then no "the whole compile takes it, where a refusal is wanted"
        else if String.isSubstring (refusal ()) (read (f "whole.log")) then true
        else no ("the units' compile refuses it otherwise than the whole compile: " ^ refusal () ^ " (" ^ units' () ^ ")")
      else if not whole then no ("the whole compile refuses it: " ^ firstLine (f "whole.log"))
      else if not warm then no ("the units' compile refuses it: " ^ firstLine (f "warm.log"))
      else
        let
          val w = bytes (f "w.rbc")
          val j = bytes (f "j.rbc")
          val () = ignore (exec {cmd = [fromRoot "bin/runevm", f "w.rbc"], dir = SOME d, stdin = "", stdout = f "w.out",
                                 stderr = f "w.out", timeout = 300})
          val printed = read (f "w.out")
        in
          if not (size w > 12 andalso String.extract (w, 12, NONE) = String.extract (j, 12, NONE)) then
            no ("the units' program is not the whole compile's (" ^ units' () ^ ")")
          else if printed <> want then no ("printed " ^ firstLine (f "w.out") ^ ", where " ^ firstLine' want ^ " is wanted")
          else
            case List.filter (fn u => not (says (u, read (f "warm.log")))) units of
              [] => true
            | u :: _ => no ("the units' compile does not say " ^ u ^ " (" ^ units' () ^ ")")
        end
    end
  and firstLine' s = case String.fields (fn c => c = #"\n") s of l :: _ => l | [] => ""

  (* a case of E13's holes, its steps in order through one store, as
     holesDir's comment says *)
  fun hole name () =
    let
      val d = out ^ "/holes/" ^ name
      val () = (rmTree d; mkdirs d)
    in
      List.app (fn (s, files, want, units) => ignore (stateHolds ("hs.units.holes", d, name ^ " step " ^ s, files, want, units)))
        (statesOf name)
    end

  (* warm equals --whole over random edits (M21's standing tier, nightly,
     unitsOne's comparison of tests/runner/oracles.sml): of each case of
     tests/hs/units/holes, a walk of its states drawn at random through one
     store, each state's modules written over the last's, so that a unit's
     entry meets every edit and its undoing in any order. The seed is
     RHC_UNITS_SEED, else the day's, and the log says it and the walk *)
  val walk = 12
  fun random name () =
    let
      val d = out ^ "/random/" ^ name
      val () = (rmTree d; mkdirs d)
      val seed = case Int.fromString (env ("RHC_UNITS_SEED", "")) of
                   SOME n => n
                 | NONE => LargeInt.toInt (LargeInt.div (Time.toSeconds (Time.now ()), 86400))
      val states = Vector.fromList (statesOf name)
      val r = ref (seed mod 2147483647 + 1)
      fun next n = (r := (!r * 48271) mod 2147483647; !r mod n)
      val picks = List.tabulate (walk, fn _ => next (Vector.length states))
      val () = say ("hs.units.random: " ^ name ^ ", seed " ^ Int.toString seed ^ ", states "
                    ^ String.concatWith " " (List.map (fn i => #1 (Vector.sub (states, i))) picks) ^ "\n")
      fun go (_, []) = ()
        | go (k, i :: rest) =
            let val (s, files, want, _) = Vector.sub (states, i)
            in
              if stateHolds ("hs.units.random", d, name ^ " seed " ^ Int.toString seed ^ ", walk " ^ Int.toString k
                                                   ^ ", state " ^ s, files, want, [])
              then go (k + 1, rest) else ()
            end
    in
      go (1, picks)
    end

  (* hello against the snapshot (M21's done-when, D45): a store made by one
     compile is a layer, read only, the library's unit frozen in it; hello
     compiled against it, with an overlay of its own, takes the library's
     unit from the layer, parses none of its modules and compiles Main and
     the link alone, its program byte for byte the whole compile's of the
     same file; and the layer is not written *)
  fun snapshot () =
    let
      val d = out ^ "/snapshot"
      val () = (rmTree d; mkdirs (d ^ "/make"); mkdirs (d ^ "/hello"))
      fun f x = d ^ "/" ^ x
      fun bytes p = (let val i = BinIO.openIn p in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
                    handle IO.Io _ => ""
      fun rhc (dir, args, log) =
        exec {cmd = [fromRoot "bin/rhc"] @ args, dir = SOME (f dir), stdin = "", stdout = f log, stderr = f log, timeout = 900} = 0
      (* the layer's files, each with its size *)
      fun listing dir =
        let
          fun walk p = if isDir p then List.concat (List.map (fn n => walk (p ^ "/" ^ n)) (sort (entries p)))
                       else [p ^ " " ^ Int.toString (size (bytes p))]
        in walk dir end
      val () = write (f "make/Main.hs", "main :: IO ()\nmain = putStrLn \"made\"\n")
      val () = write (f "hello/Main.hs", "main :: IO ()\nmain = putStrLn \"hello\"\n")
      val made = rhc ("make", ["--store", f "layer", "Main.hs", "-o", "m.rbc"], "make.log")
      val unwritten = listing (f "layer")
      val warm = rhc ("hello", ["--layer", f "layer", "--store", f "overlay", "--show-units", "Main.hs", "-o", "w.rbc"],
                      "hello.log")
      val whole = rhc ("hello", ["Main.hs", "-o", "j.rbc"], "whole.log")
      val text = read (f "hello.log")
      fun has s = String.isSubstring s text
      val w = bytes (f "hello/w.rbc")
      val j = bytes (f "hello/j.rbc")
      fun no why = say ("FAIL hs.units.snapshot: " ^ why ^ "\n")
    in
      if not made then no ("the snapshot is not made: " ^ firstLine (f "make.log"))
      else if not warm then no ("hello does not compile against it: " ^ firstLine (f "hello.log"))
      else if not whole then no ("hello does not compile whole: " ^ firstLine (f "whole.log"))
      else
        (if List.exists (fn l => String.isPrefix "rhc: unit haskell98:" l andalso String.isSubstring ": taken" l) (lines text) then ()
         else no "the library's unit is not taken from the snapshot";
         if has "rhc: unit Main: compiled" then () else no "Main is not compiled";
         if List.exists (fn l => String.isPrefix "rhc: parsed 1 of " l andalso String.isSuffix " Main" l) (lines text) then ()
         else no ("a module of the library is parsed: " ^ getOpt (List.find (String.isPrefix "rhc: parsed") (lines text), "?"));
         if size w > 12 andalso String.extract (w, 12, NONE) = String.extract (j, 12, NONE) then ()
         else no "the program is not the whole compile's";
         if listing (f "layer") = unwritten then () else no "the snapshot is written")
    end

  (* The store by default (the haskell98 roadmap's D58), RHC_STORE unset as
     a compile outside the runner has it (the runner sets it empty), Main
     and Lib of tests/hs/units/drive in a directory of the job's: a plain
     compile keeps its units in .rhc beside Main.hs, and the next one takes
     them and the link from there, its program byte for byte the first's;
     --units, which a compile of Haskell is without it, makes the same
     compile; a check keeps its units too, and a run takes them; --no-store
     and an empty RHC_STORE write nothing, and RHC_STORE names another
     store, which .rhc is not *)
  fun bytesOf p = (let val i = BinIO.openIn p in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
                  handle IO.Io _ => ""
  fun drived (d : string) =
    (rmTree d; mkdirs d;
     write (d ^ "/Lib.hs", read (fromRoot "tests/hs/units/drive/Lib.hs"));
     write (d ^ "/Main.hs", read (fromRoot "tests/hs/units/drive/Main.hs")))
  (* bin/rhc in d with RHC_STORE unset, or set to what `store` says, its
     log in d/log *)
  fun rhcIn (d, store : string option, args, log) =
    execEnv (fn e => case store of SOME v => setEnv ("RHC_STORE", v) e | NONE => unsetEnv ["RHC_STORE"] e)
      {cmd = [fromRoot "bin/rhc"] @ args, dir = SOME d, stdin = "", stdout = d ^ "/" ^ log, stderr = d ^ "/" ^ log, timeout = 900}
  (* what a log says of a unit or the link: compiled, taken or nothing *)
  fun saysOf (text, unit) =
    let
      val prefix = if unit = "link" then "rhc: link: " else "rhc: unit " ^ unit ^ ": "
      val said = List.mapPartial (fn l => if String.isPrefix prefix l
                                          then SOME (hd (String.tokens (fn c => c = #" " orelse c = #",") (String.extract (l, size prefix, NONE))))
                                          else NONE)
                                 (lines text)
    in List.filter (fn w => w = "compiled" orelse w = "taken" orelse w = "reached") said end
  fun samePrograms (a, b) =
    let val (x, y) = (bytesOf a, bytesOf b)
    in size x > 12 andalso String.extract (x, 12, NONE) = String.extract (y, 12, NONE) end

  fun defaultStore () =
    let
      fun no why = say ("FAIL hs.units.default: " ^ why ^ "\n")
      val d = out ^ "/default"
      fun f x = d ^ "/" ^ x
      fun expect (label, log, want : (string * string) list) =
        let val text = read log
        in
          List.app (fn (u, w) => if List.exists (fn x => x = w) (saysOf (text, u)) then ()
                                 else no (label ^ ": " ^ u ^ " not " ^ w ^ " (" ^ String.concatWith "; " (List.filter (String.isPrefix "rhc: ") (lines text)) ^ ")"))
            want
        end
      (* the files of d but the program's and its outputs, a store's *)
      fun written dir = List.filter (fn n => not (List.exists (fn m => m = n) ["Lib.hs", "Main.hs"])
                                              andalso not (String.isSuffix ".rbc" n) andalso not (String.isSuffix ".log" n))
                                    (sort (entries dir))
      val () = drived d
      val cold = rhcIn (d, NONE, ["--show-units", "Main.hs", "-o", "a.rbc"], "cold.log") = 0
      val store = isDir (f ".rhc")
      val again = rhcIn (d, NONE, ["--show-units", "Main.hs", "-o", "b.rbc"], "again.log") = 0
      val spelled = rhcIn (d, NONE, ["--units", "--show-units", "Main.hs", "-o", "c.rbc"], "units.log") = 0
      val () =
        if not cold then no ("a plain compile fails: " ^ firstLine (f "cold.log"))
        else if not store then no ("a plain compile keeps no .rhc beside Main.hs: " ^ String.concatWith " " (written d))
        else if not again then no ("the second compile fails: " ^ firstLine (f "again.log"))
        else if not spelled then no ("a compile with --units fails: " ^ firstLine (f "units.log"))
        else
          (expect ("cold", f "cold.log", [("Lib", "compiled"), ("Main", "compiled"), ("link", "compiled")]);
           expect ("again", f "again.log", [("Lib", "taken"), ("Main", "taken"), ("link", "taken")]);
           expect ("--units", f "units.log", [("Lib", "taken"), ("Main", "taken"), ("link", "taken")]);
           if samePrograms (f "a.rbc", f "b.rbc") andalso samePrograms (f "a.rbc", f "c.rbc") then ()
           else no "the program taken from .rhc is not the one compiled";
           if written d = [".rhc"] then () else no ("a compile writes more than .rhc: " ^ String.concatWith " " (written d)))
      (* a check keeps its units, a run takes them *)
      val c = out ^ "/default-check"
      fun g x = c ^ "/" ^ x
      val () = drived c
      val checked = rhcIn (c, NONE, ["--typecheck-only", "Main.hs"], "check.log") = 0
      val ran = rhcIn (c, NONE, ["--show-units", "Main.hs"], "run.log") = 0
      val compiled = rhcIn (c, NONE, ["--show-units", "Main.hs", "-o", "a.rbc"], "compile.log") = 0
      val () =
        if not checked then no ("a check fails: " ^ firstLine (g "check.log"))
        else if not ran orelse not (String.isSubstring "hello\n42\n" (read (g "run.log"))) then
          no ("a run after a check does not print hello and 42: " ^ firstLine (g "run.log"))
        else if not compiled then no ("a compile after a run fails: " ^ firstLine (g "compile.log"))
        else
          (expect ("a run after a check", g "run.log", [("Lib", "taken"), ("Main", "taken")]);
           expect ("a compile after a run", g "compile.log", [("Lib", "taken"), ("Main", "taken"), ("link", "compiled")]);
           if samePrograms (f "a.rbc", g "a.rbc") then () else no "the program after a check is not a plain compile's")
      (* none, and another *)
      val n = out ^ "/default-none"
      fun h x = n ^ "/" ^ x
      val () = drived n
      val none = rhcIn (n, NONE, ["--no-store", "Main.hs", "-o", "a.rbc"], "none.log") = 0
      val empty = rhcIn (n, SOME "", ["Main.hs", "-o", "b.rbc"], "empty.log") = 0
      val emptyCheck = rhcIn (n, SOME "", ["--typecheck-only", "Main.hs"], "emptycheck.log") = 0
      val nothing = written n
      val other = rhcIn (n, SOME (h "other"), ["Main.hs", "-o", "c.rbc"], "other.log") = 0
      val both = rhcIn (n, SOME (h "other"), ["--no-store", "--show-units", "Main.hs", "-o", "d.rbc"], "both.log") = 0
    in
      if not none then no ("a compile with --no-store fails: " ^ firstLine (h "none.log"))
      else if not empty then no ("a compile with RHC_STORE empty fails: " ^ firstLine (h "empty.log"))
      else if not emptyCheck then no ("a check with RHC_STORE empty fails: " ^ firstLine (h "emptycheck.log"))
      else if not (null nothing) then no ("--no-store or an empty RHC_STORE writes " ^ String.concatWith " " nothing)
      else if not other then no ("a compile with RHC_STORE set fails: " ^ firstLine (h "other.log"))
      else if not both then no ("a compile with --no-store and RHC_STORE fails: " ^ firstLine (h "both.log"))
      else
        (if written n = ["other"] andalso isDir (h "other") then ()
         else no ("RHC_STORE's store is not the one written: " ^ String.concatWith " " (written n));
         expect ("--no-store over RHC_STORE", h "both.log", [("Lib", "compiled"), ("Main", "compiled")]);
         if List.all (fn x => samePrograms (f "a.rbc", h x)) ["a.rbc", "b.rbc", "c.rbc", "d.rbc"] then ()
         else no "a compile without the store is not the one with it")
    end

  (* Two compiles at once on one .rhc (D58), as two rune builds on one
     .rune: each entry is written whole or not at all (UnitStore.publish,
     a file renamed into place), so both compile, whichever writes first,
     their programs the same and a plain compile's, and a third takes
     every unit and the link from what they kept. Twice, each round on a
     store of its own *)
  fun concurrent () =
    let
      fun no why = say ("FAIL hs.units.concurrent: " ^ why ^ "\n")
      fun round k =
        let
          val d = out ^ "/concurrent-" ^ Int.toString k
          fun f x = d ^ "/" ^ x
          val () = drived d
          val rhc = fromRoot "bin/rhc"
          val script =
            "\"$0\" --show-units Main.hs -o a.rbc > a.log 2>&1 & a=$!; " ^
            "\"$0\" --show-units Main.hs -o b.rbc > b.log 2>&1 & b=$!; " ^
            "wait $a; sa=$?; wait $b; sb=$?; echo \"$sa $sb\" > statuses"
          val () = ignore (execEnv (unsetEnv ["RHC_STORE"])
                                   {cmd = ["sh", "-c", script, rhc], dir = SOME d, stdin = "", stdout = f "both.log",
                                    stderr = f "both.log", timeout = 1200})
          val statuses = String.tokens Char.isSpace (read (f "statuses"))
          val third = rhcIn (d, NONE, ["--show-units", "Main.hs", "-o", "c.rbc"], "c.log") = 0
          val plain = exec {cmd = [rhc, "--no-store", "Main.hs", "-o", "p.rbc"], dir = SOME d, stdin = "", stdout = f "p.log",
                            stderr = f "p.log", timeout = 900} = 0
          val text = read (f "c.log")
        in
          if statuses <> ["0", "0"] then
            no ("round " ^ Int.toString k ^ ": the compiles at once end with " ^ String.concatWith " " statuses ^ ": "
                ^ firstLine (f "a.log") ^ "; " ^ firstLine (f "b.log"))
          else if not third then no ("round " ^ Int.toString k ^ ": the compile after them fails: " ^ firstLine (f "c.log"))
          else if not plain then no ("round " ^ Int.toString k ^ ": the compile without a store fails: " ^ firstLine (f "p.log"))
          else
            ((if List.all (fn u => saysOf (text, u) = ["taken"]) ["Lib", "Main", "link"] then ()
              else no ("round " ^ Int.toString k ^ ": the compile after them does not take every unit and the link: "
                       ^ String.concatWith "; " (List.filter (String.isPrefix "rhc: ") (lines text))));
             if List.all (fn x => samePrograms (f "p.rbc", f x)) ["a.rbc", "b.rbc", "c.rbc"] then ()
             else no ("round " ^ Int.toString k ^ ": the programs of the compiles at once are not one"))
        end
    in
      round 1; round 2
    end

  (* The link's memo across the back end's settings (build-cache-issues.md,
     issue 29): Main and Lib of tests/hs/units/drive through one store, at
     each level, for each instruction set and without the strictness pass,
     in an order that comes back to each. Each program is the bytes a
     compile of the same options without a store gives; the link is taken
     where a compile before had the same options, compiled where none had,
     and neither kept nor taken without the strictness pass, whose option
     the memo's configuration does not hold *)
  fun memo () =
    let
      fun no why = say ("FAIL hs.units.memo: " ^ why ^ "\n")
      val d = out ^ "/memo"
      fun f x = d ^ "/" ^ x
      val () = drived d
      val runs = [["-O1"], ["-O0"], ["-O2"], ["-O1", "--target=stack"], ["-O2", "--strictness=off"], ["-O0", "--target=stack"],
                  ["-O2"], ["-O1"], ["-O2", "--strictness=off"], ["-O0", "--target=stack"], ["-O0"]]
      fun one (k, flags) =
        let
          val label = "step " ^ Int.toString (k + 1) ^ " (" ^ String.concatWith " " flags ^ ")"
          val warm = rhcIn (d, NONE, flags @ ["--store", "st", "--show-units", "Main.hs", "-o", "w.rbc"], "w.log") = 0
          val cold = rhcIn (d, NONE, flags @ ["--no-store", "Main.hs", "-o", "c.rbc"], "c.log") = 0
          val said = List.filter (fn w => w <> "reached") (saysOf (read (f "w.log"), "link"))
          val kept = not (List.exists (fn a => a = "--strictness=off") flags)
          val seen = List.exists (fn g => g = flags) (List.take (runs, k))
          val want = if not kept then [] else if seen then ["taken"] else ["compiled"]
        in
          if not warm then no (label ^ ": the compile through the store fails: " ^ firstLine (f "w.log"))
          else if not cold then no (label ^ ": the compile without a store fails: " ^ firstLine (f "c.log"))
          else
            ((if bytesOf (f "w.rbc") = bytesOf (f "c.rbc") then ()
              else no (label ^ ": the program through the store is not the one without it"));
             if said = want then ()
             else no (label ^ ": the link " ^ (case said of [] => "neither compiled nor taken" | w :: _ => w) ^ ", where "
                      ^ (case want of [] => "neither" | w :: _ => w) ^ " is wanted"))
        end
      fun go (_, []) = ()
        | go (k, flags :: rest) = (one (k, flags); go (k + 1, rest))
    in
      go (0, runs)
    end

  (* An entry damaged (build-cache-issues.md, issue 28): Main and Lib of
     tests/hs/units/drive compiled through a store, then each entry of it
     (its units', its modules' headers', its link's) given one byte flipped,
     in its head, in its middle and at its end, and a compile after each:
     it compiles, to the bytes of the first, the entry refused and what it
     held compiled again, never taken and never a crash. Then the store as
     a layer, read only, under an overlay of its own: a compile that takes
     a damaged part of a layer's entry, which it cannot take back, stops
     and says so, or compiles to the same bytes *)
  fun damaged () =
    let
      fun no why = say ("FAIL hs.units.damaged: " ^ why ^ "\n")
      val d = out ^ "/damaged"
      fun f x = d ^ "/" ^ x
      val () = drived d
      fun writeBytes (p, b) = let val o' = BinIO.openOut p in BinIO.output (o', Byte.stringToBytes b); BinIO.closeOut o' end
      fun flipped (b, at) =
        String.substring (b, 0, at) ^ str (Char.chr (Word.toInt (Word.xorb (Word.fromInt (Char.ord (String.sub (b, at))), 0w32))))
        ^ String.extract (b, at + 1, NONE)
      (* the entries of a store: a file of a key's directory, in a
         configuration's, not its units/ or the memo's *)
      fun entriesOf st =
        List.concat
          (List.map (fn c => if c = "memo" orelse not (isDir (st ^ "/" ^ c)) then []
                             else List.concat (List.map (fn k => if k = "units" orelse not (isDir (st ^ "/" ^ c ^ "/" ^ k)) then []
                                                                 else List.map (fn e => st ^ "/" ^ c ^ "/" ^ k ^ "/" ^ e)
                                                                        (sort (entries (st ^ "/" ^ c ^ "/" ^ k))))
                                                (sort (entries (st ^ "/" ^ c)))))
             (sort (entries st)))
      val first = rhcIn (d, NONE, ["--store", "st", "Main.hs", "-o", "a.rbc"], "a.log") = 0
      val want = bytesOf (f "a.rbc")
      fun each (p, args, log, layered) =
        let
          val b = bytesOf p
          fun at k =
            let
              val () = if layered then rmTree (f "overlay") else ()
              val () = writeBytes (p, flipped (b, k))
              val ok = rhcIn (d, NONE, args @ ["Main.hs", "-o", "x.rbc"], log) = 0
              val text = read (f log)
              val label = OS.Path.file (OS.Path.dir p) ^ "/" ^ OS.Path.file p ^ " flipped at " ^ Int.toString k
            in
              (if ok then (if bytesOf (f "x.rbc") = want then () else no (label ^ ": the program is not the one compiled first"))
               else if layered andalso String.isSubstring "holds a damaged entry" text then ()
               else no (label ^ ": the compile fails: " ^ firstLine (f log)));
              writeBytes (p, b)
            end
        in
          if size b < 8 then () else List.app at [20, size b div 2, size b - 2]
        end
    in
      if not first then no ("the first compile fails: " ^ firstLine (f "a.log"))
      else
        (List.app (fn p => each (p, ["--store", "st"], "x.log", false)) (entriesOf (f "st"));
         List.app (fn p => each (p, ["--layer", "st", "--store", "overlay"], "y.log", true)) (entriesOf (f "st")))
    end

  (* --verify-store (build-cache-issues.md, issue 6, rhc's): Main and Lib
     of tests/hs/units/drive through a store, which --verify-store then
     finds to hold what compiling gives; then Lib's body edited and Lib's
     entry made again over the first's, planted as Rune's S55 plants one:
     an entry whose usages hold and whose content is another compile's. A
     compile through the store takes it and prints what the first Lib
     made; --verify-store refuses it, naming Lib *)
  fun verified () =
    let
      fun no why = say ("FAIL hs.units.verify: " ^ why ^ "\n")
      val d = out ^ "/verify"
      fun f x = d ^ "/" ^ x
      val () = drived d
      fun rhc (args, log) = rhcIn (d, NONE, ["--store", "st", "--show-units"] @ args @ ["Main.hs", "-o", "w.rbc"], log) = 0
      fun files () =
        List.concat
          (List.map (fn c => if c = "memo" orelse not (isDir (f ("st/" ^ c))) then []
                             else List.concat (List.map (fn k => if k = "units" orelse not (isDir (f ("st/" ^ c ^ "/" ^ k))) then []
                                                                 else List.map (fn e => "st/" ^ c ^ "/" ^ k ^ "/" ^ e)
                                                                        (sort (entries (f ("st/" ^ c ^ "/" ^ k)))))
                                                (sort (entries (f ("st/" ^ c))))))
             (sort (entries (f "st"))))
      (* the entry of Lib's unit: the one whose removal makes Lib's unit
         compiled again *)
      fun libEntry () =
        List.find (fn p =>
                     let
                       val b = bytesOf (f p)
                       val () = OS.FileSys.remove (f p)
                       val _ = rhc ([], "find.log")
                       val () = let val o' = BinIO.openOut (f p) in BinIO.output (o', Byte.stringToBytes b); BinIO.closeOut o' end
                     in
                       saysOf (read (f "find.log"), "Lib") = ["compiled"]
                     end)
                  (files ())
      fun printed () = (ignore (exec {cmd = [fromRoot "bin/runevm", f "w.rbc"], dir = SOME d, stdin = "", stdout = f "w.out",
                                      stderr = f "w.out", timeout = 300});
                        read (f "w.out"))
      val first = rhc ([], "first.log")
      val good = rhc (["--verify-store"], "good.log")
      val e1 = libEntry ()
      val old = Option.map (fn p => bytesOf (f p)) e1
      val t = read (f "Lib.hs")
      val edited = let val (a, b) = Substring.position "x + x" (Substring.full t)
                   in Substring.string a ^ "x * 3" ^ String.extract (Substring.string b, 5, NONE) end
      val () = write (f "Lib.hs", edited)
      val second = rhc ([], "second.log")
      val e2 = libEntry ()
    in
      if not first then no ("the first compile fails: " ^ firstLine (f "first.log"))
      else if not good then no ("--verify-store refuses a store as compiled: " ^ firstLine (f "good.log"))
      else if not second then no ("the compile after the edit fails: " ^ firstLine (f "second.log"))
      else
        case (e1, old, e2) of
          (SOME p1, SOME b1, SOME p2) =>
            if p1 = p2 then no "Lib's entry is the same file before and after its edit"
            else
              let
                val () = let val o' = BinIO.openOut (f p2) in BinIO.output (o', Byte.stringToBytes b1); BinIO.closeOut o' end
                val planted = rhc ([], "planted.log")
                val shows = printed ()
                val checked = rhc (["--verify-store"], "checked.log")
                val text = read (f "checked.log")
              in
                if not planted then no ("the compile of the planted entry fails: " ^ firstLine (f "planted.log"))
                else if saysOf (read (f "planted.log"), "Lib") <> ["taken"] then no "the planted entry is not taken"
                else if shows <> "hello\n42\n" then no ("the planted entry's program prints " ^ firstLine (f "w.out")
                                                         ^ ", where the first Lib's 42 is wanted")
                else if checked then no "--verify-store takes the planted entry"
                else if not (String.isSubstring "--verify-store" text andalso String.isSubstring "Lib:" text) then
                  no ("--verify-store refuses it otherwise than naming Lib: " ^ firstLine (f "checked.log"))
                else ()
              end
        | _ => no "Lib's entry is not found in the store"
    end

  (* The store trimmed (build-cache-issues.md, issue 34): Main and Lib of
     tests/hs/units/drive through a store, every file of which is then
     made nine days old, past the week a trim keeps what no compile took,
     and its last trim with it. The next compile takes the units and the
     link, the trim that is due running after them, and the store keeps
     them, so that the compile after takes them all again *)
  fun trimmed () =
    let
      fun no why = say ("FAIL hs.units.trim: " ^ why ^ "\n")
      val d = out ^ "/trim"
      fun f x = d ^ "/" ^ x
      val () = drived d
      val old = Time.- (Time.now (), Time.fromSeconds (9 * 86400))
      fun age p = if isDir p then List.app (fn n => age (p ^ "/" ^ n)) (entries p)
                  else OS.FileSys.setTime (p, SOME old) handle OS.SysErr _ => ()
      fun rhc log = rhcIn (d, NONE, ["--store", "st", "--show-units", "Main.hs", "-o", "w.rbc"], log) = 0
      val first = rhc "first.log"
      val () = age (f "st")
      val aged = rhc "aged.log"
      val again = rhc "again.log"
      fun all (log, what) = List.all (fn u => saysOf (read (f log), u) = [what]) ["Lib", "Main", "link"]
    in
      if not first then no ("the first compile fails: " ^ firstLine (f "first.log"))
      else if not aged then no ("the compile after a week fails: " ^ firstLine (f "aged.log"))
      else if not again then no ("the compile after it fails: " ^ firstLine (f "again.log"))
      else
        ((if all ("aged.log", "taken") then ()
          else no ("the compile after a week does not take every unit and the link: "
                   ^ String.concatWith "; " (List.filter (String.isPrefix "rhc: unit L") (lines (read (f "aged.log")))
                                             @ List.filter (String.isPrefix "rhc: link") (lines (read (f "aged.log"))))));
         if all ("again.log", "taken") then () else no "the compile after it does not take every unit and the link")
    end

  (* A store's entries read by a bin/rhc elsewhere (build-cache-issues.md,
     issue 31): Main and Lib of tests/hs/units/drive through a store, then a
     bin/rhc whose library is another copy, at another path (its share/rhc
     copied into the job's directory, its bytecode, VM and snapshot the
     tree's): it takes every unit and the link from the store, to the same
     program, and --verify-store holds every entry it takes, the snapshot's
     library among them, to what it makes of its own copy, the places of an
     entry being kept by their modules and not by the paths they were read
     from *)
  fun elsewhere () =
    let
      fun no why = say ("FAIL hs.units.elsewhere: " ^ why ^ "\n")
      val d = out ^ "/elsewhere"
      fun f x = d ^ "/" ^ x
      val () = drived d
      val copy = f "copy"
      fun sh cmd = exec {cmd = ["sh", "-c", cmd], dir = SOME d, stdin = "", stdout = f "copy.log", stderr = f "copy.log",
                         timeout = 300} = 0
      val bin = fromRoot "bin"
      val made =
        sh ("mkdir -p copy/bin copy/share && cp -R '" ^ fromRoot "share/rhc" ^ "' copy/share/rhc && cp '" ^ bin ^ "/rhc' copy/bin/rhc"
            ^ " && ln -s '" ^ bin ^ "/rhc.rbc' copy/bin/rhc.rbc && ln -s '" ^ bin ^ "/runevm' copy/bin/runevm"
            ^ " && ln -s '" ^ bin ^ "/rhc.layer' copy/bin/rhc.layer")
      fun rhc (which, args, log) =
        execEnv (unsetEnv ["RHC_STORE"])
          {cmd = [which] @ args @ ["Main.hs", "-o", log ^ ".rbc"], dir = SOME d, stdin = "", stdout = f (log ^ ".log"),
           stderr = f (log ^ ".log"), timeout = 900} = 0
      val first = rhc (fromRoot "bin/rhc", ["--store", "st"], "first")
      val there = rhc (copy ^ "/bin/rhc", ["--store", "st", "--show-units"], "there")
      val verified = rhc (copy ^ "/bin/rhc", ["--store", "st", "--verify-store"], "verified")
    in
      if not made then no ("the copy of rhc is not made: " ^ firstLine (f "copy.log"))
      else if not first then no ("the first compile fails: " ^ firstLine (f "first.log"))
      else if not there then no ("the compile of the copy fails: " ^ firstLine (f "there.log"))
      else if not verified then no ("--verify-store of the copy refuses: " ^ firstLine (f "verified.log"))
      else
        ((if List.all (fn u => saysOf (read (f "there.log"), u) = ["taken"]) ["Lib", "Main", "link"] then ()
          else no "the copy does not take every unit and the link from the store");
         if bytesOf (f "first.rbc") = bytesOf (f "there.rbc") andalso bytesOf (f "first.rbc") = bytesOf (f "verified.rbc") then ()
         else no "the copy's programs are not the first's")
    end

  (* a store shared by compiles of one program at other levels of the
     lint, optimisations and fixpoints of a cycle's exports, each through
     one store and a twin of it whose hits are judged by every usage asked
     (RHC_HIT=asked): each unit and the link taken or made alike, and the
     program the build without a store's (build-cache-issues.md, issue
     37's B: a digest of the units before is no hit at a level its entry
     was not checked at) *)
  fun configs () =
    let
      fun no why = say ("FAIL hs.units.configs: " ^ why ^ "\n")
      val d = out ^ "/configs"
      fun f x = d ^ "/" ^ x
      val () = (rmTree d; mkdirs d)
      (* a cycle whose exports name each other's entities: a cycle that
         exports itself by `module M` exports, at the greatest fixpoint,
         every entity of the program, the library's two of some names
         among them, and is refused (5.2) *)
      val () = write (f "A.hs", "module A (a, b) where\n\nimport B\n\na :: Int\na = 1\n")
      val () = write (f "B.hs", "module B (b) where\n\nimport A\n\nb :: Int\nb = a + 1\n")
      val () = write (f "C.hs", "module C (c) where\n\nimport A\n\nc :: Int\nc = a + b\n")
      val () = write (f "Main.hs", "module Main where\n\nimport C\n\nmain :: IO ()\nmain = print c\n")
      fun rhc (env, args, log) =
        execEnv (fn e => env @ unsetEnv ["RHC_STORE", "RHC_HIT"] e)
          {cmd = [fromRoot "bin/rhc"] @ args @ ["Main.hs", "-o", log ^ ".rbc"], dir = SOME d, stdin = "",
           stdout = f (log ^ ".log"), stderr = f (log ^ ".log"), timeout = 900} = 0
      fun verdicts log =
        List.mapPartial (fn l => case String.tokens Char.isSpace l of
                                   "rhc:" :: "unit" :: name :: what :: _ => SOME (name ^ " " ^ wordOf what)
                                 | "rhc:" :: "link:" :: what :: _ => SOME ("link " ^ wordOf what)
                                 | _ => NONE)
          (lines (read (f (log ^ ".log"))))
      val settings = [["--lint=0"], ["--lint=2"], ["--lint=0"], ["--lint=2", "-O2"], ["-O2"], ["--names=greatest"],
                      ["--names=least"], ["--names=greatest", "--lint=2"], ["--lint=0"]]
      fun one (i, opts) =
        let
          val n = Int.toString i
          val warm = rhc ([], opts @ ["--store", "st", "--show-units"], "warm" ^ n)
          val asked = rhc (["RHC_HIT=asked"], opts @ ["--store", "st-asked", "--show-units"], "asked" ^ n)
          val cold = rhc ([], opts @ ["--no-store"], "cold" ^ n)
          val what = String.concatWith " " opts
        in
          if not (warm andalso asked andalso cold) then no (what ^ ": a compile fails: " ^ firstLine (f ("warm" ^ n ^ ".log")))
          else if verdicts ("warm" ^ n) <> verdicts ("asked" ^ n) then
            no (what ^ ": a unit is taken or made otherwise than where every usage is asked: "
                ^ String.concatWith ", " (verdicts ("warm" ^ n)) ^ "; asked: " ^ String.concatWith ", " (verdicts ("asked" ^ n)))
          else if String.extract (bytesOf (f ("warm" ^ n ^ ".rbc")), 12, NONE)
                  <> String.extract (bytesOf (f ("cold" ^ n ^ ".rbc")), 12, NONE) then
            no (what ^ ": the program is not the build without a store's")
          else ()
        end
    in
      ListPair.app one (List.tabulate (length settings, fn i => i + 1), settings)
    end

  (* an import's exports moved where the unit that imports it names
     nothing of what moved: the unit stands by its usages, its scope's
     usages, digests of what it imports, as they were made, and
     --verify-store holds it to what compiling it gives but those, which are
     no part of what it is made of (build-cache-issues.md, issue 37's A) *)
  fun verifyScopes () =
    let
      fun no why = say ("FAIL hs.units.verify-scopes: " ^ why ^ "\n")
      val d = out ^ "/verify-scopes"
      fun f x = d ^ "/" ^ x
      val () = drived d
      fun rhc (args, log) = rhcIn (d, NONE, ["--store", "st", "--show-units"] @ args @ ["Main.hs", "-o", "w.rbc"], log) = 0
      val first = rhc ([], "first.log")
      val () = write (f "Lib.hs", String.concat (List.map (fn l => if String.isPrefix "module Lib" l then "module Lib (double, greeting, triple) where\n"
                                                                   else l ^ "\n")
                                                         (String.fields (fn c => c = #"\n") (read (f "Lib.hs"))))
                                  ^ "triple :: Int -> Int\ntriple x = 3 * x\n")
      val second = rhc ([], "second.log")
      val verified = rhc (["--verify-store"], "verified.log")
    in
      if not first then no ("the first compile fails: " ^ firstLine (f "first.log"))
      else if not second then no ("the compile after Lib grows fails: " ^ firstLine (f "second.log"))
      else if saysOf (read (f "second.log"), "Main") <> ["taken"] then
        no "Main, which names nothing Lib gained, is not taken"
      else if not verified then no ("--verify-store refuses: " ^ firstLine (f "verified.log"))
      else ()
    end

  (* Main's Core imports a polymorphic value of Lib's, its type variables
     numbered by what Lib's check took before it, and copies a type of
     Lib's, its parameter named as Lib's source writes it: Lib gains a value
     of its own before the one Main takes, then its type's parameter is
     renamed, so that Main is taken, and --verify-store, compiling both,
     holds Main's entry to what compiling it gives after each; then Main's
     comment edited: Main compiled is the Core it was, and the link, kept by
     its units' Core, is taken. A value's type and a type's declaration,
     what Lib gives Main, with their variables named by place make it so
     (build-cache-issues.md, issue 40) *)
  fun verifyOrder () =
    let
      fun no why = say ("FAIL hs.units.verify-order: " ^ why ^ "\n")
      val d = out ^ "/verify-order"
      fun f x = d ^ "/" ^ x
      val main = "module Main (main) where\n\nimport Lib\n\nmain :: IO ()\nmain = print (unbox (Box (twice double 5)))\n"
      fun lib (more, p) =
        "module Lib (Box (..), double, twice, unbox) where\n\ndata Box " ^ p ^ " = Box " ^ p ^ "\n\nunbox :: Box c -> c\n"
        ^ "unbox (Box x) = x\n\ndouble :: Int -> Int\ndouble x = x + x\n\n" ^ more
        ^ "twice :: (a -> a) -> a -> a\ntwice g = g . g\n"
      val pairUp = "pairUp :: a -> b -> (a, b)\npairUp x y = (x, y)\n\n"
      val () = (rmTree d; mkdirs d; write (f "Lib.hs", lib ("", "a")); write (f "Main.hs", main))
      fun rhc (args, log) = rhcIn (d, NONE, ["--store", "st", "--show-units"] @ args @ ["Main.hs", "-o", "w.rbc"], log) = 0
      (* Lib edited by `edit`, Main taken, and the store held by --verify-store *)
      fun step (edit, what) =
        let
          val () = write (f "Lib.hs", edit)
          val log = what ^ ".log"
        in
          if not (rhc ([], log)) then (no ("the compile after Lib " ^ what ^ " fails: " ^ firstLine (f log)); false)
          else if saysOf (read (f log), "Main") <> ["taken"] then (no ("Main is not taken after Lib " ^ what); false)
          else if not (rhc (["--verify-store"], what ^ "-verified.log")) then
            (no ("--verify-store refuses after Lib " ^ what ^ ": "
                 ^ getOpt (List.find (String.isSubstring "--verify-store:") (lines (read (f (what ^ "-verified.log")))),
                           firstLine (f (what ^ "-verified.log"))));
             false)
          else true
        end
    in
      if not (rhc ([], "first.log")) then no ("the first compile fails: " ^ firstLine (f "first.log"))
      else if not (step (lib (pairUp, "a"), "grows")) then ()
      else if not (step (lib (pairUp, "b"), "renames")) then ()
      else
        let
          val () = write (f "Main.hs", "-- Main, its comment edited\n" ^ main)
          val third = rhc ([], "comment.log")
          val text = read (f "comment.log")
        in
          if not third then no ("the compile after Main's comment is edited fails: " ^ firstLine (f "comment.log"))
          else if saysOf (text, "Main") <> ["compiled"] then no "Main, its comment edited, is not compiled"
          else if saysOf (text, "link") <> ["taken"] then
            no ("the link is not taken: Main compiled is other Core than its entry's ("
                ^ String.concatWith ", " (saysOf (text, "link")) ^ ")")
          else ()
        end
    end

  fun command args =
    case args of
      ["hs-units-drive"] => SOME drive
    | ["hs-units-verify-scopes"] => SOME verifyScopes
    | ["hs-units-verify-order"] => SOME verifyOrder
    | ["hs-units-configs"] => SOME configs
    | ["hs-units-elsewhere"] => SOME elsewhere
    | ["hs-units-trim"] => SOME trimmed
    | ["hs-units-verify"] => SOME verified
    | ["hs-units-memo"] => SOME memo
    | ["hs-units-damaged"] => SOME damaged
    | ["hs-units-default"] => SOME defaultStore
    | ["hs-units-concurrent"] => SOME concurrent
    | ["hs-units-hole", c] => SOME (hole c)
    | ["hs-units-snapshot"] => SOME snapshot
    | ["hs-units-random", c] => SOME (random c)
    | ["hs-units-abi"] => SOME abi
    | ["hs-units-warm-whole"] => SOME warmWhole
    | ["hs-units-warm"] => SOME warm
    | ["hs-units-store"] => SOME store
    | ["hs-units-named"] => SOME named
    | ["hs-units-core", src] => SOME (fn () => coreOne src)
    | _ => NONE

  val covers = ["covers:src/rhc/store.sml", "covers:src/rhc/units.sml", "covers:src/rhc/driver.sml", "covers:lib/compiler/driver/unitstore.sml",
                "covers:src/rhc/storeconfig.sml", "covers:src/rhc/syntax.sml", "covers:lib/compiler/driver/storepolicy.sml",
                "covers:lib/compiler/core/midtext.sml", "covers:lib/language/haskell/coretomid.sml",
                "covers:tests/hs/units/*",
                "covers:tests/runner/hsunits.sml"]
  fun tree () =
    let
      fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
      val checks =
        [Tools.job ("store", ["hs-units-store"], [], 300, 600), Tools.job ("named", ["hs-units-named"], [], 500, 1200),
         Tools.job ("warm", ["hs-units-warm"], [], 500, 1800), Tools.job ("abi", ["hs-units-abi"], [], 300, 600),
         Tools.job ("warm-whole", ["hs-units-warm-whole"], [], 500, 1800), Tools.job ("drive", ["hs-units-drive"], [], 600, 3600),
         Tools.job ("snapshot", ["hs-units-snapshot"], [], 600, 2400),
         Tools.job ("default", ["hs-units-default"], [], 600, 3600), Tools.job ("concurrent", ["hs-units-concurrent"], [], 600, 3600),
         Tools.job ("memo", ["hs-units-memo"], [], 600, 3600), Tools.job ("damaged", ["hs-units-damaged"], [], 600, 3600),
         Tools.job ("verify", ["hs-units-verify"], [], 600, 3600), Tools.job ("trim", ["hs-units-trim"], [], 600, 3600),
         Tools.job ("elsewhere", ["hs-units-elsewhere"], [], 600, 3600),
         Tools.job ("configs", ["hs-units-configs"], [], 900, 3600),
         Tools.job ("verify-scopes", ["hs-units-verify-scopes"], [], 300, 900),
         Tools.job ("verify-order", ["hs-units-verify-order"], [], 300, 900)]
        @ List.map (fn c => Tools.job ("holes/" ^ c, ["hs-units-hole", c], [], 600, 3600)) (holeCases ())
        @ List.map (fn s => Tools.job ("core/" ^ HsCore.nameOf s, ["hs-units-core", s], [], 500, 1200)) (coreTests ())
      val nightly = List.map (fn c => Tools.job ("random/" ^ c, ["hs-units-random", c], [], 900, 3600)) (holeCases ())
    in
      tagged covers
        (Test.describe "hs/units" (List.map (tagged ["check", "test-rhc"]) checks @ List.map (tagged ["nightly", "test-rhc"]) nightly))
    end
end

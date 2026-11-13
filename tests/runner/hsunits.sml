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
          val ok = exec {cmd = [fromRoot "bin/rhc", "--lint=2", "--units", "--store", "st", "--show-units", "Main.hs", "-o", "w.rbc"],
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
      step ("cold", [("library", "compiled"), ("Lib", "compiled"), ("Main", "compiled"), ("link", "compiled")], "hello\n42\n");
      step ("again", [("library", "taken"), ("Lib", "taken"), ("Main", "taken"), ("link", "taken")], "hello\n42\n");
      edit ("Lib.hs", "double x = x + x", "double x = 2 * x");
      step ("body", [("library", "taken"), ("Lib", "compiled"), ("Main", "taken"), ("link", "compiled")], "hello\n42\n");
      edit ("Lib.hs", "module Lib (double, greeting) where", "module Lib (double, greeting, triple) where\n\ntriple :: Int -> Int\ntriple x = 3 * x");
      step ("export", [("library", "taken"), ("Lib", "compiled"), ("Main", "taken")], "hello\n42\n");
      edit ("Lib.hs", "double :: Int -> Int", "double :: Integer -> Integer");
      step ("type", [("library", "taken"), ("Lib", "compiled"), ("Main", "compiled"), ("link", "compiled")], "hello\n42\n")
    end

  (* E13's holes (the haskell98 roadmap's *What a cache hit must satisfy*,
     H1 to H8; E13's two GHC cases among them): each case of
     tests/hs/units/holes a program and its steps, each step a directory of
     modules written over the last step's and `want`, what the program
     prints or `refused`. At each step the units' compile through one store
     (`--units --store`) and the whole compile of the same files both give
     what is wanted, and where they compile, the same program byte for
     byte. A hole planted (tests/runner/hsmutantlist.sml, HU01 to HU09)
     takes a unit whose compile would now refuse or make another program,
     and its case fails *)
  val holesDir = "tests/hs/units/holes"
  fun holeCases () = sort (List.filter (fn n => isDir (fromRoot (holesDir ^ "/" ^ n))) (entries (fromRoot holesDir)))

  (* a case's states: the k-th its steps 1 to k's modules, the later a
     module's text the one it has, and the k-th step's want *)
  fun statesOf name : (string * (string * string) list * string) list =
    let
      val src = fromRoot (holesDir ^ "/" ^ name)
      val steps = sort (List.filter (fn n => isDir (src ^ "/" ^ n)) (entries src))
      fun go ([], _, acc) = List.rev acc
        | go (s :: rest, files, acc) =
            let
              val mine = List.map (fn p => (OS.Path.file p, read p)) (glob (src ^ "/" ^ s, ".hs"))
              val files' = mine @ List.filter (fn (n, _) => not (List.exists (fn (m, _) => m = n) mine)) files
            in go (rest, files', (s, files', read (src ^ "/" ^ s ^ "/want")) :: acc) end
    in go (steps, [], []) end

  (* one state in d, through the store d/st: the units' compile and the
     whole compile give its want, a refusal for the same reason, and where
     they compile, the same program byte for byte; false where they do
     not, said *)
  fun stateHolds (family, d, label, files, want) =
    let
      fun f x = d ^ "/" ^ x
      val () = List.app (fn n => if String.isSuffix ".hs" n andalso not (List.exists (fn (m, _) => m = n) files)
                                 then OS.FileSys.remove (f n) else ()) (entries d)
      val () = List.app (fn (n, text) => write (f n, text)) files
      fun bytes p = (let val i = BinIO.openIn p in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
                    handle IO.Io _ => ""
      fun compiles (cmd, log) = exec {cmd = cmd, dir = SOME d, stdin = "", stdout = f log, stderr = f log, timeout = 900} = 0
      val warm = compiles ([fromRoot "bin/rhc", "--units", "--store", "st", "--show-units", "Main.hs", "-o", "w.rbc"], "warm.log")
      val whole = compiles ([fromRoot "bin/rhc", "Main.hs", "-o", "j.rbc"], "whole.log")
      fun units () = String.concatWith "; " (List.filter (String.isPrefix "rhc: unit") (lines (read (f "warm.log"))))
      fun no why = (say ("FAIL " ^ family ^ ": " ^ label ^ ": " ^ why ^ "\n"); false)
      (* the units' refusal, which the whole compile's must say too: a unit
         taken that should not be may make a link that does not check *)
      fun refusal () =
        case List.find (String.isPrefix "rhc: error: ") (lines (read (f "warm.log"))) of
          SOME l => String.extract (l, size "rhc: error: ", NONE)
        | NONE => firstLine (f "warm.log")
    in
      if want = "refused\n" then
        if warm then no ("the units' compile takes what the whole compile "
                         ^ (if whole then "takes too, where a refusal is wanted" else "refuses: " ^ firstLine (f "whole.log"))
                         ^ " (" ^ units () ^ ")")
        else if whole then no "the whole compile takes it, where a refusal is wanted"
        else if String.isSubstring (refusal ()) (read (f "whole.log")) then true
        else no ("the units' compile refuses it otherwise than the whole compile: " ^ refusal () ^ " (" ^ units () ^ ")")
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
            no ("the units' program is not the whole compile's (" ^ units () ^ ")")
          else if printed <> want then no ("printed " ^ firstLine (f "w.out") ^ ", where " ^ firstLine' want ^ " is wanted")
          else true
        end
    end
  and firstLine' s = case String.fields (fn c => c = #"\n") s of l :: _ => l | [] => ""

  (* E13's holes (the haskell98 roadmap's *What a cache hit must satisfy*,
     H1 to H8; E13's two GHC cases among them): each case of
     tests/hs/units/holes a program and its steps, each step a directory of
     modules written over the last step's and `want`, what the program
     prints or `refused`. At each step the units' compile through one store
     (`--units --store`) and the whole compile of the same files both give
     what is wanted, and where they compile, the same program byte for
     byte. A hole planted (tests/runner/hsmutantlist.sml, HU01 to HU09)
     takes a unit whose compile would now refuse or make another program,
     and its case fails *)
  fun hole name () =
    let
      val d = out ^ "/holes/" ^ name
      val () = (rmTree d; mkdirs d)
    in
      List.app (fn (s, files, want) => ignore (stateHolds ("hs.units.holes", d, name ^ " step " ^ s, files, want)))
        (statesOf name)
    end

  fun command args =
    case args of
      ["hs-units-drive"] => SOME drive
    | ["hs-units-hole", c] => SOME (hole c)
    | ["hs-units-abi"] => SOME abi
    | ["hs-units-warm-whole"] => SOME warmWhole
    | ["hs-units-warm"] => SOME warm
    | ["hs-units-store"] => SOME store
    | ["hs-units-named"] => SOME named
    | ["hs-units-core", src] => SOME (fn () => coreOne src)
    | _ => NONE

  val covers = ["covers:src/rhc/store.sml", "covers:src/rhc/units.sml", "covers:src/rhc/driver.sml", "covers:lib/compiler/driver/unitstore.sml",
                "covers:lib/compiler/core/midtext.sml", "covers:lib/language/haskell/coretomid.sml",
                "covers:tests/hs/units/*",
                "covers:tests/runner/hsunits.sml"]
  fun tree () =
    let
      fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
      val checks =
        [Tools.job ("store", ["hs-units-store"], [], 300, 600), Tools.job ("named", ["hs-units-named"], [], 500, 1200),
         Tools.job ("warm", ["hs-units-warm"], [], 500, 1800), Tools.job ("abi", ["hs-units-abi"], [], 300, 600),
         Tools.job ("warm-whole", ["hs-units-warm-whole"], [], 500, 1800), Tools.job ("drive", ["hs-units-drive"], [], 600, 3600)]
        @ List.map (fn c => Tools.job ("holes/" ^ c, ["hs-units-hole", c], [], 600, 3600)) (holeCases ())
        @ List.map (fn s => Tools.job ("core/" ^ HsCore.nameOf s, ["hs-units-core", s], [], 500, 1200)) (coreTests ())
    in
      tagged covers
        (Test.describe "hs/units" (List.map (tagged ["check", "test-rhc"]) checks))
    end
end

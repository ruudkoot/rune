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
  fun warm () =
    let
      val d = out ^ "/warm"
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
        exec {cmd = [fromRoot "bin/rhc", "--lint=2", "--units"] @ args, dir = SOME d, stdin = "", stdout = log, stderr = log,
              timeout = 600}
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
              else say ("FAIL hs.units.warm: " ^ label ^ ": printed " ^ firstLine (f (label ^ ".out")) ^ "\n")))
        end
      val three = ["base.core", "lib.core", "app.core"]
      fun all what = List.map (fn n => (n, what)) ["rhc-runtime", "base", "lib", "app"]
    in
      step ("cold", three, all "compiled", "18\n");
      step ("again", three, all "taken", "18\n");
      edit ("lib.core", "(prim int_add m m)", "(prim int_mul m 3)");
      step ("body", three, [("rhc-runtime", "taken"), ("base", "taken"), ("lib", "compiled"), ("app", "taken")], "27\n");
      edit ("lib.core", "(data Shape () (Square Int) (Rect Int Int))", "(data Shape () (Square Int) (Rect Int Int) (Tri Int))");
      step ("type", three, [("rhc-runtime", "taken"), ("base", "taken"), ("lib", "compiled"), ("app", "compiled")], "27\n");
      step ("latest", ["base.core", "lib.core", "mid.core", "app.core"],
            [("rhc-runtime", "taken"), ("base", "taken"), ("lib", "taken"), ("mid", "compiled"), ("app", "compiled")], "9\n");
      step ("without", three, all "taken", "27\n")
    end

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

  fun command args =
    case args of
      ["hs-units-abi"] => SOME abi
    | ["hs-units-warm"] => SOME warm
    | ["hs-units-store"] => SOME store
    | ["hs-units-named"] => SOME named
    | ["hs-units-core", src] => SOME (fn () => coreOne src)
    | _ => NONE

  val covers = ["covers:src/rhc/store.sml", "covers:src/rhc/units.sml", "covers:lib/compiler/driver/unitstore.sml",
                "covers:lib/compiler/core/midtext.sml", "covers:lib/language/haskell/coretomid.sml",
                "covers:tests/hs/units/*",
                "covers:tests/runner/hsunits.sml"]
  fun tree () =
    List.foldl (fn (tag, t) => Test.tag tag t)
      (Test.describe "hs/units"
         ([Tools.job ("store", ["hs-units-store"], [], 300, 600), Tools.job ("named", ["hs-units-named"], [], 500, 1200),
           Tools.job ("warm", ["hs-units-warm"], [], 500, 1800), Tools.job ("abi", ["hs-units-abi"], [], 300, 600)]
          @ List.map (fn s => Tools.job ("core/" ^ HsCore.nameOf s, ["hs-units-core", s], [], 500, 1200)) (coreTests ())))
      (["check", "test-rhc"] @ covers)
end

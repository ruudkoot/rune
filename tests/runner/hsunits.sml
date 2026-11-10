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
      val () = mkdirs out
      val o' = out ^ "/core-" ^ n
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

  fun command args =
    case args of
      ["hs-units-store"] => SOME store
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
         ([Tools.job ("store", ["hs-units-store"], [], 300, 600), Tools.job ("named", ["hs-units-named"], [], 500, 1200)]
          @ List.map (fn s => Tools.job ("core/" ^ HsCore.nameOf s, ["hs-units-core", s], [], 500, 1200)) (coreTests ())))
      (["check", "test-rhc"] @ covers)
end

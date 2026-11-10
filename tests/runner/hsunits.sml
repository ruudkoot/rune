(* rhc in units (the haskell98 roadmap's M21; docs/testing.md, rhc in
   units): rhc's entries in the store alone, RhcStore with a client of its
   own and no compiler, compiled with Pickle and UnitStore and nothing else
   (tests/hs/units/store.sml), as Rune's own store is tested
   (tests/lib/compiler/store.sml). *)
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

  fun command args =
    case args of
      ["hs-units-store"] => SOME store
    | _ => NONE

  val covers = ["covers:src/rhc/store.sml", "covers:lib/compiler/driver/unitstore.sml", "covers:tests/hs/units/*",
                "covers:tests/runner/hsunits.sml"]
  fun tree () =
    List.foldl (fn (tag, t) => Test.tag tag t)
      (Test.describe "hs/units" [Tools.job ("store", ["hs-units-store"], [], 300, 600)])
      (["check", "test-rhc"] @ covers)
end

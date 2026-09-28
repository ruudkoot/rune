(* Check.laws, as the programs of runedoc --laws use it (docs/plans/quickcheck.md,
   M8): a LAW line before each law, its report after, a last line that counts
   them, and RUNE_PROPERTY_ONLY to run one alone (tests/lib/run-lib-tests.sh
   runs it both ways). *)
val () = Check.laws [
  ("TEST.rev/law-1@List",
   fn () => Prop.equalIf (Arb.list IntArb.arb, Arb.list IntArb.arb)
     (fn _ => true, fn l => let open List in rev (rev l) end, fn l => l)),
  ("TEST.nth/law-1@List",
   fn () => Prop.holdsIf (Arb.list IntArb.arb)
     (fn l => not (List.null l), fn l => List.nth (l, 0) = hd l))]

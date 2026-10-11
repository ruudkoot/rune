(* The arbitrary of SML '90 input streams (docs/plans/quickcheck.md, M6). *)

(* Implements: SML90_ARB *)
structure SML90Arb :> SML90_ARB =
struct
  open PropertyScratch

  val instream : SML90.instream Arb.arb =
    {gen = Gen.map #1 (Gen.resource (Gen.map (fn s => let val name = scratch s in (SML90.open_in name, name) end) Gen.string,
                                     fn (i, name) => (SML90.close_in i handle _ => (); remove name))),
     show = fn _ => "(* an SML '90 stream of a file *)", co = fn _ => 0w0, eq = NONE}
end

(* WideTextArb: an arbitrary of the wide characters and their text that the
   Basis Library leaves optional, in a file of its own, so that a compiler
   without the structure builds the rest (it was in wide.sml;
   docs/plans/quickcheck.md, D10). *)

(* The arbitrary of the positions of wide text readers: that of a reader over
   a drawn wide string after a drawn number of its characters. *)
structure WideTextArb =
struct
  fun positionIn (s : WideString.string, k : int) : WideTextPrimIO.pos =
    case WideTextPrimIO.openVector s of
      WideTextPrimIO.RD {readVec = SOME read, getPos = SOME getPos, ...} => (ignore (read k); getPos ())
    | _ => raise Fail "a wide text reader of a vector with no readVec or getPos"

  val pos : WideTextPrimIO.pos Arb.arb =
    {gen = Gen.map positionIn (Gen.bind (#gen WideStringArb.arb)
                                        (fn s => Gen.map (fn k => (s, k)) (Gen.intRange (0, WideString.size s)))),
     show = fn _ => "(* the position of a wide text reader *)", co = fn _ => 0w0, eq = SOME (op =)}
end

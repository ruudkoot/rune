(* The arbitraries of the Basis Library's optional wide characters, strings
   and substrings (docs/plans/quickcheck.md, M6): `XArb.arb` is the arbitrary
   of the type of `X`. *)

(* Implements: ARB_OF where type t = WideChar.char *)
structure WideCharArb = CharArbFn (WideChar)
(* Implements: ARB_OF where type t = WideString.string *)
structure WideStringArb = StringArbFn (structure S = WideString val char = WideCharArb.arb)
(* Implements: ARB_OF where type t = WideSubstring.substring *)
structure WideSubstringArb =
  SubstringArbFn (structure S = WideSubstring val string = WideStringArb.arb val name = "WideSubstring")

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

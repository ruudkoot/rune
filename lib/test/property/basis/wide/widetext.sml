(* WideTextArb: an arbitrary of the wide characters and their text that the
   Basis Library leaves optional, in a file of its own, so that a compiler
   without the structure builds the rest (it was in wide.sml;
   docs/plans/quickcheck.md, D10). *)

(* The arbitraries of the positions of wide text readers, and of readers of
   wide characters: a reader over a drawn wide string, after a drawn number
   of its characters for a position. *)
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

  (* The arbitrary of readers of wide characters over a drawn wide string,
     whose stream is a position in it, as `BasisDataArb.reader` is of
     characters: from `i`, the reader gives the character at `i` and
     `i + 1`, and `NONE` outside the string, so that a stream it reads ends. *)
  fun readerOf (s : WideString.string) : (WideChar.char, int) StringCvt.reader =
    fn i => if i >= 0 andalso i < WideString.size s then SOME (WideString.sub (s, i), i + 1) else NONE

  (* a reader has no equality; the one of the string it was drawn from is
     not kept with it, so the printer shows the characters it reads from 0 *)
  fun contents (r : (WideChar.char, int) StringCvt.reader) : WideString.string =
    let fun go (i, acc) = case r i of SOME (c, j) => if j > i then go (j, c :: acc) else WideString.implode (List.rev (c :: acc))
                                    | NONE => WideString.implode (List.rev acc)
    in go (0, []) end

  val reader : (WideChar.char, int) StringCvt.reader Arb.arb =
    {gen = Gen.map readerOf (#gen WideStringArb.arb),
     show = fn r => let val s = contents r
                    in "(fn i => if i >= 0 andalso i < " ^ Int.toString (WideString.size s) ^ " then SOME (WideString.sub ("
                       ^ #show WideStringArb.arb s ^ ", i), i + 1) else NONE)"
                    end,
     co = fn r => #co WideStringArb.arb (contents r), eq = NONE}
end

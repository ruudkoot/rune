(* requires: Text Char String Substring CharVector CharArray CharVectorSlice CharArraySlice List *)
(* The Text structure (signature TEXT). https://smlfamily.github.io/Basis/text.html:
   "structure Text :> TEXT where type Char.char = Char.char where type
   String.string = String.string where type Substring.substring =
   Substring.substring where type CharVector.vector = CharVector.vector where
   type CharArray.array = CharArray.array where type CharVectorSlice.slice =
   CharVectorSlice.slice where type CharArraySlice.slice =
   CharArraySlice.slice". The substructures "based on the representation of the
   shared character type" work on the values of the top-level structures, and
   behave as those do; what the members do is checked in the tests of the
   top-level structures. *)
structure TestText =
struct
  val eqI = T.eq T.int
  val eqS = T.eq T.string
  val eqB = T.eq T.bool

  (* ---- Char ---- *)
  val () = eqI ("Text.Char/ord-of-a-char", 97, fn () => Text.Char.ord (#"a" : char))
  val () = T.eq T.char ("Text.Char/chr-is-a-char", #"a", fn () => (Text.Char.chr 97 : Char.char))
  val () = eqI ("Text.Char/maxOrd-is-that-of-Char", Char.maxOrd, fn () => Text.Char.maxOrd)
  val () = eqB ("Text.Char/same-functions", true,
                fn () => List.all (fn i => let val c = Char.chr i
                                           in Text.Char.toString c = Char.toString c
                                              andalso Text.Char.isAlpha c = Char.isAlpha c
                                              andalso Text.Char.toUpper c = Char.toUpper c end)
                                  (List.tabulate (256, fn i => i)))
  val () = T.raises ("Text.Char/chr-raises-Chr", T.isChr, fn () => Text.Char.chr 256)

  (* ---- String ---- *)
  val () = eqI ("Text.String/size-of-a-string", 3, fn () => Text.String.size ("abc" : string))
  val () = eqS ("Text.String/concat-is-a-string", "abcd", fn () => (Text.String.^ ("ab", "cd") : String.string))
  val () = eqS ("Text.String/same-functions", String.translate (fn c => String.str c ^ "-") "abc",
                fn () => Text.String.translate (fn c => Text.String.str c ^ "-") "abc")
  val () = T.eq T.char ("Text.String/char-is-char", #"b", fn () => (Text.String.sub ("abc", 1) : char))

  (* ---- Substring ---- *)
  val () = eqS ("Text.Substring/of-a-Substring.substring", "bc",
                fn () => Text.Substring.string (Substring.substring ("abcd", 1, 2)))
  val () = eqS ("Text.Substring/is-a-Substring.substring", "bc",
                fn () => Substring.string (Text.Substring.substring ("abcd", 1, 2)))
  val () = T.eq (T.triple (T.string, T.int, T.int)) ("Text.Substring/base", ("abcd", 2, 2),
                fn () => Substring.base (Text.Substring.triml 1 (Substring.extract ("abcd", 1, NONE))))

  (* ---- CharVector ---- *)
  val () = eqS ("Text.CharVector/vector-is-a-string", "abc", fn () => Text.CharVector.fromList [#"a", #"b", #"c"])
  val () = eqI ("Text.CharVector/of-a-CharVector.vector", 2, fn () => Text.CharVector.length (CharVector.fromList [#"a", #"b"]))
  val () = eqS ("Text.CharVector/is-a-CharVector.vector", "AB",
                fn () => CharVector.map Char.toUpper (Text.CharVector.tabulate (2, fn i => Char.chr (97 + i))))

  (* ---- CharArray ---- *)
  val () = eqS ("Text.CharArray/of-a-CharArray.array", "xyx",
                fn () => let val a = CharArray.array (3, #"x") in Text.CharArray.update (a, 1, #"y"); CharArray.vector a end)
  val () = eqS ("Text.CharArray/is-a-CharArray.array", "xyx",
                fn () => let val a = Text.CharArray.array (3, #"x") in CharArray.update (a, 1, #"y"); Text.CharArray.vector a end)
  val () = eqB ("Text.CharArray/same-array-is-equal", true,
                fn () => let val a = Text.CharArray.array (1, #"x") in (a : CharArray.array) = (a : Text.CharArray.array) end)

  (* ---- CharVectorSlice ---- *)
  val () = eqS ("Text.CharVectorSlice/of-a-CharVectorSlice.slice", "bc",
                fn () => Text.CharVectorSlice.vector (CharVectorSlice.slice ("abcd", 1, SOME 2)))
  val () = eqS ("Text.CharVectorSlice/is-a-CharVectorSlice.slice", "bc",
                fn () => CharVectorSlice.vector (Text.CharVectorSlice.slice ("abcd", 1, SOME 2)))
  (*<< substring *)
  val () = eqS ("Text.CharVectorSlice/is-a-substring", "bc",
                fn () => Text.Substring.string (Text.CharVectorSlice.slice ("abcd", 1, SOME 2)))
  val () = eqS ("Text.CharVectorSlice/of-a-substring", "bc",
                fn () => Text.CharVectorSlice.vector (Text.Substring.substring ("abcd", 1, 2)))
  (*>> substring *)

  (* ---- CharArraySlice ---- *)
  val () = eqS ("Text.CharArraySlice/of-a-CharArraySlice.slice", "xyyx",
                fn () => let val a = CharArray.array (4, #"x")
                         in Text.CharArraySlice.modify (fn _ => #"y") (CharArraySlice.slice (a, 1, SOME 2)); CharArray.vector a end)
  val () = eqS ("Text.CharArraySlice/is-a-CharArraySlice.slice", "xyyx",
                fn () => let val a = Text.CharArray.array (4, #"x")
                         in CharArraySlice.modify (fn _ => #"y") (Text.CharArraySlice.slice (a, 1, SOME 2)); Text.CharArray.vector a end)
  val () = eqS ("Text.CharArraySlice/copyVec-of-a-CharVectorSlice.slice", "-bc-",
                fn () => let val a = CharArray.array (4, #"-")
                         in Text.CharArraySlice.copyVec {src = CharVectorSlice.slice ("abcd", 1, SOME 2), dst = a, di = 1};
                            CharArray.vector a end)
end

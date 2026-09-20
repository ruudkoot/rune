(* requires: CharArraySlice CharArray CharVectorSlice CharVector Substring Char String List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml fn/mono_array_slice_fn.sml *)
(* CharArraySlice (signature MONO_ARRAY_SLICE, "where type vector =
   CharVector.vector where type vector_slice = CharVectorSlice.slice where type
   array = CharArray.array where type elem = char"): the checks that hold for
   every MONO_ARRAY_SLICE structure, from fn/mono_array_slice_fn.sml, on
   sample characters that include #"\000" and #"\255", and those of the type
   identities: the vector of a slice is a string, a vector slice a substring. *)
structure TestCharArraySlice =
struct
  val chars = Vector.fromList [#"\000", #"a", #"b", #"Z", #"\n", #" ", #"\127", #"\255"]
  structure Generic = TestMonoArraySliceFn (structure S = CharArraySlice structure A = CharArray structure V = CharVector structure VS = CharVectorSlice val name = "CharArraySlice" val elems = chars val show = T.char val same = op =)

  structure S = CharArraySlice
  val eqI = T.eq T.int
  val eqS = T.eq T.string
  fun ofString s = CharArray.fromList (String.explode s)

  (* ---- the vector of a slice is a string ---- *)
  val () = eqS ("CharArraySlice.vector/is-a-string", "cde", fn () => S.vector (S.slice (ofString "abcdefg", 2, SOME 3)))
  val () = eqS ("CharArraySlice.vector/empty-string", "", fn () => S.vector (S.slice (ofString "abc", 3, NONE)))
  val () = eqS ("CharArraySlice.vector/is-CharVector.vector", "abc", fn () => (S.vector (S.full (ofString "abc")) : CharVector.vector))
  val () = eqS ("CharArraySlice.update/string", "abcXefg",
                fn () => let val a = ofString "abcdefg" in S.update (S.slice (a, 2, SOME 3), 1, #"X"); CharArray.vector a end)
  val () = eqS ("CharArraySlice.modify/toUpper", "abCDEfg",
                fn () => let val a = ofString "abcdefg" in S.modify Char.toUpper (S.slice (a, 2, SOME 3)); CharArray.vector a end)
  val () = eqS ("CharArraySlice.modifyi/string-index", "ab0d2fg",
                fn () => let val a = ofString "abcdefg"
                         in S.modifyi (fn (i, c) => if i mod 2 = 0 then Char.chr (48 + i) else c) (S.slice (a, 2, SOME 3));
                            CharArray.vector a end)
  val () = eqS ("CharArraySlice.copy/to-CharArray", "--cde-",
                fn () => let val d = CharArray.array (6, #"-")
                         in S.copy {src = S.slice (ofString "abcdefg", 2, SOME 3), dst = d, di = 2}; CharArray.vector d end)
  val () = eqS ("CharArraySlice.copy/overlapping-string", "ababcfg",
                fn () => let val a = ofString "abcdefg" in S.copy {src = S.slice (a, 0, SOME 3), dst = a, di = 2}; CharArray.vector a end)
  val () = T.eq T.char ("CharArraySlice.sub/elem-is-char", #"d", fn () => (S.sub (S.slice (ofString "abcdefg", 2, SOME 3), 1) : char))
  val () = eqI ("CharArraySlice.sub/high-character", 255,
                fn () => Char.ord (S.sub (S.full (CharArray.array (1, Char.chr 255)), 0)))
  val () = T.eq T.order ("CharArraySlice.collate/high-characters", LESS,   (* ord: 127 < 255 *)
                         fn () => S.collate Char.compare (S.full (ofString "\127"), S.full (ofString "\255")))
  val () = T.check ("CharArraySlice.base/is-the-CharArray",
                    fn () => let val a = ofString "abcdefg" in #1 (S.base (S.slice (a, 3, SOME 4))) = (a : CharArray.array) end)

  (* ---- a vector slice is a CharVectorSlice.slice, which is a substring ---- *)
  val () = eqS ("CharArraySlice.copyVec/from-CharVectorSlice", "--cde-",
                fn () => let val d = CharArray.array (6, #"-")
                         in S.copyVec {src = CharVectorSlice.slice ("abcdefg", 2, SOME 3), dst = d, di = 2}; CharArray.vector d end)
  (*<< substring *)
  val () = eqS ("CharArraySlice.copyVec/from-a-substring", "--cde-",
                fn () => let val d = CharArray.array (6, #"-")
                         in S.copyVec {src = Substring.substring ("abcdefg", 2, 3), dst = d, di = 2}; CharArray.vector d end)
  val () = T.raises ("CharArraySlice.copyVec/Subscript-substring-too-long", T.isSubscript,
                     fn () => S.copyVec {src = Substring.full "abcdefg", dst = CharArray.array (6, #"-"), di = 0})
  (*>> substring *)

  (* ---- laws against String, on pseudo-random strings ---- *)
  val () = T.seed 38
  val () = T.repeat (20, fn k =>
    let
      val t = "-" ^ Int.toString k
      val s = String.implode (List.tabulate (T.range (0, 10), fn _ => Char.chr (T.range (0, 255))))
      val i = T.range (0, String.size s)
      val n = T.range (0, String.size s - i)
    in
      eqS ("CharArraySlice.vector/String.substring" ^ t, String.substring (s, i, n),
           fn () => S.vector (S.slice (ofString s, i, SOME n)));
      eqS ("CharArraySlice.slice/String.extract" ^ t, String.extract (s, i, NONE), fn () => S.vector (S.slice (ofString s, i, NONE)));
      eqS ("CharArraySlice.copyVec/String.substring" ^ t, String.substring (s, i, n),
           fn () => let val d = CharArray.array (n, #"?")
                    in S.copyVec {src = CharVectorSlice.slice (s, i, SOME n), dst = d, di = 0}; CharArray.vector d end);
      eqS ("CharArraySlice.modify/String.map" ^ t,
           String.substring (s, 0, i) ^ String.map Char.toUpper (String.substring (s, i, n)) ^ String.extract (s, i + n, NONE),
           fn () => let val a = ofString s in S.modify Char.toUpper (S.slice (a, i, SOME n)); CharArray.vector a end)
    end)

  (*<< overflow *)
  structure Overflow = TestMonoArraySliceOverflowFn (structure S = CharArraySlice structure A = CharArray val name = "CharArraySlice" val elem = #"a")
  (*>> overflow *)
end

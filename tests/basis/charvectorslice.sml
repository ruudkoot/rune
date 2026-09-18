(* requires: CharVectorSlice CharVector Substring Char String List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_VECTOR_SLICE.sml fn/mono_vector_slice_fn.sml *)
(* CharVectorSlice (signature MONO_VECTOR_SLICE, "where type slice =
   Substring.substring where type vector = String.string where type elem =
   char"): the checks that hold for every MONO_VECTOR_SLICE structure, from
   fn/mono_vector_slice_fn.sml, on sample characters that include #"\000" and
   #"\255", and those of the type identities: a slice is a substring, its
   vector a string. *)
structure TestCharVectorSlice =
struct
  val chars = Vector.fromList [#"\000", #"a", #"b", #"Z", #"\n", #" ", #"\127", #"\255"]
  structure Generic = TestMonoVectorSliceFn (structure S = CharVectorSlice structure V = CharVector val name = "CharVectorSlice" val elems = chars val show = T.char val same = op =)

  structure S = CharVectorSlice
  val eqI = T.eq T.int
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqBase = T.eq (T.triple (T.string, T.int, T.int))

  (* ---- the vector of a slice is a string ---- *)
  val () = eqS ("CharVectorSlice.vector/is-a-string", "cde", fn () => S.vector (S.slice ("abcdefg", 2, SOME 3)))
  val () = eqS ("CharVectorSlice.vector/empty-string", "", fn () => S.vector (S.slice ("abc", 3, NONE)))
  val () = eqS ("CharVectorSlice.full/string-constant", "hello", fn () => S.vector (S.full "hello"))
  val () = eqBase ("CharVectorSlice.base/string", ("abcdefg", 2, 3), fn () => S.base (S.slice ("abcdefg", 2, SOME 3)))
  val () = eqS ("CharVectorSlice.concat/string", "cdeab", fn () => S.concat [S.slice ("abcdefg", 2, SOME 3), S.slice ("abc", 0, SOME 2)])
  val () = eqS ("CharVectorSlice.map/toUpper", "CDE", fn () => S.map Char.toUpper (S.slice ("abcdefg", 2, SOME 3)))
  val () = eqS ("CharVectorSlice.mapi/string-index", "0d2",
                fn () => S.mapi (fn (i, c) => if i mod 2 = 0 then Char.chr (48 + i) else c) (S.slice ("abcdefg", 2, SOME 3)))
  val () = T.eq T.char ("CharVectorSlice.sub/elem-is-char", #"d", fn () => (S.sub (S.slice ("abcdefg", 2, SOME 3), 1) : char))
  val () = eqI ("CharVectorSlice.sub/high-character", 255,
                fn () => Char.ord (S.sub (S.full (String.str (Char.chr 255)), 0)))
  val () = T.eq T.order ("CharVectorSlice.collate/high-characters", LESS,   (* ord: 127 < 255 *)
                         fn () => S.collate Char.compare (S.full "\127", S.full "\255"))

  (*<< substring *)
  (* ---- a slice is a substring ---- *)
  val () = eqS ("CharVectorSlice.slice/is-a-substring", "cde", fn () => Substring.string (S.slice ("abcdefg", 2, SOME 3)))
  val () = eqS ("CharVectorSlice.full/is-Substring.full", "abc", fn () => Substring.string (S.full "abc"))
  val () = eqS ("CharVectorSlice.vector/of-a-substring", "cde", fn () => S.vector (Substring.substring ("abcdefg", 2, 3)))
  val () = eqS ("CharVectorSlice.vector/of-Substring.extract", "cdefg", fn () => S.vector (Substring.extract ("abcdefg", 2, NONE)))
  val () = eqI ("CharVectorSlice.length/of-a-substring", 3, fn () => S.length (Substring.substring ("abcdefg", 2, 3)))
  val () = eqBase ("CharVectorSlice.base/of-a-substring", ("abcdefg", 2, 3), fn () => S.base (Substring.substring ("abcdefg", 2, 3)))
  val () = eqBase ("CharVectorSlice.slice/Substring.base", ("abcdefg", 2, 3), fn () => Substring.base (S.slice ("abcdefg", 2, SOME 3)))
  val () = eqBase ("CharVectorSlice.subslice/of-Substring.triml", ("abcdefg", 3, 2),
                   fn () => S.base (S.subslice (Substring.triml 2 (Substring.full "abcdefg"), 1, SOME 2)))
  val () = eqS ("CharVectorSlice.subslice/then-Substring.trimr", "cd",
                fn () => Substring.string (Substring.trimr 1 (S.subslice (S.full "abcdefg", 2, SOME 3))))
  val () = T.eq (T.option (T.pair (T.char, T.string))) ("CharVectorSlice.getItem/is-Substring.getc", SOME (#"c", "de"),
                fn () => Option.map (fn (c, r) => (c, Substring.string r)) (S.getItem (Substring.substring ("abcdefg", 2, 3))))
  val () = eqB ("CharVectorSlice.isEmpty/of-a-substring", true, fn () => S.isEmpty (Substring.full ""))
  val () = eqS ("CharVectorSlice.concat/of-substrings", "cdeab",
                fn () => S.concat [Substring.substring ("abcdefg", 2, 3), Substring.substring ("abc", 0, 2)])
  val () = T.eq T.order ("CharVectorSlice.collate/of-substrings", GREATER,
                         fn () => S.collate Char.compare (Substring.substring ("abd", 1, 2), Substring.substring ("xbc", 1, 2)))

  (* ---- laws against Substring, on pseudo-random strings ---- *)
  val () = T.seed 37
  val () = T.repeat (20, fn k =>
    let
      val t = "-" ^ Int.toString k
      val s = String.implode (List.tabulate (T.range (0, 10), fn _ => Char.chr (T.range (0, 255))))
      val i = T.range (0, String.size s)
      val n = T.range (0, String.size s - i)
    in
      eqS ("CharVectorSlice.vector/String.substring" ^ t, String.substring (s, i, n), fn () => S.vector (S.slice (s, i, SOME n)));
      eqS ("CharVectorSlice.slice/String.extract" ^ t, String.extract (s, i, NONE), fn () => S.vector (S.slice (s, i, NONE)));
      eqBase ("CharVectorSlice.base/Substring.base" ^ t, (s, i, n), fn () => Substring.base (S.slice (s, i, SOME n)));
      eqS ("CharVectorSlice.foldr/Substring.explode" ^ t, String.substring (s, i, n),
           fn () => String.implode (S.foldr (op ::) [] (Substring.substring (s, i, n))))
    end)
  (*>> substring *)

  (*<< overflow *)
  structure Overflow = TestMonoVectorSliceOverflowFn (structure S = CharVectorSlice structure V = CharVector val name = "CharVectorSlice" val elem = #"a")
  (*>> overflow *)

  (*<< size *)
  structure Size = TestMonoVectorSliceSizeFn (structure S = CharVectorSlice structure V = CharVector val name = "CharVectorSlice" val elem = #"a")
  (*>> size *)
end

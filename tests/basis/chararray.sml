(* requires: CharArray CharVector Char String List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml fn/mono_array_fn.sml *)
(* CharArray (signature MONO_ARRAY, "where type vector = CharVector.vector
   where type elem = char"): the checks that hold for every MONO_ARRAY
   structure, from fn/mono_array_fn.sml, on sample characters that include
   #"\000" and #"\255", and those of the vector type, which is string ("The
   type String.string is identical to CharVector.vector"). *)
structure TestCharArray =
struct
  val chars = Vector.fromList [#"\000", #"a", #"b", #"Z", #"\n", #" ", #"\127", #"\255"]
  structure Generic = TestMonoArrayFn (structure A = CharArray structure V = CharVector val name = "CharArray" val elems = chars val show = T.char val same = op =)

  val eqI = T.eq T.int
  val eqS = T.eq T.string
  fun ofString s = CharArray.fromList (String.explode s)

  (* ---- the vector of a CharArray.array is a string ---- *)
  val () = eqS ("CharArray.vector/is-a-string", "abc", fn () => CharArray.vector (ofString "abc"))
  val () = eqS ("CharArray.vector/empty-string", "", fn () => CharArray.vector (ofString ""))
  val () = eqS ("CharArray.vector/is-CharVector.vector", "abc", fn () => (CharArray.vector (ofString "abc") : CharVector.vector))
  val () = eqS ("CharArray.array/string-of-init", "xxx", fn () => CharArray.vector (CharArray.array (3, #"x")))
  val () = eqS ("CharArray.tabulate/string", "abcde", fn () => CharArray.vector (CharArray.tabulate (5, fn i => Char.chr (97 + i))))
  val () = eqS ("CharArray.update/string", "hallo",
                fn () => let val a = ofString "hello" in CharArray.update (a, 1, #"a"); CharArray.vector a end)
  val () = eqS ("CharArray.vector/string-is-a-snapshot", "hello",
                fn () => let val a = ofString "hello" val s = CharArray.vector a in CharArray.update (a, 1, #"a"); s end)
  val () = eqS ("CharArray.copyVec/string-constant", "--abc-",
                fn () => let val a = CharArray.array (6, #"-") in CharArray.copyVec {src = "abc", dst = a, di = 2}; CharArray.vector a end)
  val () = T.raises ("CharArray.copyVec/Subscript-string-too-long", T.isSubscript,
                     fn () => CharArray.copyVec {src = "abcdef", dst = CharArray.array (6, #"-"), di = 1})
  val () = eqS ("CharArray.copyVec/string-unchanged", "abc",
                fn () => let val s = "abc" val a = CharArray.array (3, #"-")
                         in CharArray.copyVec {src = s, dst = a, di = 0}; CharArray.update (a, 0, #"X"); s end)
  val () = eqS ("CharArray.copy/string", "heLLo",
                fn () => let val a = ofString "hello" in CharArray.copy {src = ofString "LL", dst = a, di = 2}; CharArray.vector a end)
  val () = eqS ("CharArray.modify/toUpper", "HELLO, 42",
                fn () => let val a = ofString "hello, 42" in CharArray.modify Char.toUpper a; CharArray.vector a end)
  val () = eqS ("CharArray.modifyi/index", "a1c3",
                fn () => let val a = ofString "abcd"
                         in CharArray.modifyi (fn (i, c) => if i mod 2 = 1 then Char.chr (48 + i) else c) a; CharArray.vector a end)
  val () = eqS ("CharArray.foldr/implode", "abc", fn () => String.implode (CharArray.foldr (op ::) [] (ofString "abc")))
  val () = T.eq (T.option T.char) ("CharArray.find/digit", SOME #"4", fn () => CharArray.find Char.isDigit (ofString "ab42"))
  val () = T.eq T.order ("CharArray.collate/high-characters", LESS,   (* ord: 127 < 255 *)
                         fn () => CharArray.collate Char.compare (ofString "\127", ofString "\255"))
  val () = eqI ("CharArray.elem/is-char", 255, fn () => Char.ord (CharArray.sub (CharArray.array (1, Char.chr 255), 0) : char))

  (* ---- laws against String, on pseudo-random strings ---- *)
  val () = T.seed 34
  val () = T.repeat (20, fn i =>
    let
      val n = "-" ^ Int.toString i
      fun randomString () = String.implode (List.tabulate (T.range (0, 10), fn _ => Char.chr (T.range (0, 255))))
      val s = randomString ()
      val t = randomString ()
    in
      eqS ("CharArray.vector/implode" ^ n, s, fn () => CharArray.vector (ofString s));
      eqS ("CharArray.copyVec/concat" ^ n, s ^ t,
           fn () => let val a = CharArray.array (String.size s + String.size t, #"?")
                    in CharArray.copyVec {src = s, dst = a, di = 0}; CharArray.copyVec {src = t, dst = a, di = String.size s};
                       CharArray.vector a end);
      eqS ("CharArray.modify/String.map" ^ n, String.map Char.toLower s,
           fn () => let val a = ofString s in CharArray.modify Char.toLower a; CharArray.vector a end);
      T.eq T.order ("CharArray.collate/String.compare" ^ n, String.compare (s, t),
                    fn () => CharArray.collate Char.compare (ofString s, ofString t))
    end)

  (*<< size *)
  structure Size = TestMonoArraySizeFn (structure A = CharArray val name = "CharArray" val elem = #"a")
  (*>> size *)
end

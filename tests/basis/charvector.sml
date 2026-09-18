(* requires: CharVector Char String List *)
(* uses: spec-sigs/MONO_VECTOR.sml fn/mono_vector_fn.sml *)
(* CharVector (signature MONO_VECTOR, "where type vector = String.string where
   type elem = char"): the checks that hold for every MONO_VECTOR structure,
   from fn/mono_vector_fn.sml, on sample characters that include #"\000" and
   #"\255", and those of "The type String.string is identical to
   CharVector.vector". *)
structure TestCharVector =
struct
  val chars = Vector.fromList [#"\000", #"a", #"b", #"Z", #"\n", #" ", #"\127", #"\255"]
  structure Generic = TestMonoVectorFn (structure V = CharVector val name = "CharVector" val elems = chars val show = T.char val same = op =)

  val eqI = T.eq T.int
  val eqS = T.eq T.string
  val eqB = T.eq T.bool

  (* ---- a CharVector.vector is a string ---- *)
  val () = eqS ("CharVector.fromList/is-implode", "abc", fn () => CharVector.fromList [#"a", #"b", #"c"])
  val () = eqS ("CharVector.fromList/nil-is-the-empty-string", "", fn () => CharVector.fromList [])
  val () = eqS ("CharVector.tabulate/string", "abcde", fn () => CharVector.tabulate (5, fn i => Char.chr (97 + i)))
  val () = eqI ("CharVector.length/is-size", 5, fn () => CharVector.length "hello")
  val () = eqI ("CharVector.length/empty-string", 0, fn () => CharVector.length "")
  val () = T.eq T.char ("CharVector.sub/string-constant", #"l", fn () => CharVector.sub ("hello", 3))
  val () = T.raises ("CharVector.sub/Subscript-at-size", T.isSubscript, fn () => CharVector.sub ("hello", 5))
  val () = eqS ("CharVector.update/string", "hallo", fn () => CharVector.update ("hello", 1, #"a"))
  val () = eqS ("CharVector.update/constant-unchanged", "hello",
                fn () => let val s = "hello" in ignore (CharVector.update (s, 1, #"a")); s end)
  val () = eqS ("CharVector.concat/strings", "abcd", fn () => CharVector.concat ["ab", "", "c", "d"])
  val () = eqS ("CharVector.map/toUpper", "HELLO, 42", fn () => CharVector.map Char.toUpper "hello, 42")
  val () = eqS ("CharVector.mapi/index", "a1c3", fn () => CharVector.mapi (fn (i, c) => if i mod 2 = 1 then Char.chr (48 + i) else c) "abcd")
  val () = eqS ("CharVector.foldr/implode", "abc", fn () => String.implode (CharVector.foldr (op ::) [] "abc"))
  val () = eqS ("CharVector.foldl/reverse", "cba", fn () => String.implode (CharVector.foldl (op ::) [] "abc"))
  val () = T.eq (T.option (T.pair (T.int, T.char))) ("CharVector.findi/string", SOME (2, #" "),
                                                     fn () => CharVector.findi (fn (_, c) => Char.isSpace c) "ab cd e")
  val () = T.eq (T.option T.char) ("CharVector.find/string", SOME #"4", fn () => CharVector.find Char.isDigit "ab42")
  val () = eqB ("CharVector.exists/string", true, fn () => CharVector.exists Char.isUpper "abCd")
  val () = eqB ("CharVector.all/string", false, fn () => CharVector.all Char.isLower "abCd")
  val () = eqS ("CharVector.app/string", "abc",
                fn () => let val r = ref [] in CharVector.app (fn c => r := c :: !r) "abc"; String.implode (List.rev (!r)) end)
  val () = T.eq T.order ("CharVector.collate/strings", LESS, fn () => CharVector.collate Char.compare ("abc", "abd"))
  val () = T.eq T.order ("CharVector.collate/high-characters", LESS,   (* ord: 127 < 255 *)
                         fn () => CharVector.collate Char.compare ("\127", "\255"))
  val () = eqS ("CharVector.vector/is-String.string", "abc", fn () => (CharVector.fromList [#"a", #"b", #"c"] : String.string))
  val () = eqB ("CharVector.vector/string-equality", true, fn () => CharVector.tabulate (2, fn _ => #"x") = "xx")
  val () = eqI ("CharVector.elem/is-char", 255, fn () => Char.ord (CharVector.sub (String.str (Char.chr 255), 0) : char))

  (* ---- laws against String, on pseudo-random strings ---- *)
  val () = T.seed 32
  val () = T.repeat (20, fn i =>
    let
      val n = "-" ^ Int.toString i
      fun randomString () = String.implode (List.tabulate (T.range (0, 10), fn _ => Char.chr (T.range (0, 255))))
      val s = randomString ()
      val t = randomString ()
    in
      eqS ("CharVector.fromList/explode" ^ n, s, fn () => CharVector.fromList (String.explode s));
      eqI ("CharVector.length/size" ^ n, String.size s, fn () => CharVector.length s);
      eqS ("CharVector.concat/String.concat" ^ n, String.concat [s, t, s], fn () => CharVector.concat [s, t, s]);
      eqS ("CharVector.map/String.map" ^ n, String.map Char.toLower s, fn () => CharVector.map Char.toLower s);
      T.eq T.order ("CharVector.collate/String.compare" ^ n, String.compare (s, t),
                    fn () => CharVector.collate Char.compare (s, t))
    end)

  (*<< size *)
  structure Size = TestMonoVectorSizeFn (structure V = CharVector val name = "CharVector" val elem = #"a")
  (*>> size *)
end

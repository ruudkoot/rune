(* requires: WideSubstring WideString WideChar WideCharVectorSlice *)
(* WideSubstring (optional in the specification, signature SUBSTRING): the
   substrings of WideString, which are the slices of WideCharVectorSlice.
   Expected values follow https://smlfamily.github.io/Basis/substring.html.
   The samples hold "h", 0xE9 (e with an acute accent) and 0x1F600 (a face),
   so that what counts is code points, not bytes. *)
structure TestWideSubstring =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqO = T.eq T.order
  val C = WideChar.chr
  fun ws l = WideString.implode (List.map C l)
  val show = WideString.toString
  val eqW = T.eq show
  fun showSS ss = show (WideSubstring.string ss)
  (* substrings are compared by their characters: a substring is abstract on a
     host, and its equality is not part of SUBSTRING *)
  fun eqSS (label, expected, f) =
    T.eq show (label, WideSubstring.string expected, fn () => WideSubstring.string (f ()))
  fun eqSSP (label, (a, b), f) =
    T.eq (T.pair (show, show)) (label, (WideSubstring.string a, WideSubstring.string b),
                                fn () => let val (x, y) = f () in (WideSubstring.string x, WideSubstring.string y) end)
  fun eqSSL (label, expected, f) =
    T.eq (T.list show) (label, List.map WideSubstring.string expected,
                        fn () => List.map WideSubstring.string (f ()))
  val eqCO = T.eq (T.option (fn c => "0x" ^ Int.fmt StringCvt.HEX (WideChar.ord c)))
  val isSubscript = fn Subscript => true | _ => false
  val isSpan = fn Span => true | _ => false
  val sample = ws [104, 233, 0x1F600]
  val full = WideSubstring.full sample
  val middle = WideSubstring.substring (sample, 1, 1)          (* the e-acute *)

  (*<< basics *)
  val () = eqI ("WideSubstring.size/whole", 3, fn () => WideSubstring.size full)
  val () = eqI ("WideSubstring.size/part", 1, fn () => WideSubstring.size middle)
  val () = T.check ("WideSubstring.sub/first", fn () => WideSubstring.sub (full, 0) = C 104)
  val () = T.raises ("WideSubstring.sub/Subscript-past-the-end", isSubscript, fn () => WideSubstring.sub (middle, 1))
  val () = T.check ("WideSubstring.base/string-start-length",
                    fn () => let val (s, i, n) = WideSubstring.base middle
                             in WideString.compare (s, sample) = EQUAL andalso i = 1 andalso n = 1 end)
  val () = eqSS ("WideSubstring.extract/to-the-end", WideSubstring.substring (sample, 1, 2),
                 fn () => WideSubstring.extract (sample, 1, NONE))
  val () = T.raises ("WideSubstring.extract/Subscript-past-the-end", isSubscript,
                     fn () => WideSubstring.extract (sample, 4, NONE))
  val () = eqSS ("WideSubstring.substring/middle", middle, fn () => WideSubstring.substring (sample, 1, 1))
  val () = eqSS ("WideSubstring.full/whole-string", full, fn () => WideSubstring.full sample)
  val () = eqW ("WideSubstring.string/gives-the-characters", ws [233], fn () => WideSubstring.string middle)
  val () = eqB ("WideSubstring.isEmpty/empty", true, fn () => WideSubstring.isEmpty (WideSubstring.full (ws [])))
  val () = eqB ("WideSubstring.isEmpty/not-empty", false, fn () => WideSubstring.isEmpty middle)
  val () = T.check ("WideSubstring.getc/first-and-rest",
                    fn () => case WideSubstring.getc full of
                               SOME (c, rest) => c = C 104 andalso WideSubstring.size rest = 2
                             | NONE => false)
  val () = T.check ("WideSubstring.getc/NONE-when-empty",
                    fn () => not (isSome (WideSubstring.getc (WideSubstring.full (ws [])))))
  val () = eqCO ("WideSubstring.first/character", SOME (C 104), fn () => WideSubstring.first full)
  val () = eqCO ("WideSubstring.first/NONE-when-empty", NONE, fn () => WideSubstring.first (WideSubstring.full (ws [])))
  val () = eqSS ("WideSubstring.slice/part-of-a-part", WideSubstring.substring (sample, 2, 1),
                 fn () => WideSubstring.slice (full, 2, SOME 1))
  val () = T.raises ("WideSubstring.slice/Subscript-too-long", isSubscript, fn () => WideSubstring.slice (middle, 0, SOME 2))
  (*>> basics *)

  (*<< trimming *)
  val () = eqSS ("WideSubstring.triml/drops-from-the-left", WideSubstring.substring (sample, 2, 1),
                 fn () => WideSubstring.triml 2 full)
  val () = eqSS ("WideSubstring.triml/more-than-the-size", WideSubstring.substring (sample, 3, 0),
                 fn () => WideSubstring.triml 9 full)
  val () = T.raises ("WideSubstring.triml/Subscript-negative", isSubscript, fn () => WideSubstring.triml ~1 full)
  val () = eqSS ("WideSubstring.trimr/drops-from-the-right", WideSubstring.substring (sample, 0, 1),
                 fn () => WideSubstring.trimr 2 full)
  val () = eqSS ("WideSubstring.trimr/more-than-the-size", WideSubstring.substring (sample, 0, 0),
                 fn () => WideSubstring.trimr 9 full)
  val () = T.raises ("WideSubstring.trimr/Subscript-negative", isSubscript, fn () => WideSubstring.trimr ~1 full)
  (*>> trimming *)

  (*<< pieces *)
  val () = eqW ("WideSubstring.concat/two", ws [233, 104], fn () => WideSubstring.concat [middle, WideSubstring.substring (sample, 0, 1)])
  val () = eqW ("WideSubstring.concat/empty-list", ws [], fn () => WideSubstring.concat [])
  val () = eqW ("WideSubstring.concatWith/separator", ws [233, 44, 104],
                fn () => WideSubstring.concatWith (ws [44]) [middle, WideSubstring.substring (sample, 0, 1)])
  val () = T.check ("WideSubstring.explode/characters", fn () => WideSubstring.explode full = [C 104, C 233, C 0x1F600])
  val () = eqB ("WideSubstring.isPrefix/yes", true, fn () => WideSubstring.isPrefix (ws [104]) full)
  val () = eqB ("WideSubstring.isPrefix/no", false, fn () => WideSubstring.isPrefix (ws [233]) full)
  val () = eqB ("WideSubstring.isSubstring/middle", true, fn () => WideSubstring.isSubstring (ws [233]) full)
  val () = eqB ("WideSubstring.isSubstring/absent", false, fn () => WideSubstring.isSubstring (ws [0x100]) full)
  val () = eqB ("WideSubstring.isSuffix/yes", true, fn () => WideSubstring.isSuffix (ws [0x1F600]) full)
  val () = eqB ("WideSubstring.isSuffix/no", false, fn () => WideSubstring.isSuffix (ws [104]) full)
  val () = eqO ("WideSubstring.compare/by-code-point", LESS,
                fn () => WideSubstring.compare (WideSubstring.full (ws [233]), WideSubstring.full (ws [0x100])))
  val () = eqO ("WideSubstring.collate/with-a-comparison", GREATER,
                fn () => WideSubstring.collate (fn (a, b) => WideChar.compare (b, a))
                                               (WideSubstring.full (ws [233]), WideSubstring.full (ws [0x100])))
  (*>> pieces *)

  (*<< splitting *)
  val ascii = WideSubstring.full (ws [104, 101, 49, 50])       (* h e 1 2 *)
  val () = eqSSP ("WideSubstring.splitl/letters-then-the-rest",
                  (WideSubstring.substring (ws [104, 101, 49, 50], 0, 2), WideSubstring.substring (ws [104, 101, 49, 50], 2, 2)),
                  fn () => WideSubstring.splitl WideChar.isAlpha ascii)
  val () = eqSSP ("WideSubstring.splitr/digits-at-the-end",
                  (WideSubstring.substring (ws [104, 101, 49, 50], 0, 2), WideSubstring.substring (ws [104, 101, 49, 50], 2, 2)),
                  fn () => WideSubstring.splitr WideChar.isDigit ascii)
  val () = eqSSP ("WideSubstring.splitAt/at-an-index",
                  (WideSubstring.substring (sample, 0, 1), WideSubstring.substring (sample, 1, 2)),
                  fn () => WideSubstring.splitAt (full, 1))
  val () = T.raises ("WideSubstring.splitAt/Subscript-past-the-end", isSubscript, fn () => WideSubstring.splitAt (full, 4))
  val () = eqSS ("WideSubstring.dropl/letters", WideSubstring.substring (ws [104, 101, 49, 50], 2, 2),
                 fn () => WideSubstring.dropl WideChar.isAlpha ascii)
  val () = eqSS ("WideSubstring.dropr/digits", WideSubstring.substring (ws [104, 101, 49, 50], 0, 2),
                 fn () => WideSubstring.dropr WideChar.isDigit ascii)
  val () = eqSS ("WideSubstring.takel/letters", WideSubstring.substring (ws [104, 101, 49, 50], 0, 2),
                 fn () => WideSubstring.takel WideChar.isAlpha ascii)
  val () = eqSS ("WideSubstring.taker/digits", WideSubstring.substring (ws [104, 101, 49, 50], 2, 2),
                 fn () => WideSubstring.taker WideChar.isDigit ascii)
  val () = T.check ("WideSubstring.position/found",
                    fn () => let val (pre, post) = WideSubstring.position (ws [233]) full
                             in WideSubstring.size pre = 1 andalso WideSubstring.size post = 2 end)
  val () = T.check ("WideSubstring.position/not-found",
                    fn () => let val (pre, post) = WideSubstring.position (ws [0x100]) full
                             in WideSubstring.size pre = 3 andalso WideSubstring.isEmpty post end)
  val () = eqSS ("WideSubstring.span/from-the-one-to-the-other", full,
                 fn () => WideSubstring.span (WideSubstring.substring (sample, 0, 1), WideSubstring.substring (sample, 2, 1)))
  val () = T.raises ("WideSubstring.span/Span-in-the-wrong-order", isSpan,
                     fn () => WideSubstring.span (WideSubstring.substring (sample, 2, 1), WideSubstring.substring (sample, 0, 1)))
  (*>> splitting *)

  (*<< traversal *)
  val () = eqW ("WideSubstring.translate/each-character-to-a-string", ws [104, 104, 233, 233, 0x1F600, 0x1F600],
                fn () => WideSubstring.translate (fn c => WideString.implode [c, c]) full)
  val () = eqSSL ("WideSubstring.tokens/runs-collapse",
                  [WideSubstring.substring (ws [104, 233, 233, 0x1F600], 0, 1), WideSubstring.substring (ws [104, 233, 233, 0x1F600], 3, 1)],
                  fn () => WideSubstring.tokens (fn c => c = C 233) (WideSubstring.full (ws [104, 233, 233, 0x1F600])))
  val () = eqI ("WideSubstring.fields/every-delimiter-separates", 3,
                fn () => List.length (WideSubstring.fields (fn c => c = C 233) (WideSubstring.full (ws [104, 233, 233, 0x1F600]))))
  val () = T.check ("WideSubstring.app/in-order",
                    fn () => let val seen = ref []
                             in WideSubstring.app (fn c => seen := c :: !seen) full;
                                List.rev (!seen) = [C 104, C 233, C 0x1F600] end)
  val () = eqI ("WideSubstring.foldl/sums-the-code-points", 128849,
                fn () => WideSubstring.foldl (fn (c, acc) => acc + WideChar.ord c) 0 full)
  val () = T.check ("WideSubstring.foldr/from-the-right",
                    fn () => WideSubstring.foldr (fn (c, acc) => c :: acc) [] full = [C 104, C 233, C 0x1F600])
  (*>> traversal *)
end

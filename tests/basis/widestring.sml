(* requires: WideString WideChar WideCharVector WideCharVectorSlice *)
(* WideString (optional in the specification, signature STRING): the strings
   of WideChar. Expected values follow
   https://smlfamily.github.io/Basis/string.html. The samples hold characters
   of one, two and three bytes of UTF-8 alike, since a wide string counts code
   points: "h", 0xE9 (e with an acute accent), 0x1F600 (a face). The text that
   toString and fromString take and give is of char, the 8-bit one, as the
   signature writes it. *)
structure TestWideString =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqO = T.eq T.order
  val C = WideChar.chr
  (* a wide string of code points, and how a check shows one *)
  fun ws l = WideString.implode (List.map C l)
  val show = WideString.toString
  val eqW = T.eq show
  val eqWO = T.eq (T.option show)
  val eqWL = T.eq (T.list show)
  val isSubscript = fn Subscript => true | _ => false
  val isSize = fn Size => true | _ => false
  val sample = ws [104, 233, 0x1F600]                     (* h, e-acute, face *)
  val hello = ws [104, 101, 108, 108, 111]

  (*<< basics *)
  val () = eqB ("WideString.maxSize/positive", true, fn () => WideString.maxSize > 0)
  val () = eqI ("WideString.size/code-points", 3, fn () => WideString.size sample)
  val () = eqI ("WideString.size/empty", 0, fn () => WideString.size (ws []))
  val () = T.check ("WideString.sub/first", fn () => WideString.sub (sample, 0) = C 104)
  val () = T.check ("WideString.sub/beyond-the-basic-plane", fn () => WideString.sub (sample, 2) = C 0x1F600)
  val () = T.raises ("WideString.sub/Subscript-negative", isSubscript, fn () => WideString.sub (sample, ~1))
  val () = T.raises ("WideString.sub/Subscript-past-the-end", isSubscript, fn () => WideString.sub (sample, 3))
  val () = eqW ("WideString.extract/to-the-end", ws [233, 0x1F600], fn () => WideString.extract (sample, 1, NONE))
  val () = eqW ("WideString.extract/a-length", ws [233], fn () => WideString.extract (sample, 1, SOME 1))
  val () = eqW ("WideString.extract/empty-at-the-end", ws [], fn () => WideString.extract (sample, 3, NONE))
  val () = T.raises ("WideString.extract/Subscript-past-the-end", isSubscript, fn () => WideString.extract (sample, 4, NONE))
  val () = eqW ("WideString.substring/middle", ws [233], fn () => WideString.substring (sample, 1, 1))
  val () = T.raises ("WideString.substring/Subscript-too-long", isSubscript, fn () => WideString.substring (sample, 1, 3))
  val () = eqW ("WideString.^/concatenates", ws [104, 233, 0x1F600, 104], fn () => WideString.^ (sample, ws [104]))
  val () = eqW ("WideString.concat/three", ws [104, 233, 0x1F600], fn () => WideString.concat [ws [104], ws [233], ws [0x1F600]])
  val () = eqW ("WideString.concat/empty-list", ws [], fn () => WideString.concat [])
  val () = eqW ("WideString.concatWith/separator", ws [104, 44, 233, 44, 0x1F600],
                fn () => WideString.concatWith (ws [44]) [ws [104], ws [233], ws [0x1F600]])
  val () = eqW ("WideString.concatWith/one-piece", ws [104], fn () => WideString.concatWith (ws [44]) [ws [104]])
  val () = eqW ("WideString.str/one-character", ws [0x1F600], fn () => WideString.str (C 0x1F600))
  val () = eqW ("WideString.implode/list", sample, fn () => WideString.implode [C 104, C 233, C 0x1F600])
  val () = eqI ("WideString.explode/length", 3, fn () => List.length (WideString.explode sample))
  val () = T.check ("WideString.explode/order",
                    fn () => WideString.explode sample = [C 104, C 233, C 0x1F600])
  (*>> basics *)

  (*<< mapping *)
  val () = eqW ("WideString.map/to-upper-case", ws [72, 233, 0x1F600], fn () => WideString.map WideChar.toUpper sample)
  val () = eqW ("WideString.translate/each-character-to-a-string", ws [104, 104, 233, 233, 0x1F600, 0x1F600],
                fn () => WideString.translate (fn c => WideString.implode [c, c]) sample)
  val () = eqWL ("WideString.fields/every-delimiter-separates", [ws [104], ws [], ws [0x1F600]],
                 fn () => WideString.fields (fn c => c = C 233) (ws [104, 233, 233, 0x1F600]))
  val () = eqWL ("WideString.fields/no-delimiter", [sample], fn () => WideString.fields (fn c => c = C 44) sample)
  val () = eqWL ("WideString.tokens/runs-collapse", [ws [104], ws [0x1F600]],
                 fn () => WideString.tokens (fn c => c = C 233) (ws [104, 233, 233, 0x1F600]))
  val () = eqWL ("WideString.tokens/only-delimiters", [], fn () => WideString.tokens (fn c => c = C 233) (ws [233, 233]))
  (*>> mapping *)

  (*<< search *)
  val () = eqB ("WideString.isPrefix/yes", true, fn () => WideString.isPrefix (ws [104, 233]) sample)
  val () = eqB ("WideString.isPrefix/no", false, fn () => WideString.isPrefix (ws [233]) sample)
  val () = eqB ("WideString.isPrefix/empty", true, fn () => WideString.isPrefix (ws []) sample)
  val () = eqB ("WideString.isSuffix/yes", true, fn () => WideString.isSuffix (ws [0x1F600]) sample)
  val () = eqB ("WideString.isSuffix/no", false, fn () => WideString.isSuffix (ws [233]) sample)
  val () = eqB ("WideString.isSubstring/middle", true, fn () => WideString.isSubstring (ws [233]) sample)
  val () = eqB ("WideString.isSubstring/absent", false, fn () => WideString.isSubstring (ws [104, 0x1F600]) sample)
  val () = eqB ("WideString.isSubstring/empty", true, fn () => WideString.isSubstring (ws []) sample)
  (*>> search *)

  (*<< comparison *)
  val () = eqO ("WideString.compare/by-code-point", LESS, fn () => WideString.compare (ws [233], ws [0x100]))
  val () = eqO ("WideString.compare/prefix-is-less", LESS, fn () => WideString.compare (ws [104], sample))
  val () = eqO ("WideString.compare/equal", EQUAL, fn () => WideString.compare (sample, ws [104, 233, 0x1F600]))
  val () = eqO ("WideString.collate/with-a-comparison", GREATER,
                fn () => WideString.collate (fn (a, b) => WideChar.compare (b, a)) (ws [233], ws [0x100]))
  val () = eqB ("WideString.</by-code-point", true, fn () => WideString.< (ws [233], ws [0x100]))
  val () = eqB ("WideString.<=/equal", true, fn () => WideString.<= (sample, sample))
  val () = eqB ("WideString.>/longer-with-the-same-prefix", true, fn () => WideString.> (sample, ws [104]))
  val () = eqB ("WideString.>=/equal", true, fn () => WideString.>= (sample, sample))
  (*>> comparison *)

  (*<< text *)
  val () = eqS ("WideString.toString/escapes-each-character", "h\\233\\U0001F600", fn () => WideString.toString sample)
  val () = eqS ("WideString.toString/printable", "hello", fn () => WideString.toString hello)
  val () = eqS ("WideString.toString/quote-and-newline", "\\\"\\n", fn () => WideString.toString (ws [34, 10]))
  val () = eqS ("WideString.toString/empty", "", fn () => WideString.toString (ws []))
  val () = eqWO ("WideString.fromString/plain", SOME hello, fn () => WideString.fromString "hello")
  val () = eqWO ("WideString.fromString/escapes", SOME sample, fn () => WideString.fromString "h\\233\\U0001F600")
  val () = eqWO ("WideString.fromString/escape-u", SOME (ws [0x100, 0x101]), fn () => WideString.fromString "\\u0100\\u0101")
  val () = eqWO ("WideString.fromString/formatting-sequence", SOME (ws [104, 105]), fn () => WideString.fromString "h\\   \\i")
  val () = eqWO ("WideString.fromString/empty", SOME (ws []), fn () => WideString.fromString "")
  val () = eqWO ("WideString.fromString/stops-at-what-it-cannot-read", SOME (ws [104]), fn () => WideString.fromString "h\\q")
  val () = T.check ("WideString.fromString/round-trip",
                    fn () => WideString.fromString (WideString.toString sample) = SOME sample)
  val () = eqS ("WideString.toCString/octal-and-escapes", "h\\351\\U0001F600", fn () => WideString.toCString sample)
  val () = eqWO ("WideString.fromCString/octal", SOME (ws [233]), fn () => WideString.fromCString "\\351")
  val () = eqWO ("WideString.fromCString/escape-U", SOME sample, fn () => WideString.fromCString "h\\351\\U0001F600")
  val () = eqWO ("WideString.fromCString/empty", SOME (ws []), fn () => WideString.fromCString "")
  (* scan reads a stream of wide characters, as the signature writes it *)
  val () = T.check ("WideString.scan/reads-wide-characters",
                    fn () => case WideString.scan WideCharVectorSlice.getItem (WideCharVectorSlice.full (ws [104, 105])) of
                               SOME (s, _) => s = ws [104, 105]
                             | NONE => false)
  val () = T.check ("WideString.scan/stops-at-a-character-it-cannot-read",
                    fn () => case WideString.scan WideCharVectorSlice.getItem (WideCharVectorSlice.full (ws [104, 34, 105])) of
                               SOME (s, rest) => s = ws [104] andalso WideCharVectorSlice.length rest = 2
                             | NONE => false)
  (*>> text *)
end

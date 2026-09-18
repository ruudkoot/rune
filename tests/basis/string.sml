(* requires: String Char *)
(* The String structure (signature STRING), for 8-bit characters. Expected
   values follow the text of https://smlfamily.github.io/Basis/string.html and,
   for the escape sequences, of https://smlfamily.github.io/Basis/char.html.

   In the texts given to fromString, scan and fromCString every backslash is
   written "\\", so "\\n" is the two characters backslash, n.

   Size is not checked: it can only be provoked with strings of about
   String.maxSize characters, which is 2^24 - 1 on one system and more than
   2^59 on another. *)
structure TestString =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqC = T.eq T.char
  val eqS = T.eq T.string
  val eqOrd = T.eq T.order
  val eqSO = T.eq (T.option T.string)
  val eqSL = T.eq (T.list T.string)
  val eqCL = T.eq (T.list T.char)

  (* trace f: f, and the characters it has been applied to so far, in order. *)
  fun trace (f : char -> 'a) : (char -> 'a) * (unit -> char list) =
    let val log = ref []
    in (fn c => (log := c :: !log; f c), fn () => List.rev (!log)) end

  fun fromTo (lo, hi) = if lo > hi then [] else lo :: fromTo (lo + 1, hi)
  fun digit d = Char.chr (48 + d)
  fun dec3 i = String.implode [digit (i div 100), digit (i div 10 mod 10), digit (i mod 10)]
  fun isBar c = c = #"|"

  (* the largest int, or a large one *)
  val big = case Int.maxInt of SOME m => m | NONE => 1073741823

  (* ---- maxSize, size ---- *)
  val () = T.check ("String.maxSize/positive", fn () => String.maxSize > 0)
  val () = T.check ("String.maxSize/holds-a-long-string",
                    fn () => String.maxSize >= String.size (String.implode (List.tabulate (100000, fn _ => #"x"))))
  val () = eqI ("String.size/empty", 0, fn () => String.size "")
  val () = eqI ("String.size/three", 3, fn () => String.size "abc")
  val () = eqI ("String.size/nul-inside", 3, fn () => String.size "a\000b")
  val () = eqI ("String.size/255", 1, fn () => String.size "\255")
  val () = eqI ("String.size/escapes", 4, fn () => String.size "\\\"\n\t")
  val () = eqI ("String.size/long", 100000, fn () => String.size (String.implode (List.tabulate (100000, fn _ => #"x"))))

  (* ---- sub ---- *)
  val () = eqC ("String.sub/first", #"a", fn () => String.sub ("abc", 0))
  val () = eqC ("String.sub/middle", #"b", fn () => String.sub ("abc", 1))
  val () = eqC ("String.sub/last", #"c", fn () => String.sub ("abc", 2))
  val () = eqI ("String.sub/255", 255, fn () => Char.ord (String.sub ("a\255", 1)))
  val () = eqC ("String.sub/nul", #"\000", fn () => String.sub ("a\000b", 1))
  val () = T.raises ("String.sub/Subscript-size", T.isSubscript, fn () => String.sub ("abc", 3))
  val () = T.raises ("String.sub/Subscript-negative", T.isSubscript, fn () => String.sub ("abc", ~1))
  val () = T.raises ("String.sub/Subscript-empty", T.isSubscript, fn () => String.sub ("", 0))
  val () = T.raises ("String.sub/Subscript-maxInt", T.isSubscript, fn () => String.sub ("abc", big))
  val () = T.raises ("String.sub/Subscript-minInt", T.isSubscript, fn () => String.sub ("abc", ~ big - 1))

  (* ---- extract (s, i, NONE): s[i..|s|-1]; Subscript if i < 0 or |s| < i ---- *)
  val () = eqS ("String.extract/NONE-whole", "abcde", fn () => String.extract ("abcde", 0, NONE))
  val () = eqS ("String.extract/NONE-tail", "cde", fn () => String.extract ("abcde", 2, NONE))
  val () = eqS ("String.extract/NONE-last", "e", fn () => String.extract ("abcde", 4, NONE))
  val () = eqS ("String.extract/NONE-at-size", "", fn () => String.extract ("abcde", 5, NONE))
  val () = eqS ("String.extract/NONE-empty-string", "", fn () => String.extract ("", 0, NONE))
  val () = T.raises ("String.extract/NONE-Subscript-beyond-size", T.isSubscript, fn () => String.extract ("abcde", 6, NONE))
  val () = T.raises ("String.extract/NONE-Subscript-negative", T.isSubscript, fn () => String.extract ("abcde", ~1, NONE))
  val () = T.raises ("String.extract/NONE-Subscript-empty-string", T.isSubscript, fn () => String.extract ("", 1, NONE))
  val () = T.raises ("String.extract/NONE-Subscript-maxInt", T.isSubscript, fn () => String.extract ("abcde", big, NONE))
  (* ---- extract (s, i, SOME j): s[i..i+j-1]; Subscript if i < 0 or j < 0 or |s| < i + j ---- *)
  val () = eqS ("String.extract/SOME-middle", "bcd", fn () => String.extract ("abcde", 1, SOME 3))
  val () = eqS ("String.extract/SOME-whole", "abcde", fn () => String.extract ("abcde", 0, SOME 5))
  val () = eqS ("String.extract/SOME-to-the-end", "de", fn () => String.extract ("abcde", 3, SOME 2))
  val () = eqS ("String.extract/SOME-zero", "", fn () => String.extract ("abcde", 2, SOME 0))
  val () = eqS ("String.extract/SOME-zero-at-size", "", fn () => String.extract ("abcde", 5, SOME 0))
  val () = eqS ("String.extract/SOME-empty-string", "", fn () => String.extract ("", 0, SOME 0))
  val () = T.raises ("String.extract/SOME-Subscript-too-long", T.isSubscript, fn () => String.extract ("abcde", 0, SOME 6))
  val () = T.raises ("String.extract/SOME-Subscript-end-beyond-size", T.isSubscript, fn () => String.extract ("abcde", 3, SOME 3))
  val () = T.raises ("String.extract/SOME-Subscript-start-beyond-size", T.isSubscript, fn () => String.extract ("abcde", 6, SOME 0))
  val () = T.raises ("String.extract/SOME-Subscript-negative-start", T.isSubscript, fn () => String.extract ("abcde", ~1, SOME 1))
  val () = T.raises ("String.extract/SOME-Subscript-negative-start-zero", T.isSubscript, fn () => String.extract ("abcde", ~1, SOME 0))
  val () = T.raises ("String.extract/SOME-Subscript-negative-size", T.isSubscript, fn () => String.extract ("abcde", 1, SOME ~1))
  (* "bounds checking in such a way that the Overflow exception is not
     raised". A section of its own, because SML/NJ 110.79 does not check these
     bounds at all and ends with a segmentation fault. *)
  (*<< extract-overflow *)
  val () = T.raises ("String.extract/SOME-Subscript-not-Overflow-size", T.isSubscript, fn () => String.extract ("abcde", 1, SOME big))
  val () = T.raises ("String.extract/SOME-Subscript-not-Overflow-both", T.isSubscript, fn () => String.extract ("abcde", big, SOME big))
  val () = T.raises ("String.extract/SOME-Subscript-not-Overflow-start", T.isSubscript, fn () => String.extract ("abcde", big, SOME 1))
  (*>> extract-overflow *)

  (* ---- substring (s, i, j) = extract (s, i, SOME j) ---- *)
  val () = eqS ("String.substring/middle", "bcd", fn () => String.substring ("abcde", 1, 3))
  val () = eqS ("String.substring/whole", "abcde", fn () => String.substring ("abcde", 0, 5))
  val () = eqS ("String.substring/to-the-end", "de", fn () => String.substring ("abcde", 3, 2))
  val () = eqS ("String.substring/zero", "", fn () => String.substring ("abcde", 2, 0))
  val () = eqS ("String.substring/zero-at-size", "", fn () => String.substring ("abcde", 5, 0))
  val () = eqS ("String.substring/empty-string", "", fn () => String.substring ("", 0, 0))
  val () = T.raises ("String.substring/Subscript-too-long", T.isSubscript, fn () => String.substring ("abcde", 0, 6))
  val () = T.raises ("String.substring/Subscript-end-beyond-size", T.isSubscript, fn () => String.substring ("abcde", 3, 3))
  val () = T.raises ("String.substring/Subscript-start-beyond-size", T.isSubscript, fn () => String.substring ("abcde", 6, 0))
  val () = T.raises ("String.substring/Subscript-negative-start", T.isSubscript, fn () => String.substring ("abcde", ~1, 1))
  val () = T.raises ("String.substring/Subscript-negative-size", T.isSubscript, fn () => String.substring ("abcde", 1, ~1))
  val () = T.raises ("String.substring/Subscript-not-Overflow-size", T.isSubscript, fn () => String.substring ("abcde", 1, big))
  val () = T.raises ("String.substring/Subscript-not-Overflow-both", T.isSubscript, fn () => String.substring ("abcde", big, big))

  (* ---- ^, concat, concatWith ---- *)
  val () = eqS ("String.^/basic", "abcd", fn () => String.^ ("ab", "cd"))
  val () = eqS ("String.^/empty-left", "cd", fn () => String.^ ("", "cd"))
  val () = eqS ("String.^/empty-right", "ab", fn () => String.^ ("ab", ""))
  val () = eqS ("String.^/empty-both", "", fn () => String.^ ("", ""))
  val () = eqS ("String.^/infix", "abc", fn () => "a" ^ "b" ^ "c")
  val () = eqS ("String.^/nul", "a\000\000b", fn () => String.^ ("a\000", "\000b"))
  val () = eqS ("String.concat/nil", "", fn () => String.concat [])
  val () = eqS ("String.concat/singleton", "abc", fn () => String.concat ["abc"])
  val () = eqS ("String.concat/basic", "abcdef", fn () => String.concat ["a", "", "bc", "", "def"])
  val () = eqS ("String.concat/empties", "", fn () => String.concat ["", "", ""])
  val () = eqI ("String.concat/long", 30000, fn () => String.size (String.concat (List.tabulate (10000, fn _ => "abc"))))
  val () = eqS ("String.concatWith/basic", "a, b, c", fn () => String.concatWith ", " ["a", "b", "c"])
  val () = eqS ("String.concatWith/nil", "", fn () => String.concatWith ", " [])
  val () = eqS ("String.concatWith/singleton", "a", fn () => String.concatWith ", " ["a"])
  val () = eqS ("String.concatWith/empty-separator", "abc", fn () => String.concatWith "" ["a", "b", "c"])
  val () = eqS ("String.concatWith/empty-strings", ",,", fn () => String.concatWith "," ["", "", ""])
  val () = eqS ("String.concatWith/singleton-empty", "", fn () => String.concatWith "," [""])
  val () = eqS ("String.concatWith/long-separator", "xabyabz", fn () => String.concatWith "ab" ["x", "y", "z"])

  (* ---- str, implode, explode ---- *)
  val () = eqS ("String.str/letter", "a", fn () => String.str #"a")
  val () = eqS ("String.str/nul", "\000", fn () => String.str #"\000")
  val () = eqI ("String.str/size", 1, fn () => String.size (String.str #"\255"))
  val () = eqS ("String.implode/basic", "abc", fn () => String.implode [#"a", #"b", #"c"])
  val () = eqS ("String.implode/nil", "", fn () => String.implode [])
  val () = eqS ("String.implode/bytes", "\000\127\128\255", fn () => String.implode [#"\000", #"\127", #"\128", #"\255"])
  val () = eqCL ("String.explode/basic", [#"a", #"b", #"c"], fn () => String.explode "abc")
  val () = eqCL ("String.explode/empty", [], fn () => String.explode "")
  val () = eqCL ("String.explode/bytes", [#"\000", #"\127", #"\128", #"\255"], fn () => String.explode "\000\127\128\255")
  val () = T.eq (T.list T.int) ("String.explode/all-characters", fromTo (0, 255),
                                fn () => List.map Char.ord (String.explode (String.implode (List.map Char.chr (fromTo (0, 255))))))

  (* ---- map, translate: from left to right ---- *)
  val () = eqS ("String.map/basic", "ABC", fn () => String.map Char.toUpper "abc")
  val () = eqS ("String.map/empty", "", fn () => String.map Char.toUpper "")
  val () = eqS ("String.map/bytes", "\255\000\158", fn () => String.map (fn c => Char.chr (255 - Char.ord c)) "\000\255a")
  val () = eqCL ("String.map/order", [#"a", #"b", #"c", #"a"],
                 fn () => let val (f, seen) = trace (fn c => c) in ignore (String.map f "abca"); seen () end)
  val () = eqCL ("String.map/empty-not-applied", [],
                 fn () => let val (f, seen) = trace (fn c => c) in ignore (String.map f ""); seen () end)
  val () = eqS ("String.translate/basic", "xyzcxyz",
                fn () => String.translate (fn #"a" => "xyz" | #"b" => "" | c => String.str c) "abca")
  val () = eqS ("String.translate/empty", "", fn () => String.translate (fn _ => "x") "")
  val () = eqS ("String.translate/all-to-empty", "", fn () => String.translate (fn _ => "") "abc")
  val () = eqS ("String.translate/double", "aabbcc", fn () => String.translate (fn c => String.implode [c, c]) "abc")
  val () = eqCL ("String.translate/order", [#"a", #"b", #"c", #"a"],
                 fn () => let val (f, seen) = trace String.str in ignore (String.translate f "abca"); seen () end)

  (* ---- tokens, fields ---- *)
  val () = eqSL ("String.tokens/page-example", ["abc", "def"], fn () => String.tokens isBar "|abc||def")
  val () = eqSL ("String.fields/page-example", ["", "abc", "", "def"], fn () => String.fields isBar "|abc||def")
  val () = eqSL ("String.tokens/empty-string", [], fn () => String.tokens isBar "")
  val () = eqSL ("String.fields/empty-string", [""], fn () => String.fields isBar "")
  val () = eqSL ("String.tokens/no-delimiter", ["abc"], fn () => String.tokens isBar "abc")
  val () = eqSL ("String.fields/no-delimiter", ["abc"], fn () => String.fields isBar "abc")
  val () = eqSL ("String.tokens/one-delimiter-only", [], fn () => String.tokens isBar "|")
  val () = eqSL ("String.fields/one-delimiter-only", ["", ""], fn () => String.fields isBar "|")
  val () = eqSL ("String.tokens/delimiters-only", [], fn () => String.tokens isBar "|||")
  val () = eqSL ("String.fields/delimiters-only", ["", "", "", ""], fn () => String.fields isBar "|||")
  val () = eqSL ("String.tokens/trailing-delimiter", ["a", "b"], fn () => String.tokens isBar "a|b|")
  val () = eqSL ("String.fields/trailing-delimiter", ["a", "b", ""], fn () => String.fields isBar "a|b|")
  val () = eqSL ("String.tokens/leading-delimiter", ["a", "b"], fn () => String.tokens isBar "|a|b")
  val () = eqSL ("String.fields/leading-delimiter", ["", "a", "b"], fn () => String.fields isBar "|a|b")
  val () = eqSL ("String.tokens/whitespace", ["hello", "world"], fn () => String.tokens Char.isSpace "  hello \t world\n")
  val () = eqSL ("String.fields/commas", ["a", "b", "", "c", ""], fn () => String.fields (fn c => c = #",") "a,b,,c,")
  val () = eqSL ("String.tokens/several-delimiters", ["a", "b", "c"],
                 fn () => String.tokens (fn c => c = #"," orelse c = #";") "a,;b;,;c")
  val () = eqSL ("String.fields/several-delimiters", ["a", "", "b", "c"],
                 fn () => String.fields (fn c => c = #"," orelse c = #";") "a,;b;c")
  val () = eqSL ("String.tokens/every-character-delimits", [], fn () => String.tokens (fn _ => true) "ab")
  val () = eqSL ("String.fields/every-character-delimits", ["", "", ""], fn () => String.fields (fn _ => true) "ab")
  val () = eqSL ("String.tokens/nothing-delimits", ["a|b"], fn () => String.tokens (fn _ => false) "a|b")
  val () = eqSL ("String.fields/nothing-delimits", ["a|b"], fn () => String.fields (fn _ => false) "a|b")
  val () = eqSL ("String.fields/nothing-delimits-empty-string", [""], fn () => String.fields (fn _ => false) "")
  (* "derived from s from left to right" *)
  val () = eqCL ("String.tokens/order", [#"a", #"|", #"|", #"b", #"c"],
                 fn () => let val (f, seen) = trace isBar in ignore (String.tokens f "a||bc"); seen () end)
  val () = eqCL ("String.fields/order", [#"a", #"|", #"|", #"b", #"c"],
                 fn () => let val (f, seen) = trace isBar in ignore (String.fields f "a||bc"); seen () end)

  (* ---- isPrefix, isSubstring, isSuffix ---- *)
  val () = eqB ("String.isPrefix/basic", true, fn () => String.isPrefix "ab" "abc")
  val () = eqB ("String.isPrefix/not", false, fn () => String.isPrefix "bc" "abc")
  val () = eqB ("String.isPrefix/empty", true, fn () => String.isPrefix "" "abc")
  val () = eqB ("String.isPrefix/empty-empty", true, fn () => String.isPrefix "" "")
  val () = eqB ("String.isPrefix/itself", true, fn () => String.isPrefix "abc" "abc")
  val () = eqB ("String.isPrefix/longer", false, fn () => String.isPrefix "abcd" "abc")
  val () = eqB ("String.isPrefix/of-empty", false, fn () => String.isPrefix "a" "")
  val () = eqB ("String.isPrefix/differs-at-end", false, fn () => String.isPrefix "abd" "abcd")
  val () = eqB ("String.isSuffix/basic", true, fn () => String.isSuffix "bc" "abc")
  val () = eqB ("String.isSuffix/not", false, fn () => String.isSuffix "ab" "abc")
  val () = eqB ("String.isSuffix/empty", true, fn () => String.isSuffix "" "abc")
  val () = eqB ("String.isSuffix/empty-empty", true, fn () => String.isSuffix "" "")
  val () = eqB ("String.isSuffix/itself", true, fn () => String.isSuffix "abc" "abc")
  val () = eqB ("String.isSuffix/longer", false, fn () => String.isSuffix "zabc" "abc")
  val () = eqB ("String.isSuffix/of-empty", false, fn () => String.isSuffix "a" "")
  val () = eqB ("String.isSuffix/differs-at-start", false, fn () => String.isSuffix "xcd" "abcd")
  val () = eqB ("String.isSubstring/middle", true, fn () => String.isSubstring "bc" "abcd")
  val () = eqB ("String.isSubstring/prefix", true, fn () => String.isSubstring "ab" "abcd")
  val () = eqB ("String.isSubstring/suffix", true, fn () => String.isSubstring "cd" "abcd")
  val () = eqB ("String.isSubstring/not-contiguous", false, fn () => String.isSubstring "bd" "abcd")
  val () = eqB ("String.isSubstring/empty", true, fn () => String.isSubstring "" "abc")
  val () = eqB ("String.isSubstring/empty-empty", true, fn () => String.isSubstring "" "")
  val () = eqB ("String.isSubstring/itself", true, fn () => String.isSubstring "abc" "abc")
  val () = eqB ("String.isSubstring/longer", false, fn () => String.isSubstring "abcd" "abc")
  val () = eqB ("String.isSubstring/of-empty", false, fn () => String.isSubstring "a" "")
  val () = eqB ("String.isSubstring/after-partial-match", true, fn () => String.isSubstring "aab" "aaab")
  val () = eqB ("String.isSubstring/after-partial-match-2", true, fn () => String.isSubstring "abab" "abaabab")
  val () = eqB ("String.isSubstring/partial-match-at-end", false, fn () => String.isSubstring "abc" "xxab")
  val () = eqB ("String.isSubstring/case-matters", false, fn () => String.isSubstring "BC" "abcd")

  (* ---- compare, collate, <, <=, >, >=: lexicographic, characters by their codes ---- *)
  val () = eqOrd ("String.compare/less", LESS, fn () => String.compare ("abc", "abd"))
  val () = eqOrd ("String.compare/equal", EQUAL, fn () => String.compare ("abc", "abc"))
  val () = eqOrd ("String.compare/greater", GREATER, fn () => String.compare ("b", "abc"))
  val () = eqOrd ("String.compare/prefix-less", LESS, fn () => String.compare ("ab", "abc"))
  val () = eqOrd ("String.compare/prefix-greater", GREATER, fn () => String.compare ("abc", "ab"))
  val () = eqOrd ("String.compare/empty-empty", EQUAL, fn () => String.compare ("", ""))
  val () = eqOrd ("String.compare/empty-less", LESS, fn () => String.compare ("", "a"))
  val () = eqOrd ("String.compare/upper-before-lower", LESS, fn () => String.compare ("Zebra", "apple"))
  val () = eqOrd ("String.compare/127-128", LESS, fn () => String.compare ("a\127", "a\128"))
  val () = eqOrd ("String.compare/255-letter", GREATER, fn () => String.compare ("\255", "a"))
  val () = eqOrd ("String.compare/nul-after-prefix", GREATER, fn () => String.compare ("a\000", "a"))
  val () = eqOrd ("String.compare/first-difference-decides", LESS, fn () => String.compare ("abz", "aca"))
  val reversed = fn (c, d) => Char.compare (d, c)
  val caseless = fn (c, d) => Char.compare (Char.toLower c, Char.toLower d)
  val () = eqOrd ("String.collate/Char.compare", LESS, fn () => String.collate Char.compare ("abc", "abd"))
  val () = eqOrd ("String.collate/reversed-order", GREATER, fn () => String.collate reversed ("abc", "abd"))
  val () = eqOrd ("String.collate/reversed-order-prefix", LESS, fn () => String.collate reversed ("ab", "abc"))
  val () = eqOrd ("String.collate/reversed-order-longer", GREATER, fn () => String.collate reversed ("abc", "ab"))
  val () = eqOrd ("String.collate/caseless-equal", EQUAL, fn () => String.collate caseless ("aBc", "AbC"))
  val () = eqOrd ("String.collate/caseless-less", LESS, fn () => String.collate caseless ("ABC", "abd"))
  val () = eqOrd ("String.collate/empty-empty", EQUAL, fn () => String.collate reversed ("", ""))
  val () = eqOrd ("String.collate/always-equal-length-decides", LESS, fn () => String.collate (fn _ => EQUAL) ("xy", "abc"))
  val () = eqB ("String.</less", true, fn () => String.< ("abc", "abd"))
  val () = eqB ("String.</equal", false, fn () => String.< ("abc", "abc"))
  val () = eqB ("String.</greater", false, fn () => String.< ("abd", "abc"))
  val () = eqB ("String.</prefix", true, fn () => String.< ("ab", "abc"))
  val () = eqB ("String.</127-128", true, fn () => String.< ("\127", "\128"))
  val () = eqB ("String.<=/less", true, fn () => String.<= ("abc", "abd"))
  val () = eqB ("String.<=/equal", true, fn () => String.<= ("abc", "abc"))
  val () = eqB ("String.<=/greater", false, fn () => String.<= ("abd", "abc"))
  val () = eqB ("String.<=/empty-empty", true, fn () => String.<= ("", ""))
  val () = eqB ("String.<=/255-0", false, fn () => String.<= ("\255", "\000"))
  val () = eqB ("String.>/less", false, fn () => String.> ("abc", "abd"))
  val () = eqB ("String.>/equal", false, fn () => String.> ("abc", "abc"))
  val () = eqB ("String.>/greater", true, fn () => String.> ("abd", "abc"))
  val () = eqB ("String.>/longer", true, fn () => String.> ("abc", "ab"))
  val () = eqB ("String.>/255-0", true, fn () => String.> ("\255", "\000"))
  val () = eqB ("String.>=/less", false, fn () => String.>= ("abc", "abd"))
  val () = eqB ("String.>=/equal", true, fn () => String.>= ("abc", "abc"))
  val () = eqB ("String.>=/greater", true, fn () => String.>= ("abd", "abc"))
  val () = eqB ("String.>=/empty-empty", true, fn () => String.>= ("", ""))
  val () = eqB ("String.>=/127-128", false, fn () => String.>= ("\127", "\128"))

  (* ---- toString: translate Char.toString ---- *)
  val allChars = String.implode (List.map Char.chr (fromTo (0, 255)))
  val allSML =
    "\\^@\\^A\\^B\\^C\\^D\\^E\\^F\\a\\b\\t\\n\\v\\f\\r\\^N\\^O\\^P\\^Q\\^R\\^S\\^T\\^U\\^V\\^W\\^X\\^Y\\^Z\\^[\\^\\\\^]\\^^\\^_"
    ^ " !\\\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    ^ String.concat (List.map (fn i => "\\" ^ dec3 i) (fromTo (127, 255)))
  val () = eqS ("String.toString/empty", "", fn () => String.toString "")
  val () = eqS ("String.toString/printable", "abc xyz!", fn () => String.toString "abc xyz!")
  val () = eqS ("String.toString/newline", "a\\nb", fn () => String.toString "a\nb")
  val () = eqS ("String.toString/quote-backslash", "\\\"\\\\", fn () => String.toString "\"\\")
  val () = eqS ("String.toString/controls", "\\^@\\^_\\127\\255", fn () => String.toString "\000\031\127\255")
  val () = eqS ("String.toString/two-character-escapes", "\\a\\b\\t\\n\\v\\f\\r", fn () => String.toString "\007\008\009\010\011\012\013")
  val () = eqS ("String.toString/digit-after-decimal-escape", "\\2001", fn () => String.toString "\2001")
  val () = eqS ("String.toString/all-characters", allSML, fn () => String.toString allChars)

  (* ---- fromString ---- *)
  fun fs (label, expected, text) = eqSO (label, expected, fn () => String.fromString text)
  val () = fs ("String.fromString/empty", SOME "", "")
  val () = fs ("String.fromString/printable", SOME "abc", "abc")
  val () = fs ("String.fromString/spaces-are-kept", SOME " a b ", " a b ")
  val () = fs ("String.fromString/single-quote", SOME "it's", "it's")
  val () = fs ("String.fromString/escape-n", SOME "a\nb", "a\\nb")
  val () = fs ("String.fromString/two-character-escapes", SOME "\007\008\009\010\011\012\013\\\"", "\\a\\b\\t\\n\\v\\f\\r\\\\\\\"")
  val () = fs ("String.fromString/control-escapes", SOME "\000\001\026\027\031", "\\^@\\^A\\^Z\\^[\\^_")
  val () = fs ("String.fromString/u-escape-and-decimal", SOME "ABC\255", "\\065\\u0042C\\255")
  val () = fs ("String.fromString/decimal-three-digits-only", SOME "A5", "\\0655")
  val () = fs ("String.fromString/u-escape-four-digits-only", SOME "A0", "\\u00410")
  (* stops at a non-printing character; NONE when it is the first one *)
  val () = fs ("String.fromString/not-printable-stops-at-newline", SOME "abc", "abc\ndef")
  val () = fs ("String.fromString/not-printable-stops-at-del", SOME "ab", "ab\127cd")
  val () = fs ("String.fromString/not-printable-stops-at-200", SOME "ab", "ab\200cd")
  val () = fs ("String.fromString/not-printable-first-newline", NONE, "\nabc")
  val () = fs ("String.fromString/not-printable-first-control-D", NONE, "\004")
  val () = fs ("String.fromString/not-printable-first-200", NONE, "\200")
  (* stops at an improper escape sequence; NONE when nothing precedes it *)
  val () = fs ("String.fromString/bad-escape-stops-at-q", SOME "abc", "abc\\qdef")
  val () = fs ("String.fromString/bad-escape-stops-at-decimal-256", SOME "ab", "ab\\256cd")
  val () = fs ("String.fromString/bad-escape-stops-at-two-digits", SOME "ab", "ab\\12")
  val () = fs ("String.fromString/bad-escape-stops-at-control-96", SOME "ab", "ab\\^`c")
  val () = fs ("String.fromString/bad-escape-stops-at-u-0100", SOME "ab", "ab\\u0100")
  val () = fs ("String.fromString/bad-escape-stops-at-lone-backslash", SOME "ab", "ab\\")
  val () = fs ("String.fromString/bad-escape-stops-at-C-escape", SOME "ab", "ab\\?")
  val () = fs ("String.fromString/bad-escape-first-q", NONE, "\\qabc")
  val () = fs ("String.fromString/bad-escape-first-lone-backslash", NONE, "\\")
  val () = fs ("String.fromString/bad-escape-first-decimal-256", NONE, "\\256")
  (* escaped formatting sequences are passed over, and count as scanned *)
  val () = fs ("String.fromString/format-inside", SOME "abcd", "ab\\ \n\t\\cd")
  val () = fs ("String.fromString/format-first", SOME "abc", "\\ \\abc")
  val () = fs ("String.fromString/format-last", SOME "abc", "abc\\ \\")
  val () = fs ("String.fromString/format-twice", SOME "ab", "a\\ \\\\\n\\b")
  val () = fs ("String.fromString/format-form-feed", SOME "ab", "a\\\012\\b")
  val () = fs ("String.fromString/format-then-escape", SOME "a\nb", "a\\ \\\\nb")
  val () = fs ("String.fromString/format-then-illegal-escape", SOME "", "\\ \\\\q")
  val () = fs ("String.fromString/format-unterminated", SOME "ab", "ab\\ c")
  (* the sample conversions of the page, and those of its implementation note *)
  val () = fs ("String.fromString/sample-1", NONE, "\\q")
  val () = fs ("String.fromString/sample-2", SOME "a", "a\004")
  val () = fs ("String.fromString/sample-3", SOME "a", "a\\ \\\\q")
  val () = fs ("String.fromString/sample-4", SOME "", "\\ \\")
  val () = fs ("String.fromString/sample-5", SOME "", "")
  val () = fs ("String.fromString/sample-6", SOME "", "\\ \\\004")
  val () = fs ("String.fromString/sample-7", NONE, "\\ a")
  val () = fs ("String.fromString/toString-all-characters", SOME allChars, allSML)
  (* SPEC-AMBIGUOUS: a double quote that is not escaped. The page stops the
     conversion at "the end of the source or a non-printing character (i.e.,
     one not satisfying isPrint), or if they encounter an improper escape
     sequence", and the double quote is none of these, so it converts to
     itself; that is what SML/NJ and Poly/ML do, and the reading the test
     takes. MLton stops at it, as "allowed in an SML program" in the CHAR page
     suggests. (For Char.fromString the majority is the other way round, see
     char.sml.) *)
  val () = fs ("String.fromString/unescaped-double-quote", SOME "a\"b", "a\"b")
  val () = fs ("String.fromString/unescaped-double-quote-first", SOME "\"", "\"")

  (*<< scan *)
  (* scanL s: String.scan on the list of the characters of s; the rest of the
     stream is shown as a string. *)
  fun scanL s =
    case String.scan List.getItem (String.explode s) of
      SOME (r, rest) => SOME (r, String.implode rest)
    | NONE => NONE
  fun sc (label, expected, text) = T.eq (T.option (T.pair (T.string, T.string))) (label, expected, fn () => scanL text)
  val () = sc ("String.scan/printable", SOME ("abc", ""), "abc")
  val () = sc ("String.scan/empty", SOME ("", ""), "")
  val () = sc ("String.scan/space-is-not-skipped", SOME (" a", ""), " a")
  val () = sc ("String.scan/stops-at-control-D", SOME ("ab\ncd", "\004xy"), "ab\\ncd\004xy")
  val () = sc ("String.scan/stops-at-newline", SOME ("ab", "\ncd"), "ab\ncd")
  val () = sc ("String.scan/stops-at-illegal-escape", SOME ("abc", "\\qd"), "abc\\qd")
  val () = sc ("String.scan/stops-at-decimal-256", SOME ("ab", "\\256"), "ab\\256")
  val () = sc ("String.scan/NONE-illegal-escape", NONE, "\\qabc")
  val () = sc ("String.scan/NONE-control-D", NONE, "\004abc")
  val () = sc ("String.scan/NONE-format-unterminated", NONE, "\\ a")
  val () = sc ("String.scan/format-only", SOME ("", ""), "\\ \\")
  val () = sc ("String.scan/format-then-control-D", SOME ("", "\004"), "\\ \\\004")
  val () = sc ("String.scan/format-inside-and-last", SOME ("abcd", ""), "ab\\ \\cd\\ \n\\")
  val () = sc ("String.scan/escapes", SOME ("A\t\001\255", ""), "\\065\\t\\^A\\u00ff")
  fun getc (s, i) = if i < String.size s then SOME (String.sub (s, i), (s, i + 1)) else NONE
  val () = T.eq (T.option (T.pair (T.string, T.pair (T.string, T.int))))
             ("String.scan/indexed-reader", SOME ("a\tb", ("xxa\\tb\nc", 6)), fn () => String.scan getc ("xxa\\tb\nc", 2))
  (* fromString is StringCvt.scanString scan *)
  val () = T.eq (T.list (T.option T.string))
             ("String.scan/scanString", [SOME "abc", SOME "", SOME "a\nb", NONE, SOME "", SOME "ab", NONE],
              fn () => List.map (StringCvt.scanString String.scan) ["abc", "", "a\\nb", "\\q", "\\ \\", "ab\004", "\004"])
  (*>> scan *)

  (*<< cstring *)
  (* ---- toCString: translate Char.toCString ---- *)
  val allC =
    "\\000\\001\\002\\003\\004\\005\\006\\a\\b\\t\\n\\v\\f\\r\\016\\017\\020\\021\\022\\023\\024\\025\\026\\027\\030\\031\\032\\033\\034\\035\\036\\037"
    ^ " !\\\"#$%&\\'()*+,-./0123456789:;<=>\\?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    ^ String.concat (List.map (fn i => "\\" ^ String.implode [digit (i div 64), digit (i div 8 mod 8), digit (i mod 8)])
                              (fromTo (127, 255)))
  val () = eqS ("String.toCString/empty", "", fn () => String.toCString "")
  val () = eqS ("String.toCString/printable", "abc xyz!", fn () => String.toCString "abc xyz!")
  val () = eqS ("String.toCString/escaped-printable", "a\\nb\\?c\\'d\\\"e\\\\f", fn () => String.toCString "a\nb?c'd\"e\\f")
  val () = eqS ("String.toCString/nul-and-octal", "\\000\\037\\177\\377", fn () => String.toCString "\000\031\127\255")
  val () = eqS ("String.toCString/nul-then-digit", "\\0001", fn () => String.toCString "\0001")
  val () = eqS ("String.toCString/nul-and-all-characters", allC, fn () => String.toCString allChars)

  (* ---- fromCString: as fromString, with the escape sequences of C ---- *)
  fun fc (label, expected, text) = eqSO (label, expected, fn () => String.fromCString text)
  val () = fc ("String.fromCString/empty", SOME "", "")
  val () = fc ("String.fromCString/printable", SOME "abc", "abc")
  val () = fc ("String.fromCString/spaces-are-kept", SOME " a b ", " a b ")
  val () = fc ("String.fromCString/escape-t", SOME "a\tb", "a\\tb")
  val () = fc ("String.fromCString/two-character-escapes", SOME "\007\008\009\010\011\012\013?\\\"'",
               "\\a\\b\\t\\n\\v\\f\\r\\?\\\\\\\"\\'")
  val () = fc ("String.fromCString/unescaped-single-quote", SOME "a'b", "a'b")
  val () = fc ("String.fromCString/unescaped-question-mark", SOME "a?b", "a?b")
  val () = fc ("String.fromCString/unescaped-double-quote", SOME "a", "a\"b")
  val () = fc ("String.fromCString/unescaped-double-quote-first", NONE, "\"")
  val () = fc ("String.fromCString/octal", SOME "ABC", "\\101\\102C")
  val () = fc ("String.fromCString/octal-short", SOME "\000\010\255", "\\0\\12\\377")
  val () = fc ("String.fromCString/octal-stops-at-8", SOME "\0018", "\\18")
  (* "ooo consists of one to three octal digits": a fourth digit is a character *)
  val () = fc ("String.fromCString/octal-three-digits-only", SOME "A1", "\\1011")
  val () = fc ("String.fromCString/hex", SOME "AB", "\\x41\\x42")
  val () = fc ("String.fromCString/hex-stops-at-G", SOME "AG", "\\x41G")
  (* "the longest sequence of such characters": \x42C is 1068, which is no character *)
  val () = fc ("String.fromCString/stops-at-hex-longest-sequence", SOME "A", "\\x41\\x42C")
  val () = fc ("String.fromCString/control", SOME "\001\008", "\\^A\\^H")
  val () = fc ("String.fromCString/stops-at-illegal-escape", SOME "abc", "abc\\qdef")
  val () = fc ("String.fromCString/stops-at-newline", SOME "ab", "ab\ncd")
  val () = fc ("String.fromCString/stops-at-octal-400", SOME "ab", "ab\\400")
  val () = fc ("String.fromCString/stops-at-hex-100", SOME "ab", "ab\\x100")
  val () = fc ("String.fromCString/stops-at-hex-without-digits", SOME "ab", "ab\\x")
  val () = fc ("String.fromCString/NONE-illegal-escape", NONE, "\\qabc")
  val () = fc ("String.fromCString/NONE-newline", NONE, "\nabc")
  val () = fc ("String.fromCString/NONE-lone-backslash", NONE, "\\")
  val () = fc ("String.fromCString/toCString-all-characters", SOME allChars, allC)
  val () = T.seed 8
  val () = T.repeat (40, fn k =>
    let
      val s = String.implode (List.tabulate (T.range (0, 12), fn _ =>
                if T.range (0, 1) = 0 then Char.chr (T.range (0, 255)) else T.oneOf [#"0", #"1", #"7", #"8", #"9", #"a", #"f", #"\\", #"?", #"'"]))
    in
      eqSO ("String.fromCString/toCString-" ^ Int.toString k, SOME s, fn () => String.fromCString (String.toCString s))
    end)
  (*>> cstring *)

  (* ---- laws, on pseudo-random strings ---- *)
  (* models on lists of characters *)
  fun prefixL ([], _) = true
    | prefixL (_, []) = false
    | prefixL (x :: xs, y :: ys) = x = y andalso prefixL (xs, ys)
  fun substringL (p : char list, []) = List.null p
    | substringL (p, s as _ :: t) = prefixL (p, s) orelse substringL (p, t)
  fun fieldsL s =
    let
      fun go ([], cur, acc) = List.rev (String.implode (List.rev cur) :: acc)
        | go (c :: cs, cur, acc) =
            if isBar c then go (cs, [], String.implode (List.rev cur) :: acc) else go (cs, c :: cur, acc)
    in
      go (String.explode s, [], [])
    end
  fun compareL (s, t) = List.collate Int.compare (List.map Char.ord (String.explode s), List.map Char.ord (String.explode t))

  (* any characters, with many that matter to the escape sequences *)
  fun randomString () =
    String.implode (List.tabulate (T.range (0, 12), fn _ =>
      if T.range (0, 1) = 0 then Char.chr (T.range (0, 255))
      else T.oneOf [#"0", #"1", #"9", #"a", #"n", #"^", #"@", #"\\", #"\"", #" ", #"\n", #"\000", #"\127", #"\200"]))
  (* strings over a small alphabet, so that they share parts *)
  fun randomWord n = String.implode (List.tabulate (T.range (0, n), fn _ => T.oneOf [#"a", #"b", #"|"]))

  val () = T.seed 7
  val () = T.repeat (40, fn k =>
    let
      val n = Int.toString k
      val s = randomString ()
      val t = randomString ()
      val u = randomWord 10
      val v = randomWord 10
      val p = randomWord 3
      val i = T.range (0, String.size s)
      val j = T.range (0, String.size s - i)
      val rot = fn c => Char.chr ((Char.ord c + 1) mod 256)
      val dup = fn c => if c = #"a" then "" else String.implode [c, c]
    in
      eqS ("String.implode/explode-" ^ n, s, fn () => String.implode (String.explode s));
      eqS ("String.implode/concat-map-str-" ^ n, String.concat (List.map String.str (String.explode s)),
           fn () => String.implode (String.explode s));
      eqI ("String.size/length-explode-" ^ n, List.length (String.explode s), fn () => String.size s);
      eqI ("String.^/size-" ^ n, String.size s + String.size t, fn () => String.size (s ^ t));
      eqCL ("String.^/explode-" ^ n, String.explode s @ String.explode t, fn () => String.explode (s ^ t));
      eqS ("String.concat/law-" ^ n, s ^ t ^ s, fn () => String.concat [s, t, s]);
      eqS ("String.concatWith/law-" ^ n, s ^ t ^ u ^ t ^ s, fn () => String.concatWith t [s, u, s]);
      eqCL ("String.sub/explode-" ^ n, String.explode s,
            fn () => List.tabulate (String.size s, fn m => String.sub (s, m)));
      eqS ("String.substring/take-drop-" ^ n, String.implode (List.take (List.drop (String.explode s, i), j)),
           fn () => String.substring (s, i, j));
      eqS ("String.extract/SOME-law-" ^ n, String.implode (List.take (List.drop (String.explode s, i), j)),
           fn () => String.extract (s, i, SOME j));
      eqS ("String.extract/NONE-law-" ^ n, String.implode (List.drop (String.explode s, i)),
           fn () => String.extract (s, i, NONE));
      eqS ("String.map/law-" ^ n, String.implode (List.map rot (String.explode s)), fn () => String.map rot s);
      eqS ("String.translate/law-" ^ n, String.concat (List.map dup (String.explode u)), fn () => String.translate dup u);
      eqSL ("String.fields/law-" ^ n, fieldsL u, fn () => String.fields isBar u);
      eqS ("String.fields/concatWith-" ^ n, u, fn () => String.concatWith "|" (String.fields isBar u));
      eqSL ("String.tokens/law-" ^ n, List.filter (fn f => f <> "") (fieldsL u), fn () => String.tokens isBar u);
      eqB ("String.isPrefix/law-" ^ n, prefixL (String.explode p, String.explode u), fn () => String.isPrefix p u);
      eqB ("String.isSuffix/law-" ^ n, prefixL (List.rev (String.explode p), List.rev (String.explode u)),
           fn () => String.isSuffix p u);
      eqB ("String.isSubstring/law-" ^ n, substringL (String.explode p, String.explode u), fn () => String.isSubstring p u);
      eqB ("String.isSubstring/of-concatenation-" ^ n, true, fn () => String.isSubstring u (s ^ u ^ t));
      eqOrd ("String.compare/law-" ^ n, compareL (s, t), fn () => String.compare (s, t));
      eqOrd ("String.compare/law-words-" ^ n, compareL (u, v), fn () => String.compare (u, v));
      eqOrd ("String.compare/reflexive-" ^ n, EQUAL, fn () => String.compare (s, s));
      eqOrd ("String.collate/law-" ^ n, compareL (u, v), fn () => String.collate Char.compare (u, v));
      eqOrd ("String.collate/law-bytes-" ^ n, compareL (s, t), fn () => String.collate Char.compare (s, t));
      eqB ("String.</law-" ^ n, compareL (u, v) = LESS, fn () => String.< (u, v));
      eqB ("String.<=/law-" ^ n, compareL (u, v) <> GREATER, fn () => String.<= (u, v));
      eqB ("String.>/law-" ^ n, compareL (u, v) = GREATER, fn () => String.> (u, v));
      eqB ("String.>=/law-" ^ n, compareL (u, v) <> LESS, fn () => String.>= (u, v));
      eqB ("String.</law-bytes-" ^ n, compareL (s, t) = LESS, fn () => String.< (s, t));
      eqB ("String.>=/law-bytes-" ^ n, compareL (s, t) <> LESS, fn () => String.>= (s, t));
      eqS ("String.toString/law-" ^ n, String.concat (List.map Char.toString (String.explode s)), fn () => String.toString s);
      eqSO ("String.fromString/toString-" ^ n, SOME s, fn () => String.fromString (String.toString s))
    end)
end

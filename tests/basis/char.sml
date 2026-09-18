(* requires: Char String *)
(* The Char structure (signature CHAR), for 8-bit characters. Expected values
   follow the text of https://smlfamily.github.io/Basis/char.html; the sets of
   the predicates are those of its Discussion section, which makes them
   independent of the locale: no character above 127 is a letter, a control
   character, printable, ...

   In the texts given to fromString, scan and fromCString every backslash is
   written "\\", so "\\n" is the two characters backslash, n. *)
structure TestChar =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqC = T.eq T.char
  val eqS = T.eq T.string
  val eqOrd = T.eq T.order
  val eqCO = T.eq (T.option T.char)
  val eqIL = T.eq (T.list T.int)
  val eqSL = T.eq (T.list T.string)

  fun fromTo (lo, hi) = if lo > hi then [] else lo :: fromTo (lo + 1, hi)
  val all = fromTo (0, 255)   (* the code of every character *)

  (* The codes in [lo, hi] of the characters that satisfy p. *)
  fun codesIn (lo, hi) p = List.filter (fn i => p (Char.chr i)) (fromTo (lo, hi))
  fun ascii p = codesIn (0, 127) p
  fun latin1 p = codesIn (128, 255) p

  (* allPairs f: f holds for every pair of character codes. *)
  fun allPairs f = List.all (fn i => List.all (fn j => f (i, j)) all) all

  fun digit d = Char.chr (48 + d)
  fun hexDigit d = if d < 10 then digit d else Char.chr (87 + d)   (* a-f *)
  fun dec3 i = String.implode [digit (i div 100), digit (i div 10 mod 10), digit (i mod 10)]
  fun oct3 i = String.implode [digit (i div 64), digit (i div 8 mod 8), digit (i mod 8)]
  fun hex2 i = String.implode [hexDigit (i div 16), hexDigit (i mod 16)]

  (* code r: the code of the character of a conversion, ~1 for NONE. *)
  fun code (SOME c) = Char.ord c
    | code NONE = ~1

  (* ---- minChar, maxChar, maxOrd ---- *)
  val () = eqC ("Char.minChar/chr-0", #"\000", fn () => Char.minChar)
  val () = eqI ("Char.minChar/ord", 0, fn () => Char.ord Char.minChar)
  val () = eqC ("Char.maxChar/chr-255", #"\255", fn () => Char.maxChar)
  val () = eqB ("Char.maxChar/chr-maxOrd", true, fn () => Char.maxChar = Char.chr Char.maxOrd)
  val () = eqI ("Char.maxOrd/255", 255, fn () => Char.maxOrd)
  val () = eqI ("Char.maxOrd/ord-maxChar", 255, fn () => Char.ord Char.maxChar)

  (* ---- ord, chr ---- *)
  val () = eqI ("Char.ord/A", 65, fn () => Char.ord #"A")
  val () = eqI ("Char.ord/a", 97, fn () => Char.ord #"a")
  val () = eqI ("Char.ord/zero", 48, fn () => Char.ord #"0")
  val () = eqI ("Char.ord/space", 32, fn () => Char.ord #" ")
  val () = eqI ("Char.ord/newline", 10, fn () => Char.ord #"\n")
  val () = eqI ("Char.ord/nul", 0, fn () => Char.ord #"\000")
  val () = eqI ("Char.ord/non-negative-128", 128, fn () => Char.ord #"\128")
  val () = eqI ("Char.ord/non-negative-255", 255, fn () => Char.ord #"\255")
  val () = eqC ("Char.chr/A", #"A", fn () => Char.chr 65)
  val () = eqC ("Char.chr/zero", #"\000", fn () => Char.chr 0)
  val () = eqC ("Char.chr/maxOrd", #"\255", fn () => Char.chr 255)
  val () = eqIL ("Char.chr/ord-all", all, fn () => List.map (Char.ord o Char.chr) all)
  val () = T.raises ("Char.chr/Chr-negative", T.isChr, fn () => Char.chr ~1)
  val () = T.raises ("Char.chr/Chr-above-maxOrd", T.isChr, fn () => Char.chr 256)
  val () = T.raises ("Char.chr/Chr-maxOrd-plus-1", T.isChr, fn () => Char.chr (Char.maxOrd + 1))
  val () = T.raises ("Char.chr/Chr-large", T.isChr, fn () => Char.chr 100000)
  val () = T.raises ("Char.chr/Chr-large-negative", T.isChr, fn () => Char.chr ~100000)
  val () = T.raises ("Char.chr/Chr-maxInt", T.isChr,
                     fn () => Char.chr (case Int.maxInt of SOME m => m | NONE => 1073741823))
  val () = T.raises ("Char.chr/Chr-minInt", T.isChr,
                     fn () => Char.chr (case Int.minInt of SOME m => m | NONE => ~1073741824))
  val () = T.raises ("Char.chr/Chr-is-General.Chr", fn General.Chr => true | _ => false, fn () => Char.chr 256)

  (* ---- succ, pred ---- *)
  val () = eqC ("Char.succ/a", #"b", fn () => Char.succ #"a")
  val () = eqC ("Char.succ/minChar", #"\001", fn () => Char.succ Char.minChar)
  val () = eqC ("Char.succ/127", #"\128", fn () => Char.succ #"\127")
  val () = eqC ("Char.succ/254", #"\255", fn () => Char.succ #"\254")
  val () = T.raises ("Char.succ/Chr-maxChar", T.isChr, fn () => Char.succ Char.maxChar)
  val () = T.raises ("Char.succ/Chr-255", T.isChr, fn () => Char.succ #"\255")
  val () = eqIL ("Char.succ/all", fromTo (1, 255),
                 fn () => List.map (Char.ord o Char.succ o Char.chr) (fromTo (0, 254)))
  val () = eqC ("Char.pred/b", #"a", fn () => Char.pred #"b")
  val () = eqC ("Char.pred/maxChar", #"\254", fn () => Char.pred Char.maxChar)
  val () = eqC ("Char.pred/128", #"\127", fn () => Char.pred #"\128")
  val () = eqC ("Char.pred/1", #"\000", fn () => Char.pred #"\001")
  val () = T.raises ("Char.pred/Chr-minChar", T.isChr, fn () => Char.pred Char.minChar)
  val () = T.raises ("Char.pred/Chr-0", T.isChr, fn () => Char.pred #"\000")
  val () = eqIL ("Char.pred/all", fromTo (0, 254),
                 fn () => List.map (Char.ord o Char.pred o Char.chr) (fromTo (1, 255)))

  (* ---- compare, <, <=, >, >=: the order of the codes, which are non-negative ---- *)
  val () = eqOrd ("Char.compare/less", LESS, fn () => Char.compare (#"a", #"b"))
  val () = eqOrd ("Char.compare/equal", EQUAL, fn () => Char.compare (#"a", #"a"))
  val () = eqOrd ("Char.compare/greater", GREATER, fn () => Char.compare (#"b", #"a"))
  val () = eqOrd ("Char.compare/upper-before-lower", LESS, fn () => Char.compare (#"Z", #"a"))
  val () = eqOrd ("Char.compare/127-128", LESS, fn () => Char.compare (#"\127", #"\128"))
  val () = eqOrd ("Char.compare/255-0", GREATER, fn () => Char.compare (#"\255", #"\000"))
  val () = eqOrd ("Char.compare/min-max", LESS, fn () => Char.compare (Char.minChar, Char.maxChar))
  val () = T.check ("Char.compare/all-pairs",
                    fn () => allPairs (fn (i, j) => Char.compare (Char.chr i, Char.chr j) = Int.compare (i, j)))

  val () = eqB ("Char.</less", true, fn () => Char.< (#"a", #"b"))
  val () = eqB ("Char.</equal", false, fn () => Char.< (#"a", #"a"))
  val () = eqB ("Char.</greater", false, fn () => Char.< (#"b", #"a"))
  val () = eqB ("Char.</127-128", true, fn () => Char.< (#"\127", #"\128"))
  val () = eqB ("Char.</255-0", false, fn () => Char.< (#"\255", #"\000"))
  val () = T.check ("Char.</all-pairs", fn () => allPairs (fn (i, j) => Char.< (Char.chr i, Char.chr j) = (i < j)))
  val () = eqB ("Char.<=/less", true, fn () => Char.<= (#"a", #"b"))
  val () = eqB ("Char.<=/equal", true, fn () => Char.<= (#"a", #"a"))
  val () = eqB ("Char.<=/greater", false, fn () => Char.<= (#"b", #"a"))
  val () = eqB ("Char.<=/128-127", false, fn () => Char.<= (#"\128", #"\127"))
  val () = T.check ("Char.<=/all-pairs", fn () => allPairs (fn (i, j) => Char.<= (Char.chr i, Char.chr j) = (i <= j)))
  val () = eqB ("Char.>/less", false, fn () => Char.> (#"a", #"b"))
  val () = eqB ("Char.>/equal", false, fn () => Char.> (#"a", #"a"))
  val () = eqB ("Char.>/greater", true, fn () => Char.> (#"b", #"a"))
  val () = eqB ("Char.>/255-0", true, fn () => Char.> (#"\255", #"\000"))
  val () = T.check ("Char.>/all-pairs", fn () => allPairs (fn (i, j) => Char.> (Char.chr i, Char.chr j) = (i > j)))
  val () = eqB ("Char.>=/less", false, fn () => Char.>= (#"a", #"b"))
  val () = eqB ("Char.>=/equal", true, fn () => Char.>= (#"a", #"a"))
  val () = eqB ("Char.>=/greater", true, fn () => Char.>= (#"b", #"a"))
  val () = eqB ("Char.>=/127-128", false, fn () => Char.>= (#"\127", #"\128"))
  val () = T.check ("Char.>=/all-pairs", fn () => allPairs (fn (i, j) => Char.>= (Char.chr i, Char.chr j) = (i >= j)))

  (* ---- contains, notContains ---- *)
  val () = eqB ("Char.contains/first", true, fn () => Char.contains "abc" #"a")
  val () = eqB ("Char.contains/last", true, fn () => Char.contains "abc" #"c")
  val () = eqB ("Char.contains/absent", false, fn () => Char.contains "abc" #"d")
  val () = eqB ("Char.contains/case-matters", false, fn () => Char.contains "abc" #"A")
  val () = eqB ("Char.contains/empty-string", false, fn () => Char.contains "" #"a")
  val () = eqB ("Char.contains/repeated", true, fn () => Char.contains "aab" #"a")
  val () = eqB ("Char.contains/nul", true, fn () => Char.contains "a\000b" #"\000")
  val () = eqB ("Char.contains/255", true, fn () => Char.contains "\000\255" #"\255")
  val () = eqB ("Char.contains/254-absent", false, fn () => Char.contains "\000\255" #"\254")
  (* "hello, world\n": \n , space d e h l o r w *)
  val () = eqIL ("Char.contains/all-characters", [10, 32, 44, 100, 101, 104, 108, 111, 114, 119],
                 fn () => let val p = Char.contains "hello, world\n" in codesIn (0, 255) p end)
  val () = eqIL ("Char.contains/every-character", all,
                 fn () => codesIn (0, 255) (Char.contains (String.implode (List.map Char.chr all))))
  val () = eqB ("Char.notContains/first", false, fn () => Char.notContains "abc" #"a")
  val () = eqB ("Char.notContains/last", false, fn () => Char.notContains "abc" #"c")
  val () = eqB ("Char.notContains/absent", true, fn () => Char.notContains "abc" #"d")
  val () = eqB ("Char.notContains/empty-string", true, fn () => Char.notContains "" #"a")
  val () = eqB ("Char.notContains/255", false, fn () => Char.notContains "\000\255" #"\255")
  val () = eqIL ("Char.notContains/all-characters",
                 fromTo (0, 9) @ fromTo (11, 31) @ fromTo (33, 43) @ fromTo (45, 99) @ [102, 103]
                 @ fromTo (105, 107) @ [109, 110, 112, 113] @ fromTo (115, 118) @ fromTo (120, 255),
                 fn () => let val p = Char.notContains "hello, world\n" in codesIn (0, 255) p end)
  val () = eqIL ("Char.notContains/empty-string-all", all, fn () => codesIn (0, 255) (Char.notContains ""))

  (* ---- the predicates: their exact sets (Discussion section of the page);
          no character above 127 satisfies any of them ---- *)
  val () = eqIL ("Char.isAscii/ascii", fromTo (0, 127), fn () => ascii Char.isAscii)
  val () = eqIL ("Char.isAscii/latin1", [], fn () => latin1 Char.isAscii)
  val () = eqB ("Char.isAscii/127", true, fn () => Char.isAscii #"\127")
  val () = eqB ("Char.isAscii/128", false, fn () => Char.isAscii #"\128")

  val () = eqIL ("Char.isUpper/ascii", fromTo (65, 90), fn () => ascii Char.isUpper)
  val () = eqIL ("Char.isUpper/latin1", [], fn () => latin1 Char.isUpper)
  val () = eqB ("Char.isUpper/A", true, fn () => Char.isUpper #"A")
  val () = eqB ("Char.isUpper/a", false, fn () => Char.isUpper #"a")
  val () = eqB ("Char.isUpper/A-grave", false, fn () => Char.isUpper #"\192")

  val () = eqIL ("Char.isLower/ascii", fromTo (97, 122), fn () => ascii Char.isLower)
  val () = eqIL ("Char.isLower/latin1", [], fn () => latin1 Char.isLower)
  val () = eqB ("Char.isLower/z", true, fn () => Char.isLower #"z")
  val () = eqB ("Char.isLower/Z", false, fn () => Char.isLower #"Z")
  val () = eqB ("Char.isLower/a-grave", false, fn () => Char.isLower #"\224")

  val () = eqIL ("Char.isDigit/ascii", fromTo (48, 57), fn () => ascii Char.isDigit)
  val () = eqIL ("Char.isDigit/latin1", [], fn () => latin1 Char.isDigit)
  val () = eqB ("Char.isDigit/9", true, fn () => Char.isDigit #"9")
  val () = eqB ("Char.isDigit/colon", false, fn () => Char.isDigit #":")
  val () = eqB ("Char.isDigit/superscript-two", false, fn () => Char.isDigit #"\178")

  val () = eqIL ("Char.isAlpha/ascii", fromTo (65, 90) @ fromTo (97, 122), fn () => ascii Char.isAlpha)
  val () = eqIL ("Char.isAlpha/latin1", [], fn () => latin1 Char.isAlpha)
  val () = eqB ("Char.isAlpha/m", true, fn () => Char.isAlpha #"m")
  val () = eqB ("Char.isAlpha/underscore", false, fn () => Char.isAlpha #"_")
  val () = eqB ("Char.isAlpha/e-acute", false, fn () => Char.isAlpha #"\233")

  val () = eqIL ("Char.isAlphaNum/ascii", fromTo (48, 57) @ fromTo (65, 90) @ fromTo (97, 122),
                 fn () => ascii Char.isAlphaNum)
  val () = eqIL ("Char.isAlphaNum/latin1", [], fn () => latin1 Char.isAlphaNum)
  val () = eqB ("Char.isAlphaNum/0", true, fn () => Char.isAlphaNum #"0")
  val () = eqB ("Char.isAlphaNum/underscore", false, fn () => Char.isAlphaNum #"_")

  val () = eqIL ("Char.isHexDigit/ascii", fromTo (48, 57) @ fromTo (65, 70) @ fromTo (97, 102),
                 fn () => ascii Char.isHexDigit)
  val () = eqIL ("Char.isHexDigit/latin1", [], fn () => latin1 Char.isHexDigit)
  val () = eqB ("Char.isHexDigit/F", true, fn () => Char.isHexDigit #"F")
  val () = eqB ("Char.isHexDigit/f", true, fn () => Char.isHexDigit #"f")
  val () = eqB ("Char.isHexDigit/G", false, fn () => Char.isHexDigit #"G")
  val () = eqB ("Char.isHexDigit/g", false, fn () => Char.isHexDigit #"g")

  val () = eqIL ("Char.isGraph/ascii", fromTo (33, 126), fn () => ascii Char.isGraph)
  val () = eqIL ("Char.isGraph/latin1", [], fn () => latin1 Char.isGraph)
  val () = eqB ("Char.isGraph/space", false, fn () => Char.isGraph #" ")
  val () = eqB ("Char.isGraph/tilde", true, fn () => Char.isGraph #"~")
  val () = eqB ("Char.isGraph/del", false, fn () => Char.isGraph #"\127")

  val () = eqIL ("Char.isPrint/ascii", fromTo (32, 126), fn () => ascii Char.isPrint)
  val () = eqIL ("Char.isPrint/latin1", [], fn () => latin1 Char.isPrint)
  val () = eqB ("Char.isPrint/space", true, fn () => Char.isPrint #" ")
  val () = eqB ("Char.isPrint/tab", false, fn () => Char.isPrint #"\t")
  val () = eqB ("Char.isPrint/del", false, fn () => Char.isPrint #"\127")
  val () = eqB ("Char.isPrint/no-break-space", false, fn () => Char.isPrint #"\160")

  val () = eqIL ("Char.isPunct/ascii", fromTo (33, 47) @ fromTo (58, 64) @ fromTo (91, 96) @ fromTo (123, 126),
                 fn () => ascii Char.isPunct)
  val () = eqIL ("Char.isPunct/latin1", [], fn () => latin1 Char.isPunct)
  val () = eqB ("Char.isPunct/underscore", true, fn () => Char.isPunct #"_")
  val () = eqB ("Char.isPunct/space", false, fn () => Char.isPunct #" ")
  val () = eqB ("Char.isPunct/inverted-question-mark", false, fn () => Char.isPunct #"\191")

  val () = eqIL ("Char.isCntrl/ascii", fromTo (0, 31) @ [127], fn () => ascii Char.isCntrl)
  val () = eqIL ("Char.isCntrl/latin1", [], fn () => latin1 Char.isCntrl)
  val () = eqB ("Char.isCntrl/nul", true, fn () => Char.isCntrl #"\000")
  val () = eqB ("Char.isCntrl/del", true, fn () => Char.isCntrl #"\127")
  val () = eqB ("Char.isCntrl/space", false, fn () => Char.isCntrl #" ")
  val () = eqB ("Char.isCntrl/128-not-ascii", false, fn () => Char.isCntrl #"\128")

  val () = eqIL ("Char.isSpace/ascii", [9, 10, 11, 12, 13, 32], fn () => ascii Char.isSpace)
  val () = eqIL ("Char.isSpace/latin1", [], fn () => latin1 Char.isSpace)
  val () = eqB ("Char.isSpace/vertical-tab", true, fn () => Char.isSpace #"\011")
  val () = eqB ("Char.isSpace/backspace", false, fn () => Char.isSpace #"\008")
  val () = eqB ("Char.isSpace/no-break-space", false, fn () => Char.isSpace #"\160")

  (* ---- toLower, toUpper: ASCII letters only ---- *)
  val () = eqC ("Char.toLower/A", #"a", fn () => Char.toLower #"A")
  val () = eqC ("Char.toLower/Z", #"z", fn () => Char.toLower #"Z")
  val () = eqC ("Char.toLower/a", #"a", fn () => Char.toLower #"a")
  val () = eqC ("Char.toLower/at-sign", #"@", fn () => Char.toLower #"@")
  val () = eqC ("Char.toLower/bracket", #"[", fn () => Char.toLower #"[")
  val () = eqC ("Char.toLower/digit", #"5", fn () => Char.toLower #"5")
  val () = eqC ("Char.toLower/A-grave", #"\192", fn () => Char.toLower #"\192")
  val () = eqIL ("Char.toLower/all", fromTo (0, 64) @ fromTo (97, 122) @ fromTo (91, 255),
                 fn () => List.map (Char.ord o Char.toLower o Char.chr) all)
  val () = eqC ("Char.toUpper/a", #"A", fn () => Char.toUpper #"a")
  val () = eqC ("Char.toUpper/z", #"Z", fn () => Char.toUpper #"z")
  val () = eqC ("Char.toUpper/A", #"A", fn () => Char.toUpper #"A")
  val () = eqC ("Char.toUpper/backquote", #"`", fn () => Char.toUpper #"`")
  val () = eqC ("Char.toUpper/brace", #"{", fn () => Char.toUpper #"{")
  val () = eqC ("Char.toUpper/a-grave", #"\224", fn () => Char.toUpper #"\224")
  val () = eqC ("Char.toUpper/y-diaeresis", #"\255", fn () => Char.toUpper #"\255")
  val () = eqIL ("Char.toUpper/all", fromTo (0, 96) @ fromTo (65, 90) @ fromTo (123, 255),
                 fn () => List.map (Char.ord o Char.toUpper o Char.chr) all)

  (* ---- toString ---- *)
  val () = eqS ("Char.toString/letter", "a", fn () => Char.toString #"a")
  val () = eqS ("Char.toString/space", " ", fn () => Char.toString #" ")
  val () = eqS ("Char.toString/tilde", "~", fn () => Char.toString #"~")
  val () = eqS ("Char.toString/single-quote", "'", fn () => Char.toString #"'")
  val () = eqS ("Char.toString/question-mark", "?", fn () => Char.toString #"?")
  val () = eqS ("Char.toString/backslash", "\\\\", fn () => Char.toString #"\\")
  val () = eqS ("Char.toString/double-quote", "\\\"", fn () => Char.toString #"\"")
  val () = eqS ("Char.toString/alert", "\\a", fn () => Char.toString #"\007")
  val () = eqS ("Char.toString/backspace", "\\b", fn () => Char.toString #"\008")
  val () = eqS ("Char.toString/tab", "\\t", fn () => Char.toString #"\009")
  val () = eqS ("Char.toString/newline", "\\n", fn () => Char.toString #"\010")
  val () = eqS ("Char.toString/vertical-tab", "\\v", fn () => Char.toString #"\011")
  val () = eqS ("Char.toString/form-feed", "\\f", fn () => Char.toString #"\012")
  val () = eqS ("Char.toString/carriage-return", "\\r", fn () => Char.toString #"\013")
  val () = eqS ("Char.toString/nul", "\\^@", fn () => Char.toString #"\000")
  val () = eqS ("Char.toString/control-A", "\\^A", fn () => Char.toString #"\001")
  val () = eqS ("Char.toString/control-Z", "\\^Z", fn () => Char.toString #"\026")
  val () = eqS ("Char.toString/escape", "\\^[", fn () => Char.toString #"\027")
  val () = eqS ("Char.toString/control-backslash", "\\^\\", fn () => Char.toString #"\028")
  val () = eqS ("Char.toString/control-underscore", "\\^_", fn () => Char.toString #"\031")
  val () = eqI ("Char.toString/control-size", 3, fn () => String.size (Char.toString #"\000"))
  val () = eqS ("Char.toString/del", "\\127", fn () => Char.toString #"\127")
  val () = eqS ("Char.toString/128", "\\128", fn () => Char.toString #"\128")
  val () = eqS ("Char.toString/255", "\\255", fn () => Char.toString #"\255")
  val () = eqSL ("Char.toString/all-below-32",
                 ["\\^@", "\\^A", "\\^B", "\\^C", "\\^D", "\\^E", "\\^F", "\\a",
                  "\\b", "\\t", "\\n", "\\v", "\\f", "\\r", "\\^N", "\\^O",
                  "\\^P", "\\^Q", "\\^R", "\\^S", "\\^T", "\\^U", "\\^V", "\\^W",
                  "\\^X", "\\^Y", "\\^Z", "\\^[", "\\^\\", "\\^]", "\\^^", "\\^_"],
                 fn () => List.map (Char.toString o Char.chr) (fromTo (0, 31)))
  val () = eqS ("Char.toString/all-printable",
                " !\\\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~",
                fn () => String.concat (List.map (Char.toString o Char.chr) (fromTo (32, 126))))
  val () = eqSL ("Char.toString/all-above-126", List.map (fn i => "\\" ^ dec3 i) (fromTo (127, 255)),
                 fn () => List.map (Char.toString o Char.chr) (fromTo (127, 255)))

  (* ---- fromString ---- *)
  fun fs (label, expected, text) = eqCO (label, expected, fn () => Char.fromString text)
  val () = fs ("Char.fromString/letter", SOME #"a", "a")
  val () = fs ("Char.fromString/rest-ignored", SOME #"a", "abc")
  val () = fs ("Char.fromString/space", SOME #" ", " x")
  val () = fs ("Char.fromString/empty", NONE, "")
  val () = fs ("Char.fromString/single-quote", SOME #"'", "'")
  val () = fs ("Char.fromString/printable-only-newline", NONE, "\n")
  val () = fs ("Char.fromString/printable-only-tab", NONE, "\ta")
  val () = fs ("Char.fromString/printable-only-del", NONE, "\127")
  val () = fs ("Char.fromString/printable-only-128", NONE, "\128")
  val () = fs ("Char.fromString/printable-only-255", NONE, "\255")
  (* A first character outside [0x20, 0x7E], and a backslash by itself, give
     NONE; the double quote (34) is checked by itself below. *)
  val () = eqIL ("Char.fromString/printable-only-all-converted",
                 fromTo (32, 33) @ fromTo (35, 91) @ fromTo (93, 126),
                 fn () => List.filter (fn i => i <> 34 andalso Char.fromString (String.str (Char.chr i)) = SOME (Char.chr i)) all)
  val () = eqIL ("Char.fromString/printable-only-all-rejected",
                 fromTo (0, 31) @ [92] @ fromTo (127, 255),
                 fn () => List.filter (fn i => i <> 34 andalso Char.fromString (String.str (Char.chr i)) = NONE) all)
  (* SPEC-AMBIGUOUS: the page lets fromString scan a character "as allowed in
     an SML program", where a double quote must be escaped, but names only
     non-printable characters and illegal escape sequences as the reasons for
     NONE. MLton and SML/NJ return NONE, Poly/ML returns the double quote;
     the test takes the reading of the majority. (For String.fromString the
     majority is the other way round, see string.sml.) *)
  val () = fs ("Char.fromString/unescaped-double-quote", NONE, "\"")

  val () = fs ("Char.fromString/escape-a", SOME #"\007", "\\a")
  val () = fs ("Char.fromString/escape-b", SOME #"\008", "\\b")
  val () = fs ("Char.fromString/escape-t", SOME #"\009", "\\t")
  val () = fs ("Char.fromString/escape-n", SOME #"\010", "\\n")
  val () = fs ("Char.fromString/escape-v", SOME #"\011", "\\v")
  val () = fs ("Char.fromString/escape-f", SOME #"\012", "\\f")
  val () = fs ("Char.fromString/escape-r", SOME #"\013", "\\r")
  val () = fs ("Char.fromString/escape-backslash", SOME #"\\", "\\\\")
  val () = fs ("Char.fromString/escape-double-quote", SOME #"\"", "\\\"")
  val () = fs ("Char.fromString/escape-rest-ignored", SOME #"\010", "\\nabc")
  (* The second characters that make a complete escape sequence: " \ a b f n r t v *)
  val () = eqIL ("Char.fromString/two-character-escapes", [34, 92, 97, 98, 102, 110, 114, 116, 118],
                 fn () => List.filter (fn i => Char.fromString ("\\" ^ String.str (Char.chr i)) <> NONE) all)
  val () = fs ("Char.fromString/illegal-q", NONE, "\\q")
  val () = fs ("Char.fromString/illegal-lone-backslash", NONE, "\\")
  val () = fs ("Char.fromString/illegal-question-mark", NONE, "\\?")
  val () = fs ("Char.fromString/illegal-single-quote", NONE, "\\'")
  val () = fs ("Char.fromString/illegal-x", NONE, "\\x41")
  val () = fs ("Char.fromString/illegal-upper-N", NONE, "\\N")

  val () = fs ("Char.fromString/control-at", SOME #"\000", "\\^@")
  val () = fs ("Char.fromString/control-A", SOME #"\001", "\\^A")
  val () = fs ("Char.fromString/control-H-is-backspace", SOME #"\008", "\\^H")
  val () = fs ("Char.fromString/control-Z", SOME #"\026", "\\^Z")
  val () = fs ("Char.fromString/control-bracket", SOME #"\027", "\\^[")
  val () = fs ("Char.fromString/control-backslash", SOME #"\028", "\\^\\")
  val () = fs ("Char.fromString/control-underscore", SOME #"\031", "\\^_")
  val () = fs ("Char.fromString/control-rest-ignored", SOME #"\001", "\\^AB")
  val () = fs ("Char.fromString/control-range-63", NONE, "\\^?")
  val () = fs ("Char.fromString/control-range-96", NONE, "\\^`")
  val () = fs ("Char.fromString/control-range-lowercase", NONE, "\\^a")
  val () = fs ("Char.fromString/control-incomplete", NONE, "\\^")
  val () = eqIL ("Char.fromString/control-all", fromTo (0, 31),
                 fn () => List.map (fn i => code (Char.fromString ("\\^" ^ String.str (Char.chr i)))) (fromTo (64, 95)))
  val () = eqIL ("Char.fromString/control-range-all", [],
                 fn () => List.filter (fn i => Char.fromString ("\\^" ^ String.str (Char.chr i)) <> NONE)
                                      (fromTo (0, 63) @ fromTo (96, 255)))

  val () = fs ("Char.fromString/decimal-065", SOME #"A", "\\065")
  val () = fs ("Char.fromString/decimal-000", SOME #"\000", "\\000")
  val () = fs ("Char.fromString/decimal-255", SOME #"\255", "\\255")
  val () = fs ("Char.fromString/decimal-256", NONE, "\\256")
  val () = fs ("Char.fromString/decimal-999", NONE, "\\999")
  val () = fs ("Char.fromString/decimal-one-digit", NONE, "\\6")
  val () = fs ("Char.fromString/decimal-two-digits", NONE, "\\65")
  val () = fs ("Char.fromString/decimal-two-digits-letter", NONE, "\\06a")
  val () = fs ("Char.fromString/decimal-fourth-digit-ignored", SOME #"A", "\\0655")
  val () = eqIL ("Char.fromString/decimal-all", all,
                 fn () => List.map (fn i => code (Char.fromString ("\\" ^ dec3 i))) all)
  val () = eqIL ("Char.fromString/decimal-above-255", [],
                 fn () => List.filter (fn i => Char.fromString ("\\" ^ dec3 i) <> NONE) (fromTo (256, 999)))

  val () = fs ("Char.fromString/u-0041", SOME #"A", "\\u0041")
  val () = fs ("Char.fromString/u-0000", SOME #"\000", "\\u0000")
  val () = fs ("Char.fromString/u-00ff", SOME #"\255", "\\u00ff")
  val () = fs ("Char.fromString/u-00FF", SOME #"\255", "\\u00FF")
  val () = fs ("Char.fromString/u-007e", SOME #"~", "\\u007e")
  val () = fs ("Char.fromString/u-0100-does-not-fit", NONE, "\\u0100")
  val () = fs ("Char.fromString/u-ffff-does-not-fit", NONE, "\\uffff")
  val () = fs ("Char.fromString/u-three-digits", NONE, "\\u041")
  val () = fs ("Char.fromString/u-three-digits-letter", NONE, "\\u004g")
  val () = fs ("Char.fromString/u-incomplete", NONE, "\\u")
  val () = fs ("Char.fromString/u-fifth-digit-ignored", SOME #"A", "\\u00410")
  val () = fs ("Char.fromString/u-uppercase-U", NONE, "\\U0041")
  val () = eqIL ("Char.fromString/u-all", all,
                 fn () => List.map (fn i => code (Char.fromString ("\\u00" ^ hex2 i))) all)

  (* \f...f\ is passed over, where f...f is one or more formatting characters. *)
  val () = fs ("Char.fromString/format-space", SOME #"a", "\\ \\a")
  val () = fs ("Char.fromString/format-newline", SOME #"a", "\\\n\\a")
  val () = fs ("Char.fromString/format-tab", SOME #"a", "\\\t\\a")
  val () = fs ("Char.fromString/format-several", SOME #"a", "\\ \t\n \\a")
  val () = fs ("Char.fromString/format-form-feed", SOME #"a", "\\\012\\a")
  val () = fs ("Char.fromString/format-twice", SOME #"a", "\\ \\\\\n\\a")
  val () = fs ("Char.fromString/format-then-escape", SOME #"\010", "\\ \\\\n")
  val () = fs ("Char.fromString/format-then-decimal", SOME #"A", "\\\n  \\\\065")
  val () = fs ("Char.fromString/format-after", SOME #"a", "a\\ \\")
  val () = fs ("Char.fromString/format-unterminated", NONE, "\\ ")
  val () = fs ("Char.fromString/format-letter-inside", NONE, "\\ x \\a")
  (* The sample conversions of the page. Its third sample reads "a\\ \\\q",
     which is not an SML string; the STRING page has "a\\ \\\\q". *)
  val () = fs ("Char.fromString/sample-1", NONE, "\\q")
  val () = fs ("Char.fromString/sample-2", SOME #"a", "a\004")
  val () = fs ("Char.fromString/sample-3", SOME #"a", "a\\ \\\\q")
  val () = fs ("Char.fromString/sample-4", NONE, "\\ \\")
  val () = fs ("Char.fromString/sample-5", NONE, "")
  val () = fs ("Char.fromString/sample-6", NONE, "\\ \\\004")
  val () = fs ("Char.fromString/sample-7", NONE, "\\ a")
  val () = eqIL ("Char.fromString/toString-all", all,
                 fn () => List.map (fn i => code (Char.fromString (Char.toString (Char.chr i)))) all)

  (*<< scan *)
  (* scanL s: Char.scan on the list of the characters of s; the rest of the
     stream is shown as a string. *)
  fun scanL s =
    case Char.scan List.getItem (String.explode s) of
      SOME (c, rest) => SOME (c, String.implode rest)
    | NONE => NONE
  fun sc (label, expected, text) = T.eq (T.option (T.pair (T.char, T.string))) (label, expected, fn () => scanL text)
  val () = sc ("Char.scan/letter", SOME (#"a", "bc"), "abc")
  val () = sc ("Char.scan/last-character", SOME (#"a", ""), "a")
  val () = sc ("Char.scan/empty", NONE, "")
  val () = sc ("Char.scan/space-is-not-skipped", SOME (#" ", "a"), " a")
  val () = sc ("Char.scan/escape-n", SOME (#"\010", "xy"), "\\nxy")
  val () = sc ("Char.scan/escape-backslash", SOME (#"\\", "n"), "\\\\n")
  val () = sc ("Char.scan/control", SOME (#"\001", "B"), "\\^AB")
  val () = sc ("Char.scan/decimal", SOME (#"A", "B"), "\\065B")
  val () = sc ("Char.scan/decimal-three-digits-only", SOME (#"A", "5"), "\\0655")
  val () = sc ("Char.scan/u", SOME (#"A", "0"), "\\u00410")
  val () = sc ("Char.scan/illegal-escape", NONE, "\\qa")
  val () = sc ("Char.scan/decimal-256", NONE, "\\256")
  val () = sc ("Char.scan/not-printable", NONE, "\010a")
  val () = sc ("Char.scan/format-before", SOME (#"a", "bc"), "\\ \\abc")
  (* "Such sequences are successfully scanned, so that the remaining stream
     returned by scan will never have a valid escaped formatting sequence as
     its prefix." *)
  val () = sc ("Char.scan/trailing-format", SOME (#"a", "bc"), "a\\ \\bc")
  val () = sc ("Char.scan/trailing-format-twice", SOME (#"a", "bc"), "a\\ \\\\\n\t\\bc")
  val () = sc ("Char.scan/trailing-format-at-end", SOME (#"a", ""), "a\\ \\")
  val () = sc ("Char.scan/trailing-format-after-escape", SOME (#"\010", "b"), "\\n\\ \\b")
  val () = sc ("Char.scan/trailing-format-after-leading-format", SOME (#"a", "b"), "\\ \\a\\ \\b")
  val () = sc ("Char.scan/trailing-format-after-leading-format-and-escape", SOME (#"\010", "b"), "\\ \\\\n\\ \\b")
  val () = sc ("Char.scan/invalid-format-is-not-scanned", SOME (#"a", "\\ b"), "a\\ b")
  val () = sc ("Char.scan/format-only", NONE, "\\ \\")
  val () = sc ("Char.scan/format-then-not-printable", NONE, "\\ \\\004")
  (* any reader: here a string and an index *)
  fun getc (s, i) = if i < String.size s then SOME (String.sub (s, i), (s, i + 1)) else NONE
  val () = T.eq (T.option (T.pair (T.char, T.pair (T.string, T.int))))
             ("Char.scan/indexed-reader", SOME (#"\009", ("xa\\tb", 4)), fn () => Char.scan getc ("xa\\tb", 2))
  val () = T.eq (T.option (T.pair (T.char, T.pair (T.string, T.int))))
             ("Char.scan/indexed-reader-end", NONE, fn () => Char.scan getc ("xa", 2))
  (* fromString is StringCvt.scanString scan *)
  val () = T.eq (T.list (T.option T.char))
             ("Char.scan/scanString",
              [SOME #"a", NONE, SOME #"\010", NONE, SOME #"A", SOME #"a", NONE, NONE, SOME #" "],
              fn () => List.map (StringCvt.scanString Char.scan)
                         ["abc", "", "\\n", "\\q", "\\065", "\\ \\a", "\\ \\", "\010", " a"])
  (*>> scan *)

  (*<< cstring *)
  (* ---- toCString ---- *)
  val () = eqS ("Char.toCString/letter", "a", fn () => Char.toCString #"a")
  val () = eqS ("Char.toCString/space", " ", fn () => Char.toCString #" ")
  val () = eqS ("Char.toCString/backslash", "\\\\", fn () => Char.toCString #"\\")
  val () = eqS ("Char.toCString/double-quote", "\\\"", fn () => Char.toCString #"\"")
  val () = eqS ("Char.toCString/question-mark", "\\?", fn () => Char.toCString #"?")
  val () = eqS ("Char.toCString/single-quote", "\\'", fn () => Char.toCString #"'")
  val () = eqS ("Char.toCString/alert", "\\a", fn () => Char.toCString #"\007")
  val () = eqS ("Char.toCString/backspace", "\\b", fn () => Char.toCString #"\008")
  val () = eqS ("Char.toCString/tab", "\\t", fn () => Char.toCString #"\009")
  val () = eqS ("Char.toCString/newline", "\\n", fn () => Char.toCString #"\010")
  val () = eqS ("Char.toCString/vertical-tab", "\\v", fn () => Char.toCString #"\011")
  val () = eqS ("Char.toCString/form-feed", "\\f", fn () => Char.toCString #"\012")
  val () = eqS ("Char.toCString/carriage-return", "\\r", fn () => Char.toCString #"\013")
  val () = eqS ("Char.toCString/nul", "\\000", fn () => Char.toCString #"\000")
  val () = eqS ("Char.toCString/1", "\\001", fn () => Char.toCString #"\001")
  val () = eqS ("Char.toCString/escape", "\\033", fn () => Char.toCString #"\027")
  val () = eqS ("Char.toCString/31", "\\037", fn () => Char.toCString #"\031")
  val () = eqS ("Char.toCString/del", "\\177", fn () => Char.toCString #"\127")
  val () = eqS ("Char.toCString/128", "\\200", fn () => Char.toCString #"\128")
  val () = eqS ("Char.toCString/255", "\\377", fn () => Char.toCString #"\255")
  val () = eqSL ("Char.toCString/nul-and-all-below-32",
                 ["\\000", "\\001", "\\002", "\\003", "\\004", "\\005", "\\006", "\\a",
                  "\\b", "\\t", "\\n", "\\v", "\\f", "\\r", "\\016", "\\017",
                  "\\020", "\\021", "\\022", "\\023", "\\024", "\\025", "\\026", "\\027",
                  "\\030", "\\031", "\\032", "\\033", "\\034", "\\035", "\\036", "\\037"],
                 fn () => List.map (Char.toCString o Char.chr) (fromTo (0, 31)))
  val () = eqS ("Char.toCString/all-printable",
                " !\\\"#$%&\\'()*+,-./0123456789:;<=>\\?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~",
                fn () => String.concat (List.map (Char.toCString o Char.chr) (fromTo (32, 126))))
  val () = eqSL ("Char.toCString/all-above-126", List.map (fn i => "\\" ^ oct3 i) (fromTo (127, 255)),
                 fn () => List.map (Char.toCString o Char.chr) (fromTo (127, 255)))

  (* ---- fromCString ---- *)
  fun fc (label, expected, text) = eqCO (label, expected, fn () => Char.fromCString text)
  val () = fc ("Char.fromCString/letter", SOME #"a", "a")
  val () = fc ("Char.fromCString/rest-ignored", SOME #"a", "abc")
  val () = fc ("Char.fromCString/space", SOME #" ", " x")
  val () = fc ("Char.fromCString/empty", NONE, "")
  val () = fc ("Char.fromCString/unescaped-single-quote", SOME #"'", "'")
  val () = fc ("Char.fromCString/unescaped-double-quote", NONE, "\"")
  val () = fc ("Char.fromCString/unescaped-question-mark", SOME #"?", "?")
  val () = fc ("Char.fromCString/printable-only-newline", NONE, "\n")
  val () = fc ("Char.fromCString/printable-only-del", NONE, "\127")
  val () = fc ("Char.fromCString/printable-only-128", NONE, "\128")
  (* "fromCString accepts an unescaped single quote character, but does not
     accept an unescaped double quote character": every printable character
     but the double quote and the backslash converts to itself. *)
  val () = eqIL ("Char.fromCString/printable-only-all-converted",
                 fromTo (32, 33) @ fromTo (35, 91) @ fromTo (93, 126),
                 fn () => List.filter (fn i => i <> 34 andalso Char.fromCString (String.str (Char.chr i)) = SOME (Char.chr i)) all)
  val () = eqIL ("Char.fromCString/printable-only-all-rejected",
                 fromTo (0, 31) @ [92] @ fromTo (127, 255),
                 fn () => List.filter (fn i => i <> 34 andalso Char.fromCString (String.str (Char.chr i)) = NONE) all)
  val () = fc ("Char.fromCString/escape-a", SOME #"\007", "\\a")
  val () = fc ("Char.fromCString/escape-b", SOME #"\008", "\\b")
  val () = fc ("Char.fromCString/escape-t", SOME #"\009", "\\t")
  val () = fc ("Char.fromCString/escape-n", SOME #"\010", "\\n")
  val () = fc ("Char.fromCString/escape-v", SOME #"\011", "\\v")
  val () = fc ("Char.fromCString/escape-f", SOME #"\012", "\\f")
  val () = fc ("Char.fromCString/escape-r", SOME #"\013", "\\r")
  val () = fc ("Char.fromCString/escape-question-mark", SOME #"?", "\\?")
  val () = fc ("Char.fromCString/escape-backslash", SOME #"\\", "\\\\")
  val () = fc ("Char.fromCString/escape-double-quote", SOME #"\"", "\\\"")
  val () = fc ("Char.fromCString/escape-single-quote", SOME #"'", "\\'")
  val () = fc ("Char.fromCString/escape-rest-ignored", SOME #"\010", "\\nabc")
  (* The second characters that make a complete escape sequence:
     " ' 0-7 ? \ a b f n r t v *)
  val () = eqIL ("Char.fromCString/two-character-escapes",
                 [34, 39, 48, 49, 50, 51, 52, 53, 54, 55, 63, 92, 97, 98, 102, 110, 114, 116, 118],
                 fn () => List.filter (fn i => Char.fromCString ("\\" ^ String.str (Char.chr i)) <> NONE) all)
  val () = fc ("Char.fromCString/illegal-q", NONE, "\\q")
  val () = fc ("Char.fromCString/illegal-lone-backslash", NONE, "\\")
  val () = fc ("Char.fromCString/illegal-u", NONE, "\\u0041")
  val () = fc ("Char.fromCString/illegal-format", NONE, "\\ \\a")

  val () = fc ("Char.fromCString/control-H-is-backspace", SOME #"\008", "\\^H")
  val () = fc ("Char.fromCString/control-at", SOME #"\000", "\\^@")
  val () = fc ("Char.fromCString/control-underscore", SOME #"\031", "\\^_")
  val () = fc ("Char.fromCString/control-range-96", NONE, "\\^`")
  val () = fc ("Char.fromCString/control-incomplete", NONE, "\\^")
  val () = eqIL ("Char.fromCString/control-all", fromTo (0, 31),
                 fn () => List.map (fn i => code (Char.fromCString ("\\^" ^ String.str (Char.chr i)))) (fromTo (64, 95)))

  val () = fc ("Char.fromCString/octal-101", SOME #"A", "\\101")
  val () = fc ("Char.fromCString/octal-one-digit", SOME #"\007", "\\7")
  val () = fc ("Char.fromCString/octal-zero", SOME #"\000", "\\0")
  val () = fc ("Char.fromCString/octal-two-digits", SOME #"\010", "\\12")
  val () = fc ("Char.fromCString/octal-012", SOME #"\010", "\\012")
  val () = fc ("Char.fromCString/octal-377", SOME #"\255", "\\377")
  val () = fc ("Char.fromCString/octal-400-does-not-fit", NONE, "\\400")
  val () = fc ("Char.fromCString/octal-777-does-not-fit", NONE, "\\777")
  val () = fc ("Char.fromCString/octal-8-is-no-digit", NONE, "\\8")
  val () = fc ("Char.fromCString/octal-stops-at-8", SOME #"\001", "\\18")
  val () = fc ("Char.fromCString/octal-stops-at-9", SOME #"A", "\\1019")
  val () = fc ("Char.fromCString/octal-stops-at-letter", SOME #"\008", "\\10a")
  val () = eqIL ("Char.fromCString/octal-all", all,
                 fn () => List.map (fn i => code (Char.fromCString ("\\" ^ oct3 i))) all)

  val () = fc ("Char.fromCString/hex-41", SOME #"A", "\\x41")
  val () = fc ("Char.fromCString/hex-4a", SOME #"J", "\\x4a")
  val () = fc ("Char.fromCString/hex-4A", SOME #"J", "\\x4A")
  val () = fc ("Char.fromCString/hex-ff", SOME #"\255", "\\xff")
  val () = fc ("Char.fromCString/hex-FF", SOME #"\255", "\\xFF")
  val () = fc ("Char.fromCString/hex-one-digit", SOME #"\007", "\\x7")
  val () = fc ("Char.fromCString/hex-0", SOME #"\000", "\\x0")
  val () = fc ("Char.fromCString/hex-longest-sequence", SOME #"A", "\\x0041")
  val () = fc ("Char.fromCString/hex-longest-sequence-does-not-fit", NONE, "\\x410")
  val () = fc ("Char.fromCString/hex-100-does-not-fit", NONE, "\\x100")
  val () = fc ("Char.fromCString/hex-leading-zeros", SOME #"A", "\\x000000000000000000000000000000041")
  val () = fc ("Char.fromCString/hex-fffff-does-not-fit", NONE, "\\xfffff")
  (* a value that does not fit in an int either: still NONE, not Overflow *)
  val () = fc ("Char.fromCString/hex-huge-does-not-fit", NONE, "\\xfffffffffffffffffffffffffffffffff")
  val () = fc ("Char.fromCString/hex-no-digit", NONE, "\\x")
  val () = fc ("Char.fromCString/hex-no-digit-g", NONE, "\\xg")
  val () = fc ("Char.fromCString/hex-stops-at-g", SOME #"A", "\\x41g")
  val () = fc ("Char.fromCString/hex-uppercase-X", NONE, "\\X41")
  val () = eqIL ("Char.fromCString/hex-all", all,
                 fn () => List.map (fn i => code (Char.fromCString ("\\x" ^ hex2 i))) all)
  val () = eqIL ("Char.fromCString/toCString-all", all,
                 fn () => List.map (fn i => code (Char.fromCString (Char.toCString (Char.chr i)))) all)
  (*>> cstring *)

  (* ---- laws, on pseudo-random strings and characters ---- *)
  fun randomString () = String.implode (List.tabulate (T.range (0, 12), fn _ => Char.chr (T.range (0, 255))))
  val () = T.seed 5
  val () = T.repeat (40, fn k =>
    let
      val n = Int.toString k
      val s = randomString ()
      val i = T.range (0, 255)
      val j = T.range (0, 255)
      fun occurs m = List.exists (fn c => Char.ord c = m) (String.explode s)
    in
      eqIL ("Char.contains/law-" ^ n, List.filter occurs all, fn () => codesIn (0, 255) (Char.contains s));
      eqIL ("Char.notContains/law-" ^ n, List.filter (not o occurs) all, fn () => codesIn (0, 255) (Char.notContains s));
      eqOrd ("Char.compare/law-" ^ n, Int.compare (i, j), fn () => Char.compare (Char.chr i, Char.chr j));
      eqOrd ("Char.compare/antisymmetric-" ^ n, Int.compare (j, i), fn () => Char.compare (Char.chr j, Char.chr i));
      eqB ("Char.isPunct/law-" ^ n, Char.isGraph (Char.chr i) andalso not (Char.isAlphaNum (Char.chr i)),
           fn () => Char.isPunct (Char.chr i));
      eqC ("Char.toUpper/toLower-" ^ n, Char.toUpper (Char.chr i), fn () => Char.toUpper (Char.toLower (Char.toUpper (Char.chr i))))
    end)
end

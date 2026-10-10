(* libraries: random *)
(* Utf8 and DisplayWidth: every scalar value written and read back; the
   ill-formed sequences of the Unicode Standard's examples (section 3.9,
   "U+FFFD Substitution of Maximal Subparts") and Markus Kuhn's decoder
   test, each read as the replacements the standard recommends; random
   bytes read without failing; and the widths of known characters. *)
structure Utf8Test =
struct
  val failures = ref 0
  fun check (name, ok) =
    if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  fun bytes l = String.implode (map Char.chr l)

  (* every scalar value, encoded and decoded *)
  fun roundTrip () =
    let
      fun go c =
        if c > 0x10FFFF then true
        else if c = 0xD800 then go 0xE000
        else
          let val s = Utf8.encode c
          in Utf8.decode (s, 0) = SOME (c, size s) andalso Utf8.isValid s andalso go (c + 1) end
    in
      check ("every scalar value round-trips", go 0)
    end

  (* bytes, and the code points a reader that never fails gives for them *)
  val replaced = [
    ("the standard's example, Table 3-8",
     [0x61, 0xF1, 0x80, 0x80, 0xE1, 0x80, 0xC2, 0x62, 0x80, 0x63, 0x80, 0xBF, 0x64],
     [0x61, 0xFFFD, 0xFFFD, 0xFFFD, 0x62, 0xFFFD, 0x63, 0xFFFD, 0xFFFD, 0x64]),
    ("an overlong slash", [0xC0, 0xAF], [0xFFFD, 0xFFFD]),
    ("an overlong NUL in three bytes", [0xE0, 0x80, 0x80], [0xFFFD, 0xFFFD, 0xFFFD]),
    ("an overlong NUL in four bytes", [0xF0, 0x80, 0x80, 0x80], [0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD]),
    ("a high surrogate", [0xED, 0xA0, 0x80], [0xFFFD, 0xFFFD, 0xFFFD]),
    ("past 0x10FFFF", [0xF4, 0x90, 0x80, 0x80], [0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD]),
    ("a lead that cannot lead", [0xF5, 0x80], [0xFFFD, 0xFFFD]),
    ("a sequence cut short, then ASCII", [0xE2, 0x82, 0x41], [0xFFFD, 0x41]),
    ("cut short at the end", [0xF0, 0x9F, 0x98], [0xFFFD]),
    ("a continuation alone", [0x80], [0xFFFD]),
    ("FE and FF", [0xFE, 0xFF], [0xFFFD, 0xFFFD]),
    ("the last scalars", [0xF4, 0x8F, 0xBF, 0xBF, 0xEF, 0xBF, 0xBF], [0x10FFFF, 0xFFFF])]

  fun replacements () =
    List.app (fn (name, b, cps) =>
                check ("replacement: " ^ name, Utf8.explode (bytes b) = cps)) replaced

  (* random bytes: never an exception; isValid exactly when nothing is
     replaced that was not there, and when implode undoes explode *)
  fun randomBytes () =
    let
      fun draw (0, g, acc) = (String.implode acc, g)
        | draw (n, g, acc) =
            let val (b, g) = Random.int (0, 255) g in draw (n - 1, g, Char.chr b :: acc) end
      fun go (0, _) = true
        | go (k, g) =
            let
              val (n, g) = Random.int (0, 12) g
              val (s, g) = draw (n, g, [])
              val cps = Utf8.explode s
              val ok = Utf8.isValid s = (Utf8.implode cps = s)
                       andalso Utf8.size s = length cps
                       andalso (Utf8.isValid s orelse List.exists (fn c => c = Utf8.replacement) cps)
            in
              ok andalso go (k - 1, g)
            end
    in
      check ("random bytes", go (20000, Random.fromSeed 0w17))
    end

  fun widths () =
    let
      val cases = [(0x41, 1), (0x6F22, 2), (0x301, 0), (0x1F600, 2), (0x200D, 0),
                   (0xAD, 1), (0x1B, 0), (0x9F, 0), (0x1160, 0), (0xFF21, 2),
                   (0x3000, 2), (0xA0, 1), (0xFE0F, 0), (0x1F1E6, 2), (0xE9, 1)]
    in
      List.app (fn (c, w) =>
                  check ("width of U+" ^ Int.fmt StringCvt.HEX c,
                         DisplayWidth.codePoint c = w)) cases;
      check ("columns", DisplayWidth.columns "caf\195\169 \230\188\162\229\173\151" = 9);
      check ("isControl", DisplayWidth.isControl 0x7F andalso not (DisplayWidth.isControl 0xA0))
    end

  fun clusterWidths () =
    let
      val family = "\240\159\145\169\226\128\141\240\159\145\169\226\128\141\240\159\145\167"
      val flag = "\240\159\135\179\240\159\135\177"
      val keycap = "1\239\184\143\226\131\163"
      val heart = "\226\157\164\239\184\143"
    in
      check ("a family is one cluster", Grapheme.count family = 1);
      check ("a family, by cluster", Grapheme.width Grapheme.ByCluster family = 2);
      check ("a family, by code point", Grapheme.width Grapheme.ByCodePoint family = 6);
      check ("a flag", Grapheme.count flag = 1 andalso Grapheme.width Grapheme.ByCluster flag = 2);
      check ("a keycap", Grapheme.count keycap = 1 andalso Grapheme.width Grapheme.ByCluster keycap = 2);
      check ("a heart with VS16", Grapheme.width Grapheme.ByCluster heart = 2);
      check ("e and an accent", Grapheme.clusters "e\204\129" = ["e\204\129"]);
      check ("CR LF", Grapheme.clusters "\r\na" = ["\r\n", "a"]);
      check ("an ill-formed byte is a cluster", Grapheme.clusters "a\255b" = ["a", "\255", "b"])
    end

  fun main () =
    (roundTrip (); replacements (); randomBytes (); widths (); clusterWidths ();
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " utf8, widths: "
            ^ Int.toString (!failures) ^ " failed\n"))
end

val () = Utf8Test.main ()

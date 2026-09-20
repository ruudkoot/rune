(* requires: StringCvt *)
(* The StringCvt structure (signature STRING_CVT). Expected values follow the
   text of https://smlfamily.github.io/Basis/string-cvt.html.

   The readers are written by hand, over a list of characters (listRd) and
   over a string with the index of the next character (strRd), so that what
   splitl, takel, dropl and skipWS are checked against does not come from the
   library. The type cs is abstract; it occurs only in the types of the
   scanning functions given to scanString.

   Size (padLeft, padRight) needs a string of more than String.maxSize
   characters. It is checked only where String.maxSize + 1 exists and an
   implementation that forgets the check would merely build such a string
   (String.maxSize at most 2^26); elsewhere the attempt could exhaust the
   memory of the machine. *)
structure TestStringCvt =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqCL = T.eq (T.list T.char)
  val eqIL = T.eq (T.list T.int)
  val eqSO = T.eq (T.option T.string)
  val eqIO = T.eq (T.option T.int)
  val eqSCL = T.eq (T.pair (T.string, T.list T.char))
  val eqSP = T.eq (T.pair (T.string, T.pair (T.string, T.int)))
  val eqP = T.eq (T.pair (T.string, T.int))

  (* ---- readers ---- *)
  fun listRd ([] : char list) = NONE
    | listRd (c :: cs) = SOME (c, cs)
  fun strRd (s, i) = if i < String.size s then SOME (String.sub (s, i), (s, i + 1)) else NONE

  (* traced rdr: rdr, and the indices it has been asked for so far, in order. *)
  fun traced () : (string * int -> (char * (string * int)) option) * (unit -> int list) =
    let val log = ref []
    in (fn (s, i) => (log := i :: !log; strRd (s, i)), fn () => List.rev (!log)) end

  (* trace f: f, and the characters it has been applied to so far, in order. *)
  fun trace (f : char -> 'a) : (char -> 'a) * (unit -> char list) =
    let val log = ref []
    in (fn c => (log := c :: !log; f c), fn () => List.rev (!log)) end

  (* a scanning function that reads every character of the source *)
  fun whole rdr src =
    let fun go (src, acc) = case rdr src of
                              NONE => SOME (String.implode (List.rev acc), src)
                            | SOME (c, src') => go (src', c :: acc)
    in go (src, []) end

  (* the smallest and the largest int, or a small and a large one *)
  val big = case Int.maxInt of SOME m => m | NONE => 1073741823
  val small = case Int.minInt of SOME m => m | NONE => ~1073741824

  (* ---- radix: "the bases 2, 8, 10, and 16, respectively" ---- *)
  fun baseOf StringCvt.BIN = 2
    | baseOf StringCvt.OCT = 8
    | baseOf StringCvt.DEC = 10
    | baseOf StringCvt.HEX = 16
  val () = eqI ("StringCvt.BIN/pattern", 2, fn () => baseOf StringCvt.BIN)
  val () = eqI ("StringCvt.OCT/pattern", 8, fn () => baseOf StringCvt.OCT)
  val () = eqI ("StringCvt.DEC/pattern", 10, fn () => baseOf StringCvt.DEC)
  val () = eqI ("StringCvt.HEX/pattern", 16, fn () => baseOf StringCvt.HEX)
  val () = eqB ("StringCvt.radix/equal-to-itself", true,
                fn () => List.all (fn r => r = r) [StringCvt.BIN, StringCvt.OCT, StringCvt.DEC, StringCvt.HEX])
  val () = eqI ("StringCvt.radix/four-distinct-values", 12,
                fn () =>
                  let val all = [StringCvt.BIN, StringCvt.OCT, StringCvt.DEC, StringCvt.HEX]
                  in List.length (List.concat (List.map (fn r => List.filter (fn r' => r <> r') all) all)) end)
  (*<< Int.fmt *)
  val () = eqS ("StringCvt.BIN/Int.fmt", "1011", fn () => Int.fmt StringCvt.BIN 11)
  val () = eqS ("StringCvt.OCT/Int.fmt", "13", fn () => Int.fmt StringCvt.OCT 11)
  val () = eqS ("StringCvt.DEC/Int.fmt", "11", fn () => Int.fmt StringCvt.DEC 11)
  val () = eqS ("StringCvt.HEX/Int.fmt", "B", fn () => Int.fmt StringCvt.HEX 11)
  (*>> Int.fmt *)
  (*<< Int.scan *)
  val () = eqIO ("StringCvt.BIN/Int.scan", SOME 5, fn () => StringCvt.scanString (Int.scan StringCvt.BIN) "101")
  val () = eqIO ("StringCvt.OCT/Int.scan", SOME 65, fn () => StringCvt.scanString (Int.scan StringCvt.OCT) "101")
  val () = eqIO ("StringCvt.DEC/Int.scan", SOME 101, fn () => StringCvt.scanString (Int.scan StringCvt.DEC) "101")
  val () = eqIO ("StringCvt.HEX/Int.scan", SOME 257, fn () => StringCvt.scanString (Int.scan StringCvt.HEX) "101")
  (*>> Int.scan *)

  (* ---- realfmt ---- *)
  fun describe (StringCvt.SCI p) = ("SCI", p)
    | describe (StringCvt.FIX p) = ("FIX", p)
    | describe (StringCvt.GEN p) = ("GEN", p)
    | describe StringCvt.EXACT = ("EXACT", NONE)
  val eqD = T.eq (T.pair (T.string, T.option T.int))
  val () = eqD ("StringCvt.SCI/pattern", ("SCI", SOME 3), fn () => describe (StringCvt.SCI (SOME 3)))
  val () = eqD ("StringCvt.SCI/pattern-NONE", ("SCI", NONE), fn () => describe (StringCvt.SCI NONE))
  val () = eqD ("StringCvt.FIX/pattern", ("FIX", SOME 0), fn () => describe (StringCvt.FIX (SOME 0)))
  val () = eqD ("StringCvt.FIX/pattern-NONE", ("FIX", NONE), fn () => describe (StringCvt.FIX NONE))
  val () = eqD ("StringCvt.GEN/pattern", ("GEN", SOME 12), fn () => describe (StringCvt.GEN (SOME 12)))
  val () = eqD ("StringCvt.GEN/pattern-NONE", ("GEN", NONE), fn () => describe (StringCvt.GEN NONE))
  val () = eqD ("StringCvt.EXACT/pattern", ("EXACT", NONE), fn () => describe StringCvt.EXACT)
  (* the constructors carry any int option, also one no format accepts *)
  val () = eqD ("StringCvt.SCI/carries-negative", ("SCI", SOME ~1), fn () => describe (StringCvt.SCI (SOME ~1)))
  val () = eqB ("StringCvt.realfmt/equality", true,
                fn () => StringCvt.SCI (SOME 2) = StringCvt.SCI (SOME 2) andalso StringCvt.EXACT = StringCvt.EXACT
                         andalso StringCvt.GEN NONE = StringCvt.GEN NONE)
  val () = eqB ("StringCvt.realfmt/constructors-differ", true,
                fn () => StringCvt.SCI (SOME 2) <> StringCvt.FIX (SOME 2) andalso StringCvt.FIX (SOME 2) <> StringCvt.GEN (SOME 2)
                         andalso StringCvt.SCI NONE <> StringCvt.GEN NONE andalso StringCvt.GEN NONE <> StringCvt.EXACT)
  (* the default is a different value from the precision it stands for *)
  val () = eqB ("StringCvt.realfmt/arguments-differ", true,
                fn () => StringCvt.SCI NONE <> StringCvt.SCI (SOME 6) andalso StringCvt.FIX (SOME 1) <> StringCvt.FIX (SOME 2)
                         andalso StringCvt.GEN NONE <> StringCvt.GEN (SOME 12))
  (* tests/basis/real_fmt.sml checks the formats in full, EXACT among them;
     here each constructor is given to Real.fmt once or twice. *)
  (*<< Real.fmt *)
  (* SCI: "always one digit before the decimal point ... The optional integer
     value specifies the number of decimal digits to appear after the decimal
     point, with 6 being the default. In particular, if 0 is specified, there
     should be no fractional part. The exponent is zero if the value is zero." *)
  val () = eqS ("StringCvt.SCI/Real.fmt-default-6", "1.500000E0", fn () => Real.fmt (StringCvt.SCI NONE) 1.5)
  val () = eqS ("StringCvt.SCI/Real.fmt-2", "1.25E2", fn () => Real.fmt (StringCvt.SCI (SOME 2)) 125.0)
  val () = eqS ("StringCvt.SCI/Real.fmt-0", "5E0", fn () => Real.fmt (StringCvt.SCI (SOME 0)) 5.0)
  val () = eqS ("StringCvt.SCI/Real.fmt-zero", "0.0E0", fn () => Real.fmt (StringCvt.SCI (SOME 1)) 0.0)
  (* FIX: "at least one digit before the decimal point", the same precision rules *)
  val () = eqS ("StringCvt.FIX/Real.fmt-default-6", "1.500000", fn () => Real.fmt (StringCvt.FIX NONE) 1.5)
  val () = eqS ("StringCvt.FIX/Real.fmt-2", "0.25", fn () => Real.fmt (StringCvt.FIX (SOME 2)) 0.25)
  val () = eqS ("StringCvt.FIX/Real.fmt-0", "2", fn () => Real.fmt (StringCvt.FIX (SOME 0)) 2.0)
  (* GEN: "There should not be any trailing zeros after the decimal point."
     The optional value is "the maximum number of significant digits". *)
  val () = eqS ("StringCvt.GEN/Real.fmt-default", "1.5", fn () => Real.fmt (StringCvt.GEN NONE) 1.5)
  val () = eqS ("StringCvt.GEN/Real.fmt-3", "0.333", fn () => Real.fmt (StringCvt.GEN (SOME 3)) (1.0 / 3.0))
  (* "In all cases, positive and negative infinities are converted to "inf" and
     "~inf", respectively, and NaN values are converted to the string "nan"." *)
  val () = List.app (fn (name, f) =>
    (eqS ("StringCvt." ^ name ^ "/Real.fmt-inf", "inf", fn () => Real.fmt f Real.posInf);
     eqS ("StringCvt." ^ name ^ "/Real.fmt-neg-inf", "~inf", fn () => Real.fmt f Real.negInf);
     eqS ("StringCvt." ^ name ^ "/Real.fmt-nan", "nan", fn () => Real.fmt f (Real.posInf - Real.posInf))))
    [("SCI", StringCvt.SCI NONE), ("FIX", StringCvt.FIX (SOME 2)), ("GEN", StringCvt.GEN NONE)]
  (*>> Real.fmt *)

  (* ---- reader: "type ('a,'b) reader = 'b -> ('a * 'b) option" ---- *)
  val () = T.check ("StringCvt.reader/is-the-function-type",
                    fn () =>
                      let
                        val r : (char, char list) StringCvt.reader = listRd
                        val r' : (int, int) StringCvt.reader = fn n => if n > 0 then SOME (n, n - 1) else NONE
                        val f : int -> (int * int) option = r'
                      in
                        r [#"x", #"y"] = SOME (#"x", [#"y"]) andalso r [] = NONE andalso f 3 = SOME (3, 2) andalso r' 0 = NONE
                      end)

  (* ---- padLeft, padRight ----
     "These return s padded, on the left or right, respectively, with i - |s|
     copies of the character c. If |s| >= i, they just return the string s." *)
  val () = eqS ("StringCvt.padLeft/basic", "   ab", fn () => StringCvt.padLeft #" " 5 "ab")
  val () = eqS ("StringCvt.padRight/basic", "ab   ", fn () => StringCvt.padRight #" " 5 "ab")
  val () = eqS ("StringCvt.padLeft/other-character", "00042", fn () => StringCvt.padLeft #"0" 5 "42")
  val () = eqS ("StringCvt.padRight/other-character", "42***", fn () => StringCvt.padRight #"*" 5 "42")
  val () = eqS ("StringCvt.padLeft/one-short", "-abc", fn () => StringCvt.padLeft #"-" 4 "abc")
  val () = eqS ("StringCvt.padRight/one-short", "abc-", fn () => StringCvt.padRight #"-" 4 "abc")
  val () = eqS ("StringCvt.padLeft/empty-string", "xxx", fn () => StringCvt.padLeft #"x" 3 "")
  val () = eqS ("StringCvt.padRight/empty-string", "xxx", fn () => StringCvt.padRight #"x" 3 "")
  val () = eqS ("StringCvt.padLeft/nul-character", "\000\000a", fn () => StringCvt.padLeft #"\000" 3 "a")
  val () = eqS ("StringCvt.padRight/character-255", "a\255\255", fn () => StringCvt.padRight #"\255" 3 "a")
  val () = eqS ("StringCvt.padLeft/width-equals-size", "abc", fn () => StringCvt.padLeft #" " 3 "abc")
  val () = eqS ("StringCvt.padRight/width-equals-size", "abc", fn () => StringCvt.padRight #" " 3 "abc")
  (* "never trimming off any part of s" *)
  val () = eqS ("StringCvt.padLeft/width-below-size", "abc", fn () => StringCvt.padLeft #" " 2 "abc")
  val () = eqS ("StringCvt.padRight/width-below-size", "abc", fn () => StringCvt.padRight #" " 2 "abc")
  val () = eqS ("StringCvt.padLeft/width-one", "abc", fn () => StringCvt.padLeft #" " 1 "abc")
  val () = eqS ("StringCvt.padRight/width-one", "abc", fn () => StringCvt.padRight #" " 1 "abc")
  (* "Note that if i <= 0, s is returned." *)
  val () = eqS ("StringCvt.padLeft/width-zero", "abc", fn () => StringCvt.padLeft #" " 0 "abc")
  val () = eqS ("StringCvt.padRight/width-zero", "abc", fn () => StringCvt.padRight #" " 0 "abc")
  val () = eqS ("StringCvt.padLeft/width-zero-empty-string", "", fn () => StringCvt.padLeft #" " 0 "")
  val () = eqS ("StringCvt.padRight/width-zero-empty-string", "", fn () => StringCvt.padRight #" " 0 "")
  val () = eqS ("StringCvt.padLeft/width-negative", "abc", fn () => StringCvt.padLeft #" " ~1 "abc")
  val () = eqS ("StringCvt.padRight/width-negative", "abc", fn () => StringCvt.padRight #" " ~1 "abc")
  val () = eqS ("StringCvt.padLeft/width-negative-empty-string", "", fn () => StringCvt.padLeft #" " ~5 "")
  val () = eqS ("StringCvt.padRight/width-negative-empty-string", "", fn () => StringCvt.padRight #" " ~5 "")
  (* i - |s| does not exist for the smallest int; s is returned all the same *)
  val () = eqS ("StringCvt.padLeft/width-minInt", "abc", fn () => StringCvt.padLeft #" " small "abc")
  val () = eqS ("StringCvt.padRight/width-minInt", "abc", fn () => StringCvt.padRight #" " small "abc")
  (* the functions are curried: a partial application pads many strings *)
  val () = T.eq (T.list T.string) ("StringCvt.padLeft/partial-application", ["  1", " 22", "333", "4444"],
                                   fn () => List.map (StringCvt.padLeft #" " 3) ["1", "22", "333", "4444"])
  val () = T.eq (T.list T.string) ("StringCvt.padRight/partial-application", ["1  ", "22 ", "333", "4444"],
                                   fn () => List.map (StringCvt.padRight #" " 3) ["1", "22", "333", "4444"])
  val () = eqI ("StringCvt.padLeft/long", 100000, fn () => String.size (StringCvt.padLeft #"." 100000 "x"))
  val () = eqI ("StringCvt.padRight/long", 100000, fn () => String.size (StringCvt.padRight #"." 100000 "x"))
  (* "These functions raise Size if the size of the resulting string would be
     greater than String.maxSize." (see the header) *)
  val () =
    if String.maxSize <= 67108864 andalso String.maxSize < big then
      (T.raises ("StringCvt.padLeft/Size", T.isSize, fn () => StringCvt.padLeft #" " (String.maxSize + 1) "ab");
       T.raises ("StringCvt.padRight/Size", T.isSize, fn () => StringCvt.padRight #" " (String.maxSize + 1) "ab");
       T.raises ("StringCvt.padLeft/Size-empty-string", T.isSize, fn () => StringCvt.padLeft #" " (String.maxSize + 1) "");
       T.raises ("StringCvt.padRight/Size-empty-string", T.isSize, fn () => StringCvt.padRight #" " (String.maxSize + 1) ""))
    else ()

  (* ---- splitl ----
     "returns (pref, src') where pref is the longest prefix (left substring) of
     src, as produced by the character reader rdr, all of whose characters
     satisfy f, and src' is the remainder of src. Thus, the first character
     retrievable from src' is the leftmost character not satisfying f." *)
  val () = eqSCL ("StringCvt.splitl/list-basic", ("123", [#"a", #"b", #"4"]),
                  fn () => StringCvt.splitl Char.isDigit listRd (String.explode "123ab4"))
  val () = eqSCL ("StringCvt.splitl/list-none-satisfy", ("", [#"a", #"1"]),
                  fn () => StringCvt.splitl Char.isDigit listRd [#"a", #"1"])
  val () = eqSCL ("StringCvt.splitl/list-all-satisfy", ("123", []),
                  fn () => StringCvt.splitl Char.isDigit listRd (String.explode "123"))
  val () = eqSCL ("StringCvt.splitl/list-empty-source", ("", []), fn () => StringCvt.splitl Char.isDigit listRd [])
  val () = eqSCL ("StringCvt.splitl/list-one-satisfies", ("7", []), fn () => StringCvt.splitl Char.isDigit listRd [#"7"])
  val () = eqSCL ("StringCvt.splitl/list-one-fails", ("", [#"x"]), fn () => StringCvt.splitl Char.isDigit listRd [#"x"])
  val () = eqSCL ("StringCvt.splitl/always-true", ("a1 ", []), fn () => StringCvt.splitl (fn _ => true) listRd (String.explode "a1 "))
  val () = eqSCL ("StringCvt.splitl/always-false", ("", [#"a", #"1"]), fn () => StringCvt.splitl (fn _ => false) listRd [#"a", #"1"])
  val () = eqSP ("StringCvt.splitl/string-basic", ("123", ("123ab4", 3)),
                 fn () => StringCvt.splitl Char.isDigit strRd ("123ab4", 0))
  val () = eqSP ("StringCvt.splitl/string-from-the-middle", ("ab", ("123ab4", 5)),
                 fn () => StringCvt.splitl Char.isAlpha strRd ("123ab4", 3))
  val () = eqSP ("StringCvt.splitl/string-to-the-end", ("4", ("123ab4", 6)),
                 fn () => StringCvt.splitl Char.isDigit strRd ("123ab4", 5))
  val () = eqSP ("StringCvt.splitl/string-at-the-end", ("", ("123ab4", 6)),
                 fn () => StringCvt.splitl Char.isDigit strRd ("123ab4", 6))
  val () = eqSP ("StringCvt.splitl/string-empty", ("", ("", 0)), fn () => StringCvt.splitl Char.isDigit strRd ("", 0))
  val () = eqSP ("StringCvt.splitl/all-256-characters", (String.implode (List.tabulate (128, Char.chr)), ("", 128)),
                 fn () =>
                   let val (pref, (_, i)) = StringCvt.splitl (fn c => Char.ord c < 128) strRd (String.implode (List.tabulate (256, Char.chr)), 0)
                   in (pref, ("", i)) end)
  val () = T.eq (T.option (T.pair (T.char, T.pair (T.string, T.int))))
             ("StringCvt.splitl/first-of-remainder-is-leftmost-failing", SOME (#"a", ("12ab3", 3)),
              fn () => strRd (#2 (StringCvt.splitl Char.isDigit strRd ("12ab3", 0))))
  (* the reader is any function of the type: here the source is a number whose
     decimal digits are read from the right *)
  val () = T.eq (T.pair (T.string, T.int)) ("StringCvt.splitl/other-source", ("00", 12),
             fn () => StringCvt.splitl (fn c => c = #"0")
                        (fn n => if n = 0 then NONE else SOME (Char.chr (48 + n mod 10), n div 10)) 1200)
  (* the predicate sees the characters from the left, up to the first that fails *)
  val () = eqCL ("StringCvt.splitl/predicate-order", [#"1", #"2", #"a"],
                 fn () => let val (f, seen) = trace Char.isDigit
                          in ignore (StringCvt.splitl f listRd (String.explode "12ab3")); seen () end)
  (* "Scanning functions using the reader type, such as skipWS, splitl, and
     Int.scan, will often use lookahead characters to determine when to stop
     scanning": the character that stops the scan is read, nothing after it. *)
  val () = T.check ("StringCvt.splitl/reads-no-further-than-first-failing",
                    fn () => let val (rdr, asked) = traced ()
                             in ignore (StringCvt.splitl Char.isDigit rdr ("12ab3", 0));
                                List.all (fn i => i <= 2) (asked ()) andalso List.exists (fn i => i = 2) (asked ())
                             end)
  val () = T.check ("StringCvt.splitl/reads-from-the-source-given",
                    fn () => let val (rdr, asked) = traced ()
                             in ignore (StringCvt.splitl Char.isAlpha rdr ("12ab3", 2));
                                List.all (fn i => 2 <= i andalso i <= 4) (asked ())
                             end)
  (* an exception of the reader or of the predicate passes through *)
  val () = T.raises ("StringCvt.splitl/reader-raises", T.isFail,
                     fn () => StringCvt.splitl Char.isDigit (fn (_ : int) => raise Fail "rdr") 0)
  val () = T.raises ("StringCvt.splitl/predicate-raises", T.isDiv,
                     fn () => StringCvt.splitl (fn c => 1 div (Char.ord c - 50) <> 0) listRd (String.explode "123"))

  (* ---- takel, dropl ----
     "takel f rdr s = #1(splitl f rdr s)", "dropl f rdr s = #2(splitl f rdr s)" *)
  val () = eqS ("StringCvt.takel/list-basic", "123", fn () => StringCvt.takel Char.isDigit listRd (String.explode "123ab4"))
  val () = eqS ("StringCvt.takel/none-satisfy", "", fn () => StringCvt.takel Char.isDigit listRd (String.explode "ab4"))
  val () = eqS ("StringCvt.takel/all-satisfy", "123", fn () => StringCvt.takel Char.isDigit listRd (String.explode "123"))
  val () = eqS ("StringCvt.takel/empty-source", "", fn () => StringCvt.takel Char.isDigit listRd [])
  val () = eqS ("StringCvt.takel/string-from-the-middle", "ab", fn () => StringCvt.takel Char.isAlpha strRd ("123ab4", 3))
  val () = eqS ("StringCvt.takel/maximal-prefix-only", "aa", fn () => StringCvt.takel (fn c => c = #"a") strRd ("aabaa", 0))
  val () = eqCL ("StringCvt.dropl/list-basic", [#"a", #"b", #"4"], fn () => StringCvt.dropl Char.isDigit listRd (String.explode "123ab4"))
  val () = eqCL ("StringCvt.dropl/none-satisfy", [#"a", #"4"], fn () => StringCvt.dropl Char.isDigit listRd [#"a", #"4"])
  val () = eqCL ("StringCvt.dropl/all-satisfy", [], fn () => StringCvt.dropl Char.isDigit listRd (String.explode "123"))
  val () = eqCL ("StringCvt.dropl/empty-source", [], fn () => StringCvt.dropl Char.isDigit listRd [])
  val () = eqP ("StringCvt.dropl/string-basic", ("123ab4", 3), fn () => StringCvt.dropl Char.isDigit strRd ("123ab4", 0))
  val () = eqP ("StringCvt.dropl/string-from-the-middle", ("123ab4", 5), fn () => StringCvt.dropl Char.isAlpha strRd ("123ab4", 3))
  val () = eqP ("StringCvt.dropl/maximal-prefix-only", ("aabaa", 2), fn () => StringCvt.dropl (fn c => c = #"a") strRd ("aabaa", 0))
  val () = eqCL ("StringCvt.takel/predicate-order", [#"1", #"2", #"a"],
                 fn () => let val (f, seen) = trace Char.isDigit
                          in ignore (StringCvt.takel f listRd (String.explode "12ab3")); seen () end)
  val () = eqCL ("StringCvt.dropl/predicate-order", [#"1", #"2", #"a"],
                 fn () => let val (f, seen) = trace Char.isDigit
                          in ignore (StringCvt.dropl f listRd (String.explode "12ab3")); seen () end)
  val () = T.check ("StringCvt.takel/reads-no-further-than-first-failing",
                    fn () => let val (rdr, asked) = traced ()
                             in ignore (StringCvt.takel Char.isDigit rdr ("12ab3", 0)); List.all (fn i => i <= 2) (asked ()) end)
  val () = T.check ("StringCvt.dropl/reads-no-further-than-first-failing",
                    fn () => let val (rdr, asked) = traced ()
                             in ignore (StringCvt.dropl Char.isDigit rdr ("12ab3", 0)); List.all (fn i => i <= 2) (asked ()) end)

  (* ---- skipWS ----
     "A whitespace character is one that satisfies the predicate Char.isSpace.
     It is equivalent to dropl Char.isSpace." Char.isSpace: "space, newline,
     tab, carriage return, vertical tab, formfeed". The checks labelled wsx-*
     need carriage return, vertical tab and formfeed to be skipped, the others
     only space, tab and newline. *)
  val () = eqCL ("StringCvt.skipWS/spaces", [#"x", #" ", #"y"], fn () => StringCvt.skipWS listRd (String.explode "  x y"))
  val () = eqCL ("StringCvt.skipWS/space-tab-newline", [#"x", #"\n"], fn () => StringCvt.skipWS listRd (String.explode " \t\n \n\tx\n"))
  val () = eqCL ("StringCvt.skipWS/wsx-every-whitespace-character", [#"x", #" "],
                 fn () => StringCvt.skipWS listRd (String.explode " \t\n\r\v\f \n\tx "))
  val () = eqCL ("StringCvt.skipWS/no-whitespace", [#"x", #" "], fn () => StringCvt.skipWS listRd [#"x", #" "])
  val () = eqCL ("StringCvt.skipWS/only-whitespace", [], fn () => StringCvt.skipWS listRd (String.explode " \n\t "))
  val () = eqCL ("StringCvt.skipWS/empty-source", [], fn () => StringCvt.skipWS listRd [])
  val () = eqP ("StringCvt.skipWS/string-basic", (" \t 42 ", 3), fn () => StringCvt.skipWS strRd (" \t 42 ", 0))
  val () = eqP ("StringCvt.skipWS/string-from-the-middle", ("a  b", 3), fn () => StringCvt.skipWS strRd ("a  b", 1))
  val () = eqP ("StringCvt.skipWS/string-at-non-whitespace", ("a  b", 0), fn () => StringCvt.skipWS strRd ("a  b", 0))
  val () = eqP ("StringCvt.skipWS/string-at-the-end", ("ab ", 3), fn () => StringCvt.skipWS strRd ("ab ", 2))
  (* of the 256 characters exactly 9 to 13 and 32 are skipped *)
  val () = eqIL ("StringCvt.skipWS/wsx-exactly-the-six-characters", [9, 10, 11, 12, 13, 32],
                 fn () => List.filter (fn code => StringCvt.skipWS listRd [Char.chr code, #"x"] = [#"x"])
                                      (List.tabulate (256, fn i => i)))
  val () = eqIL ("StringCvt.skipWS/other-characters-stay", [],
                 fn () => List.filter (fn code => not (List.exists (fn w => w = code) [9, 10, 11, 12, 13, 32])
                                                  andalso StringCvt.skipWS listRd [Char.chr code, #" "] <> [Char.chr code, #" "])
                                      (List.tabulate (256, fn i => i)))
  val () = T.check ("StringCvt.skipWS/reads-no-further-than-first-non-whitespace",
                    fn () => let val (rdr, asked) = traced ()
                             in ignore (StringCvt.skipWS rdr ("  ab  ", 0)); List.all (fn i => i <= 2) (asked ()) end)

  (* ---- scanString ----
     "scanString converts the string into a character source (type cs) and
     applies the scanning function." *)
  (* the page's example: "scanString (fn rdr => SOME o (splitl f rdr))" *)
  val () = eqSO ("StringCvt.scanString/page-example-splitl", SOME "123",
                 fn () => StringCvt.scanString (fn rdr => SOME o (StringCvt.splitl Char.isDigit rdr)) "123abc")
  val () = eqSO ("StringCvt.scanString/splitl-nothing-satisfies", SOME "",
                 fn () => StringCvt.scanString (fn rdr => SOME o (StringCvt.splitl Char.isDigit rdr)) "abc")
  val () = eqSO ("StringCvt.scanString/splitl-empty-string", SOME "",
                 fn () => StringCvt.scanString (fn rdr => SOME o (StringCvt.splitl Char.isDigit rdr)) "")
  (* the source produces the characters of the string, in order, and then NONE *)
  val () = eqSO ("StringCvt.scanString/source-is-the-string", SOME "hello, world", fn () => StringCvt.scanString whole "hello, world")
  val () = eqSO ("StringCvt.scanString/source-of-empty-string", SOME "", fn () => StringCvt.scanString whole "")
  val () = eqSO ("StringCvt.scanString/source-of-all-256-characters", SOME (String.implode (List.tabulate (256, Char.chr))),
                 fn () => StringCvt.scanString whole (String.implode (List.tabulate (256, Char.chr))))
  val () = eqI ("StringCvt.scanString/source-of-long-string", 100000,
                fn () => String.size (valOf (StringCvt.scanString whole (StringCvt.padLeft #"a" 100000 ""))))
  val () = T.eq (T.option T.char) ("StringCvt.scanString/first-character", SOME #"a",
             fn () => StringCvt.scanString (fn rdr => rdr) "abc")
  val () = T.eq (T.option T.char) ("StringCvt.scanString/first-character-of-empty-string", NONE,
             fn () => StringCvt.scanString (fn rdr => rdr) "")
  (* what the scanning function returns is the result: NONE, or SOME of the
     value, whatever is left of the source *)
  val () = eqIO ("StringCvt.scanString/NONE", NONE,
                 fn () => StringCvt.scanString (fn _ => fn (_ : StringCvt.cs) => NONE : (int * StringCvt.cs) option) "123")
  val () = eqIO ("StringCvt.scanString/nothing-read", SOME 42,
                 fn () => StringCvt.scanString (fn _ => fn (src : StringCvt.cs) => SOME (42, src)) "123")
  val () = eqIO ("StringCvt.scanString/nothing-read-empty-string", SOME 42,
                 fn () => StringCvt.scanString (fn _ => fn (src : StringCvt.cs) => SOME (42, src)) "")
  val () = eqSO ("StringCvt.scanString/rest-is-ignored", SOME "ab",
                 fn () => StringCvt.scanString (fn rdr => fn src =>
                            case rdr src of
                              SOME (a, src') => (case rdr src' of
                                                   SOME (b, src'') => SOME (String.implode [a, b], src'')
                                                 | NONE => NONE)
                            | NONE => NONE) "abcdef")
  val () = eqSO ("StringCvt.scanString/too-short-for-the-scanner", NONE,
                 fn () => StringCvt.scanString (fn rdr => fn src =>
                            case rdr src of
                              SOME (a, src') => (case rdr src' of
                                                   SOME (b, src'') => SOME (String.implode [a, b], src'')
                                                 | NONE => NONE)
                            | NONE => NONE) "a")
  (* "A value of this type represents the state of a character stream": a
     state can be read again, which is what backtracking needs *)
  val () = eqSO ("StringCvt.scanString/state-can-be-read-again", SOME "aab",
                 fn () => StringCvt.scanString (fn rdr => fn (src : StringCvt.cs) =>
                            case (rdr src, rdr src) of
                              (SOME (a, _), SOME (a', src')) =>
                                (case rdr src' of
                                   SOME (b, src'') => SOME (String.implode [a, a', b], src'')
                                 | NONE => NONE)
                            | _ => NONE) "abc")
  val () = eqB ("StringCvt.scanString/end-can-be-read-again", true,
                fn () => valOf (StringCvt.scanString (fn rdr => fn src =>
                           let val src' = #2 (valOf (rdr src))
                           in SOME (not (Option.isSome (rdr src')) andalso not (Option.isSome (rdr src'))
                                    andalso Option.isSome (rdr src), src') end) "a"))
  (* the scanning function is applied once, to one reader and one source *)
  val () = T.eq (T.pair (T.int, T.int)) ("StringCvt.scanString/scanner-applied-once", (1, 1),
             fn () =>
               let val outer = ref 0
                   val inner = ref 0
               in
                 ignore (StringCvt.scanString (fn rdr => (outer := !outer + 1;
                                                           fn src => (inner := !inner + 1; whole rdr src))) "abc");
                 (!outer, !inner)
               end)
  (* an exception of the scanning function passes through *)
  val () = T.raises ("StringCvt.scanString/scanner-raises", T.isFail,
                     fn () => StringCvt.scanString (fn _ => fn (_ : StringCvt.cs) => (raise Fail "scan") : (int * StringCvt.cs) option) "abc")
  (* the functions of this structure work on the source of scanString *)
  val () = eqSO ("StringCvt.scanString/skipWS-then-takel", SOME "42",
                 fn () => StringCvt.scanString (fn rdr => fn src =>
                            let val (tok, rest) = StringCvt.splitl Char.isDigit rdr (StringCvt.skipWS rdr src)
                            in if tok = "" then NONE else SOME (tok, rest) end) " \t\n42 7")
  val () = eqSO ("StringCvt.scanString/skipWS-then-takel-NONE", NONE,
                 fn () => StringCvt.scanString (fn rdr => fn src =>
                            let val (tok, rest) = StringCvt.splitl Char.isDigit rdr (StringCvt.skipWS rdr src)
                            in if tok = "" then NONE else SOME (tok, rest) end) "  x42")
  val () = eqSO ("StringCvt.scanString/dropl-then-whole", SOME "b1",
                 fn () => StringCvt.scanString (fn rdr => fn src => whole rdr (StringCvt.dropl (fn c => c = #"a") rdr src)) "aaab1")
  (* splitl asks the source of scanString for no more than the character that stops it *)
  val () = eqI ("StringCvt.scanString/splitl-reads-one-character-ahead", 3,
                fn () =>
                  let val asked = ref 0
                  in
                    ignore (StringCvt.scanString (fn rdr => fn src =>
                              SOME (StringCvt.splitl Char.isDigit (fn s => (asked := !asked + 1; rdr s)) src)) "12abcdef");
                    !asked
                  end)
  (*<< Bool.scan *)
  (* "Typical scanning functions are Bool.scan and Date.scan." *)
  val () = T.eq (T.option T.bool) ("StringCvt.scanString/Bool.scan", SOME true, fn () => StringCvt.scanString Bool.scan "true")
  val () = T.eq (T.option T.bool) ("StringCvt.scanString/Bool.scan-rest-is-ignored", SOME false,
             fn () => StringCvt.scanString Bool.scan "false, true")
  val () = T.eq (T.option T.bool) ("StringCvt.scanString/Bool.scan-NONE", NONE, fn () => StringCvt.scanString Bool.scan "maybe")
  (* "Bool.scan List.getItem has the type (bool, char list) reader" *)
  val () = T.eq (T.option (T.pair (T.bool, T.list T.char))) ("StringCvt.reader/Bool.scan-List.getItem", SOME (true, [#"!", #"?"]),
             fn () => let val rdr : (bool, char list) StringCvt.reader = Bool.scan List.getItem
                      in rdr (String.explode "true!?") end)
  (*>> Bool.scan *)
  (*<< Int.scan-scanString *)
  val () = eqIO ("StringCvt.scanString/Int.scan", SOME 42, fn () => StringCvt.scanString (Int.scan StringCvt.DEC) "42")
  val () = eqIO ("StringCvt.scanString/Int.scan-rest-is-ignored", SOME 42, fn () => StringCvt.scanString (Int.scan StringCvt.DEC) "42abc")
  val () = eqIO ("StringCvt.scanString/Int.scan-NONE", NONE, fn () => StringCvt.scanString (Int.scan StringCvt.DEC) "abc42")
  val () = eqIO ("StringCvt.scanString/Int.scan-empty-string", NONE, fn () => StringCvt.scanString (Int.scan StringCvt.DEC) "")
  (* a scanning function built from two: an integer, a comma, an integer *)
  val () = T.eq (T.option (T.pair (T.int, T.int))) ("StringCvt.scanString/composed-scanner", SOME (12, ~7),
             fn () => StringCvt.scanString (fn rdr => fn src =>
                        case Int.scan StringCvt.DEC rdr src of
                          NONE => NONE
                        | SOME (a, src) =>
                            (case rdr src of
                               SOME (#",", src) => (case Int.scan StringCvt.DEC rdr src of
                                                      NONE => NONE
                                                    | SOME (b, src) => SOME ((a, b), src))
                             | _ => NONE)) "12,~7;")
  (*>> Int.scan-scanString *)

  (* ---- laws, on pseudo-random strings ---- *)
  (* the number of characters at the start of s, from index i, that satisfy f *)
  fun run (f, s, i) = if i < String.size s andalso f (String.sub (s, i)) then 1 + run (f, s, i + 1) else 0
  fun copies (c, n) = String.implode (List.tabulate (if n < 0 then 0 else n, fn _ => c))
  fun randomText () =
    String.implode (List.tabulate (T.range (0, 12), fn _ => T.oneOf [#"a", #"b", #"1", #"2", #" ", #"\n", #"\t"]))

  val () = T.seed 23
  val () = T.repeat (40, fn k =>
    let
      val n = Int.toString k
      val s = randomText ()
      val i = T.range (0, String.size s)
      val f = T.oneOf [Char.isDigit, Char.isAlpha, Char.isSpace, fn c => c <> #"1", fn _ => true, fn _ => false]
      val c = T.oneOf [#" ", #"0", #"*"]
      val w = T.range (~3, 20)
      val m = run (f, s, i)
      val ws = run (Char.isSpace, s, i)
    in
      eqSP ("StringCvt.splitl/law-string-" ^ n, (String.substring (s, i, m), (s, i + m)), fn () => StringCvt.splitl f strRd (s, i));
      eqSCL ("StringCvt.splitl/law-list-" ^ n, (String.substring (s, i, m), String.explode (String.extract (s, i + m, NONE))),
             fn () => StringCvt.splitl f listRd (String.explode (String.extract (s, i, NONE))));
      eqS ("StringCvt.splitl/law-parts-make-the-whole-" ^ n, String.extract (s, i, NONE),
           fn () => let val (pref, rest) = StringCvt.splitl f listRd (String.explode (String.extract (s, i, NONE)))
                    in pref ^ String.implode rest end);
      eqS ("StringCvt.takel/law-" ^ n, String.substring (s, i, m), fn () => StringCvt.takel f strRd (s, i));
      eqP ("StringCvt.dropl/law-" ^ n, (s, i + m), fn () => StringCvt.dropl f strRd (s, i));
      eqB ("StringCvt.takel/law-is-first-of-splitl-" ^ n, true,
           fn () => StringCvt.takel f strRd (s, i) = #1 (StringCvt.splitl f strRd (s, i)));
      eqB ("StringCvt.dropl/law-is-second-of-splitl-" ^ n, true,
           fn () => StringCvt.dropl f strRd (s, i) = #2 (StringCvt.splitl f strRd (s, i)));
      eqP ("StringCvt.skipWS/law-" ^ n, (s, i + ws), fn () => StringCvt.skipWS strRd (s, i));
      eqB ("StringCvt.skipWS/law-is-dropl-isSpace-" ^ n, true,
           fn () => StringCvt.skipWS strRd (s, i) = StringCvt.dropl Char.isSpace strRd (s, i));
      eqSO ("StringCvt.scanString/law-whole-" ^ n, SOME s, fn () => StringCvt.scanString whole s);
      eqSO ("StringCvt.scanString/law-splitl-" ^ n, SOME (String.substring (s, 0, run (f, s, 0))),
            fn () => StringCvt.scanString (fn rdr => SOME o (StringCvt.splitl f rdr)) s);
      eqSO ("StringCvt.scanString/law-skipWS-" ^ n, SOME (String.extract (s, run (Char.isSpace, s, 0), NONE)),
            fn () => StringCvt.scanString (fn rdr => fn src => whole rdr (StringCvt.skipWS rdr src)) s);
      eqS ("StringCvt.padLeft/law-" ^ n, copies (c, w - String.size s) ^ s, fn () => StringCvt.padLeft c w s);
      eqS ("StringCvt.padRight/law-" ^ n, s ^ copies (c, w - String.size s), fn () => StringCvt.padRight c w s);
      eqI ("StringCvt.padLeft/law-size-" ^ n, Int.max (w, String.size s), fn () => String.size (StringCvt.padLeft c w s));
      eqI ("StringCvt.padRight/law-size-" ^ n, Int.max (w, String.size s), fn () => String.size (StringCvt.padRight c w s))
    end)
end

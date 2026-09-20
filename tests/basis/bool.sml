(* requires: Bool *)
(* The Bool structure (signature BOOL). Expected values follow the text of
   https://smlfamily.github.io/Basis/bool.html.

   scan and fromString: "Ignoring case and initial whitespace, the sequences
   "true" and "false" are converted to the corresponding boolean values."
   Whitespace is what Char.isSpace accepts (StringCvt.skipWS: "A whitespace
   character is one that satisfies the predicate Char.isSpace"): "space,
   newline, tab, carriage return, vertical tab, formfeed". Whatever follows the
   sequence is left in the stream, so a string only has to start with it. *)
structure TestBool =
struct
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqI = T.eq T.int
  val eqL = T.eq (T.list T.int)
  val eqOB = T.eq (T.option T.bool)

  (* ---- the datatype is the top-level one ---- *)
  val () = eqB ("Bool.true/same-as-toplevel", true, fn () => Bool.true)
  val () = eqB ("Bool.false/same-as-toplevel", false, fn () => Bool.false)
  val () = eqI ("Bool.true/pattern", 1, fn () => case true of Bool.true => 1 | Bool.false => 0)
  val () = eqI ("Bool.false/pattern", 0, fn () => case false of Bool.true => 1 | Bool.false => 0)
  val () = eqB ("Bool.bool/distinct", false, fn () => Bool.true = Bool.false)
  val () = eqI ("Bool.bool/if", 1, fn () => if (Bool.true : Bool.bool) then 1 else 0)
  (* Discussion: andalso and orelse "provide short-circuit evaluation" *)
  val () = eqL ("Bool.bool/andalso-short-circuit", [1],
                fn () =>
                  let val log = ref []
                      fun say (n, b) = (log := n :: !log; b)
                  in ignore (say (1, false) andalso say (2, true)); List.rev (!log) end)
  val () = eqL ("Bool.bool/orelse-short-circuit", [1],
                fn () =>
                  let val log = ref []
                      fun say (n, b) = (log := n :: !log; b)
                  in ignore (say (1, true) orelse say (2, false)); List.rev (!log) end)

  (* ---- not ---- *)
  val () = eqB ("Bool.not/true", false, fn () => Bool.not true)
  val () = eqB ("Bool.not/false", true, fn () => Bool.not false)
  val () = eqB ("Bool.not/toplevel-true", false, fn () => not true)
  val () = eqB ("Bool.not/toplevel-false", true, fn () => not false)
  val () = eqB ("Bool.not/involution-true", true, fn () => Bool.not (Bool.not true))
  val () = eqB ("Bool.not/involution-false", false, fn () => Bool.not (Bool.not false))

  (* ---- toString: "either "true" or "false"" ---- *)
  val () = eqS ("Bool.toString/true", "true", fn () => Bool.toString true)
  val () = eqS ("Bool.toString/false", "false", fn () => Bool.toString false)

  (* ---- fromString ----
     Labels: case-* need case to be ignored; ws-* need space, tab or newline to
     be skipped, wsx-* carriage return, vertical tab or formfeed; prefix-* need
     the characters after the sequence to be left alone; mixed-* need several
     of these. *)
  val () = eqOB ("Bool.fromString/true", SOME true, fn () => Bool.fromString "true")
  val () = eqOB ("Bool.fromString/false", SOME false, fn () => Bool.fromString "false")
  val () = eqOB ("Bool.fromString/toString-true", SOME true, fn () => Bool.fromString (Bool.toString true))
  val () = eqOB ("Bool.fromString/toString-false", SOME false, fn () => Bool.fromString (Bool.toString false))
  (* "otherwise it returns NONE" *)
  val () = eqOB ("Bool.fromString/none-empty", NONE, fn () => Bool.fromString "")
  val () = eqOB ("Bool.fromString/none-t", NONE, fn () => Bool.fromString "t")
  val () = eqOB ("Bool.fromString/none-tru", NONE, fn () => Bool.fromString "tru")
  val () = eqOB ("Bool.fromString/none-fals", NONE, fn () => Bool.fromString "fals")
  val () = eqOB ("Bool.fromString/none-FALs", NONE, fn () => Bool.fromString "FALs")
  val () = eqOB ("Bool.fromString/none-yes", NONE, fn () => Bool.fromString "yes")
  val () = eqOB ("Bool.fromString/none-one", NONE, fn () => Bool.fromString "1")
  val () = eqOB ("Bool.fromString/none-zero", NONE, fn () => Bool.fromString "0")
  val () = eqOB ("Bool.fromString/none-xtrue", NONE, fn () => Bool.fromString "xtrue")
  val () = eqOB ("Bool.fromString/none-nottrue", NONE, fn () => Bool.fromString "nottrue")
  val () = eqOB ("Bool.fromString/none-t-rue", NONE, fn () => Bool.fromString "t rue")
  val () = eqOB ("Bool.fromString/none-tru-e", NONE, fn () => Bool.fromString "tru e")
  val () = eqOB ("Bool.fromString/none-trufalse", NONE, fn () => Bool.fromString "trufalse")
  val () = eqOB ("Bool.fromString/none-quoted", NONE, fn () => Bool.fromString "\"true\"")
  val () = eqOB ("Bool.fromString/none-whitespace-only", NONE, fn () => Bool.fromString "   ")
  val () = eqOB ("Bool.fromString/none-newline-only", NONE, fn () => Bool.fromString "\n")
  val () = eqOB ("Bool.fromString/none-whitespace-inside", NONE, fn () => Bool.fromString " tr ue")
  (* the characters next to the whitespace characters (9 to 13, and 32) are
     not whitespace *)
  val () = List.app (fn code =>
    eqOB ("Bool.fromString/none-not-whitespace-" ^ Int.toString code, NONE,
          fn () => Bool.fromString (String.str (Char.chr code) ^ "true")))
    [0, 8, 14, 31, 33, 95, 127]
  (* "Ignoring case" *)
  val () = eqOB ("Bool.fromString/case-TRUE", SOME true, fn () => Bool.fromString "TRUE")
  val () = eqOB ("Bool.fromString/case-FALSE", SOME false, fn () => Bool.fromString "FALSE")
  val () = eqOB ("Bool.fromString/case-True", SOME true, fn () => Bool.fromString "True")
  val () = eqOB ("Bool.fromString/case-False", SOME false, fn () => Bool.fromString "False")
  val () = eqOB ("Bool.fromString/case-tRuE", SOME true, fn () => Bool.fromString "tRuE")
  val () = eqOB ("Bool.fromString/case-fAlSe", SOME false, fn () => Bool.fromString "fAlSe")
  val () = eqOB ("Bool.fromString/case-truE", SOME true, fn () => Bool.fromString "truE")
  (* "Ignoring ... initial whitespace" *)
  val () = eqOB ("Bool.fromString/ws-space", SOME true, fn () => Bool.fromString " true")
  val () = eqOB ("Bool.fromString/ws-tab", SOME true, fn () => Bool.fromString "\ttrue")
  val () = eqOB ("Bool.fromString/ws-newline", SOME true, fn () => Bool.fromString "\ntrue")
  val () = eqOB ("Bool.fromString/ws-spaces", SOME false, fn () => Bool.fromString "    false")
  val () = eqOB ("Bool.fromString/ws-several", SOME false, fn () => Bool.fromString " \t\n \n\tfalse")
  val () = eqOB ("Bool.fromString/wsx-return", SOME true, fn () => Bool.fromString "\rtrue")
  val () = eqOB ("Bool.fromString/wsx-vertical-tab", SOME true, fn () => Bool.fromString "\vtrue")
  val () = eqOB ("Bool.fromString/wsx-formfeed", SOME true, fn () => Bool.fromString "\ftrue")
  val () = eqOB ("Bool.fromString/wsx-all-six", SOME false, fn () => Bool.fromString " \t\n\r\v\ffalse")
  (* the rest of the string is left alone *)
  val () = eqOB ("Bool.fromString/prefix-trailing-space", SOME true, fn () => Bool.fromString "true ")
  val () = eqOB ("Bool.fromString/prefix-trailing-newline", SOME false, fn () => Bool.fromString "false\n")
  val () = eqOB ("Bool.fromString/prefix-truely", SOME true, fn () => Bool.fromString "truely")
  val () = eqOB ("Bool.fromString/prefix-falsetto", SOME false, fn () => Bool.fromString "falsetto")
  val () = eqOB ("Bool.fromString/prefix-truefalse", SOME true, fn () => Bool.fromString "truefalse")
  val () = eqOB ("Bool.fromString/prefix-falsetrue", SOME false, fn () => Bool.fromString "falsetrue")
  val () = eqOB ("Bool.fromString/prefix-two-words", SOME true, fn () => Bool.fromString "true false")
  val () = eqOB ("Bool.fromString/mixed-ws-case", SOME true, fn () => Bool.fromString "\n\tTrue")
  val () = eqOB ("Bool.fromString/mixed-ws-case-rest", SOME false, fn () => Bool.fromString "  FALSE;")

  (* ---- a model of the specification, for the laws below ---- *)
  fun skipSpace (c :: cs) = if Char.isSpace c then skipSpace cs else c :: cs
    | skipSpace [] = []
  (* after (word, cs): what follows word at the head of cs, ignoring case *)
  fun after ([], cs) = SOME cs
    | after (_ :: _, []) = NONE
    | after (w :: ws, c :: cs) = if Char.toLower c = w then after (ws, cs) else NONE
  fun modelScan (cs : char list) : (bool * char list) option =
    let val cs = skipSpace cs
    in
      case after (String.explode "true", cs) of
        SOME rest => SOME (true, rest)
      | NONE => (case after (String.explode "false", cs) of
                   SOME rest => SOME (false, rest)
                 | NONE => NONE)
    end
  fun modelFromString s = case modelScan (String.explode s) of SOME (b, _) => SOME b | NONE => NONE

  (* random texts, by the kind of thing they need (see the labels above):
     whitespace or nothing, then a word, then anything *)
  val lower = ["true", "false", "tru", "fals", "x", ""]
  val upper = ["TRUE", "FALSE", "True", "False", "tRuE", "fAlSe", "TRU", "fALS"]
  val ws = [" ", "  ", "\t", "\n", " \n\t "]
  val wsx = ["\r", "\v", "\f", "\r\n", " \f\v"]
  val tails = ["", "e", "x", "1", " ", "true", "false", "\n"]
  val kinds =
    [("prefix", [""], lower),
     ("case", [""], lower @ upper @ upper),
     ("ws", "" :: ws @ ws, lower),
     ("wsx", "" :: wsx @ wsx, lower),
     ("mixed", "" :: ws @ wsx, lower @ upper)]
  fun randomText (leads, words) = T.oneOf leads ^ T.oneOf words ^ T.oneOf tails

  val () = T.seed 1
  val () = List.app (fn (kind, leads, words) =>
    T.repeat (30, fn i =>
      let val s = randomText (leads, words)
      in
        eqOB ("Bool.fromString/" ^ kind ^ "-model-" ^ Int.toString i, modelFromString s,
              fn () => Bool.fromString s)
      end))
    kinds
  val () = List.app (fn b =>
    (eqOB ("Bool.fromString/toString-law-" ^ Bool.toString b, SOME b, fn () => Bool.fromString (Bool.toString b));
     eqS ("Bool.toString/of-not-" ^ Bool.toString b, if b then "false" else "true",
          fn () => Bool.toString (Bool.not b))))
    [true, false]

  (*<< scan *)
  (* scan getc strm: "On successful scanning of a boolean value, scan returns
     SOME(b, rest), where b is the scanned value and rest is the remaining
     character stream." Here with readers written out by hand. *)
  val eqScanL = T.eq (T.option (T.pair (T.bool, T.list T.char)))
  val eqScanI = T.eq (T.option (T.pair (T.bool, T.int)))
  val eqScanSI = T.eq (T.option (T.pair (T.bool, T.pair (T.string, T.int))))

  (* a list of characters *)
  fun listReader ([] : char list) = NONE
    | listReader (c :: cs) = SOME (c, cs)
  (* a string and an index into it *)
  fun stringReader (s : string, i : int) =
    if i < String.size s then SOME (String.sub (s, i), (s, i + 1)) else NONE
  (* an index into a fixed string *)
  fun indexReader (s : string) (i : int) =
    if i < String.size s then SOME (String.sub (s, i), i + 1) else NONE

  val () = eqScanL ("Bool.scan/list-true", SOME (true, []), fn () => Bool.scan listReader (String.explode "true"))
  val () = eqScanL ("Bool.scan/list-false", SOME (false, []), fn () => Bool.scan listReader (String.explode "false"))
  val () = eqScanL ("Bool.scan/list-rest", SOME (true, [#"X", #"Y"]),
                    fn () => Bool.scan listReader (String.explode "trueXY"))
  val () = eqScanL ("Bool.scan/list-rest-keeps-whitespace", SOME (true, String.explode " false"),
                    fn () => Bool.scan listReader (String.explode "true false"))
  val () = eqScanL ("Bool.scan/list-rest-is-a-prefix-of-true", SOME (true, String.explode "tru"),
                    fn () => Bool.scan listReader (String.explode "truetru"))
  val () = eqScanL ("Bool.scan/none-empty", NONE, fn () => Bool.scan listReader [])
  val () = eqScanL ("Bool.scan/none-whitespace-only", NONE, fn () => Bool.scan listReader (String.explode " \n "))
  val () = eqScanL ("Bool.scan/none-tru", NONE, fn () => Bool.scan listReader (String.explode "tru"))
  val () = eqScanL ("Bool.scan/none-fals", NONE, fn () => Bool.scan listReader (String.explode "fals"))
  val () = eqScanL ("Bool.scan/none-xtrue", NONE, fn () => Bool.scan listReader (String.explode "xtrue"))
  val () = eqScanL ("Bool.scan/none-tr-ue", NONE, fn () => Bool.scan listReader (String.explode "tr ue"))
  val () = eqScanL ("Bool.scan/case-list", SOME (true, [#"!"]),
                    fn () => Bool.scan listReader (String.explode "TrUe!"))
  val () = eqScanL ("Bool.scan/ws-list", SOME (false, String.explode ", more"),
                    fn () => Bool.scan listReader (String.explode "  \tfalse, more"))
  val () = eqScanL ("Bool.scan/wsx-list", SOME (false, [#"\r"]),
                    fn () => Bool.scan listReader (String.explode "\r\v\ffalse\r"))
  val () = eqScanL ("Bool.scan/mixed-list", SOME (false, String.explode ", more"),
                    fn () => Bool.scan listReader (String.explode "  \tFALSE, more"))
  (* StringCvt: "Bool.scan List.getItem has the type (bool, char list) reader" *)
  val () = eqScanL ("Bool.scan/List.getItem", SOME (false, [#"!"]),
                    fn () => Bool.scan List.getItem (String.explode "false!"))

  val () = eqScanSI ("Bool.scan/string-index", SOME (true, ("true!", 4)),
                     fn () => Bool.scan stringReader ("true!", 0))
  val () = eqScanSI ("Bool.scan/string-index-from-the-middle", SOME (false, ("true;false;true", 10)),
                     fn () => Bool.scan stringReader ("true;false;true", 5))
  val () = eqScanSI ("Bool.scan/none-string-index-middle-of-word", NONE,
                     fn () => Bool.scan stringReader ("true", 1))
  val () = eqScanSI ("Bool.scan/none-string-index-at-end", NONE, fn () => Bool.scan stringReader ("true", 4))
  val () = eqScanSI ("Bool.scan/ws-string-index", SOME (true, ("  true!", 6)),
                     fn () => Bool.scan stringReader ("  true!", 0))
  val () = eqScanI ("Bool.scan/index", SOME (false, 5), fn () => Bool.scan (indexReader "false") 0)
  val () = eqScanI ("Bool.scan/none-index", NONE, fn () => Bool.scan (indexReader "maybe") 0)
  val () = eqScanI ("Bool.scan/case-index", SOME (false, 5), fn () => Bool.scan (indexReader "FaLsE") 0)
  val () = eqScanI ("Bool.scan/ws-index", SOME (true, 6), fn () => Bool.scan (indexReader "\n\ttrue\n") 0)
  val () = eqScanI ("Bool.scan/wsx-index", SOME (true, 7), fn () => Bool.scan (indexReader "\r\n\ttrue\n") 0)

  (* the rest can be scanned again *)
  fun scanAll cs = case Bool.scan listReader cs of
                     SOME (b, rest) => b :: scanAll rest
                   | NONE => []
  val () = T.eq (T.list T.bool) ("Bool.scan/repeatedly", [true, false, false, true],
             fn () => scanAll (String.explode "truefalsefalsetrue-true"))
  val () = T.eq (T.list T.bool) ("Bool.scan/ws-repeatedly", [true, false, true, true],
             fn () => scanAll (String.explode "true false\ntrue\ttrue stop true"))

  val () = T.seed 2
  val () = List.app (fn (kind, leads, words) =>
    T.repeat (30, fn i =>
      let
        val n = Int.toString i
        val s = randomText (leads, words)
        val cs = String.explode s
      in
        eqScanL ("Bool.scan/" ^ kind ^ "-model-" ^ n, modelScan cs, fn () => Bool.scan listReader cs);
        T.check ("Bool.scan/agrees-with-fromString-" ^ kind ^ "-" ^ n,
                 fn () => Bool.fromString s
                          = (case Bool.scan listReader cs of SOME (b, _) => SOME b | NONE => NONE))
      end))
    kinds
  (*>> scan *)

  (*<< scanString *)
  (* "The function fromString is equivalent to StringCvt.scanString scan." *)
  val () = eqOB ("Bool.scan/scanString-true", SOME true, fn () => StringCvt.scanString Bool.scan "true")
  val () = eqOB ("Bool.scan/scanString-false", SOME false, fn () => StringCvt.scanString Bool.scan "false")
  val () = eqOB ("Bool.scan/scanString-rest", SOME false, fn () => StringCvt.scanString Bool.scan "false rest")
  val () = eqOB ("Bool.scan/none-scanString-tru", NONE, fn () => StringCvt.scanString Bool.scan "tru")
  val () = eqOB ("Bool.scan/none-scanString-empty", NONE, fn () => StringCvt.scanString Bool.scan "")
  val () = eqOB ("Bool.scan/mixed-scanString", SOME false,
                 fn () => StringCvt.scanString Bool.scan " \n FaLsE rest")
  val () = T.seed 3
  val () = List.app (fn (kind, leads, words) =>
    T.repeat (30, fn i =>
      let val s = randomText (leads, words)
      in
        T.check ("Bool.fromString/scanString-scan-" ^ kind ^ "-" ^ Int.toString i,
                 fn () => Bool.fromString s = StringCvt.scanString Bool.scan s)
      end))
    kinds
  (*>> scanString *)
end

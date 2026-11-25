(* What a Haskell 2010 corpus source says about itself, and the filter that
   keeps untrusted code from every compiler (the haskell2010 roadmap's D40,
   M2; tests/hs2010/corpus/README.md): E8's scan2010.py and the copies of
   its judge.py (the haskell2010 drafts' results/E8/scripts), ported
   character for character, as tests/runner/hssource.sml ports the 98
   corpus's, so that the 2010 harness gives E8's verdicts.

   A candidate any of whose modules turns on Template Haskell or
   quasi-quotes, uses CPP (a pragma, -cpp, or a directive line, in a
   literate file too), imports by `capi`, or whose options name a
   preprocessor, a plugin or an option file goes to no compiler, since each
   runs code or reads files at compile time; in every copy that is compiled
   the pragmas ANN (which GHC evaluates), INCLUDE and OPTIONS are blanked.
   By D40's B the rule for CPP is a switch: CPP with #include stays out for
   good, and CPP without it is admitted once rhc has CPP (M20 turns the
   switch), a Hackage candidate's cabal flags read first, each cpp-options
   word as the -optP flag Cabal makes of it, so that the option rule
   refuses them. *)
structure HsFilter =
struct
  val isWhite = HsSource.isWhite
  val isWord = HsSource.isWord
  val skip = HsSource.skip

  (* D40's switch: off until M20 lands *)
  val cppAdmitted = false

  fun member x xs = List.exists (fn y => y = x) xs
  fun upper s = String.map Char.toUpper s
  fun lower s = String.map Char.toLower s
  fun trim s = HsSource.stripChars " \t\n\r\011\012\028\029\030\031\133\160" s

  (* the text with its comments, strings and character literals blanked,
     newlines kept but in a string that a newline ends: E8's strip_comments,
     which blanks a character literal where 98's did not *)
  fun stripComments t =
    let
      val n = size t
      fun at i = String.sub (t, i)
      fun starts (s, i) = i + size s <= n andalso String.substring (t, i, size s) = s
      fun blank (i, j) = CharVector.tabulate (j - i, fn k => if at (i + k) = #"\n" then #"\n" else #" ")
      fun spaces k = CharVector.tabulate (Int.max (0, k), fn _ => #" ")
      fun symbol c = Char.contains "!#$%&*+./<=>?@\\^|~:-" c
      fun alnum c = isWord c andalso c <> #"_"
      (* where a character literal from i ends, its closing quote, as E8's
         scan finds one: 'c', or a backslash and at most ten more before
         the quote on the line *)
      fun charEnd i =
        if i + 2 < n andalso (i = 0 orelse not (alnum (at (i - 1)) orelse at (i - 1) = #"_" orelse at (i - 1) = #"'"))
           andalso ((at (i + 2) = #"'" andalso at (i + 1) <> #"\\") orelse at (i + 1) = #"\\") then
          if at (i + 1) = #"\\" then
            let fun go j = if j < n andalso at j <> #"'" andalso at j <> #"\n" andalso j - i < 12 then go (j + 1) else j
                val j = go (i + 3)
            in if j >= n orelse at j <> #"'" then NONE else SOME j end
          else SOME (i + 2)
        else NONE
      fun go (i, acc) =
        if i >= n then String.concat (rev acc)
        else
          let val c = at i
          in
            if c = #"\"" then
              let fun close j = if j < n andalso at j <> #"\"" andalso at j <> #"\n" then close (if at j = #"\\" then j + 2 else j + 1) else j
                  val j = close (i + 1)
              in go (j + 1, spaces (j + 1 - i) :: acc) end
            else if c = #"'" andalso isSome (charEnd i) then
              let val j = valOf (charEnd i) in go (j + 1, spaces (j + 1 - i) :: acc) end
            else if starts ("{-", i) then
              let fun close (j, 0) = j
                    | close (j, d) = if j >= n then j
                                     else if starts ("{-", j) then close (j + 2, d + 1)
                                     else if starts ("-}", j) then close (j + 2, d - 1)
                                     else close (j + 1, d)
                  val j = Int.min (n, close (i + 2, 1))
              in go (j, blank (i, j) :: acc) end
            else if starts ("--", i) andalso (i + 2 >= n orelse not (symbol (at (i + 2))) orelse at (i + 2) = #"-") then
              let fun eol j = if j < n andalso at j <> #"\n" then eol (j + 1) else j
                  val j = eol i
              in go (j, spaces (j - i) :: acc) end
            else go (i + 1, str c :: acc)
          end
    in go (0, []) end

  (* every pragma {-# NAME ... #-} of a text, NAME letters and underscores
     ending at a word's end: its name in capitals and what follows it *)
  fun pragmas body =
    let
      val n = size body
      fun letter c = (ord c < 128 andalso Char.isAlpha c) orelse c = #"_"
      fun close i = if i + 3 > n then NONE else if String.substring (body, i, 3) = "#-}" then SOME i else close (i + 1)
      fun go (i, acc) =
        if i + 3 > n then rev acc
        else if String.substring (body, i, 3) = "{-#" then
          let val k = skip isWhite body (i + 3)
              val e = skip letter body k
          in
            if e > k andalso (e >= n orelse not (isWord (String.sub (body, e)))) then
              case close e of
                SOME c => go (c + 3, (upper (String.substring (body, k, e - k)), String.substring (body, e, c - e)) :: acc)
              | NONE => rev acc
            else go (i + 1, acc)
          end
        else go (i + 1, acc)
    in go (0, []) end

  (* a line of the text that starts with p: p at a line's start, which may
     be preceded by spaces that span lines where `spaces` says so *)
  fun anyLine p t = List.exists (fn s => p s) (HsSource.lineStarts t)
  fun wordAt t (w, i) = HsSource.word t (w, i)
  (* `w1`, spaces, `w2` from i: where w2 ends, or NONE *)
  fun pair t (w1, w2s) i =
    if i + size w1 <= size t andalso String.substring (t, i, size w1) = w1 then
      let val j = i + size w1
          val k = skip isWhite t j
      in k > j andalso List.exists (fn w => wordAt t (w, k)) w2s end
    else false

  val directives = ["if", "ifdef", "ifndef", "include", "define", "undef", "else", "elif", "endif", "error", "line"]
  (* a CPP directive at a line's start of the raw text (a literate one too,
     where unlit drops it) *)
  fun directiveOf words raw =
    anyLine (fn s => s < size raw andalso String.sub (raw, s) = #"#"
                     andalso let val i = skip isWhite raw (s + 1) in List.exists (fn w => wordAt raw (w, i)) words end) raw

  type scan = {path : string, lines : int, lhs : bool, imports : string list, boot : string list, module : string,
               ext : string list, opts : string list, pragmas : string list, cpp : bool, includes : bool,
               foreign : bool, capi : bool, ann : bool}

  (* a source as E8's scan reads it: RAW is its text, its newlines made
     Python's *)
  fun scanText (path, raw) : scan =
    let
      val lhs = String.isSuffix ".lhs" path
      val body = if lhs then HsSource.unlit raw else raw
      val code = stripComments body
      val ps = pragmas body
      val ext = HsSource.dedup (List.concat (List.map (fn (name, arg) =>
                  if name = "LANGUAGE" then List.filter (fn x => x <> "") (List.map trim (String.fields (fn c => c = #",") arg))
                  else if String.isPrefix "OPTIONS" name then
                    List.mapPartial (fn w => if String.isPrefix "-X" w then SOME (String.extract (w, 2, NONE))
                                             else if member w ["-fglasgow-exts", "-cpp", "-fth", "-ffi", "-fffi", "-farrows"] then SOME w
                                             else NONE) (String.tokens isWhite arg)
                  else []) ps))
      val opts = List.concat (List.map (fn (name, arg) => if String.isPrefix "OPTIONS" name then String.tokens isWhite arg else []) ps)
      val other = HsSource.dedup (List.mapPartial (fn (name, _) => if name = "LANGUAGE" orelse String.isPrefix "OPTIONS" name
                                                                   then NONE else SOME name) ps)
      val newlines = CharVector.foldl (fn (c, k) => if c = #"\n" then k + 1 else k) 0 raw
      val cppLines = directiveOf directives raw
      fun foreignAt words s = pair code ("foreign", words) (skip isWhite code s)
      val capi = anyLine (fn s => let val i = skip isWhite code s
                                  in pair code ("foreign", ["import"]) i
                                     andalso let val j = skip isWhite code (i + 7) val k = skip isWhite code (j + 6)
                                             in k > j + 6 andalso wordAt code ("capi", k) end end) code
    in
      {path = path, lines = newlines + (if String.isSuffix "\n" raw then 0 else 1), lhs = lhs,
       imports = HsSource.dedup (HsSource.importsOf code), boot = HsSource.bootImports body, module = HsSource.moduleOf code,
       ext = ext, opts = opts, pragmas = other, cpp = cppLines orelse member "CPP" ext orelse member "-cpp" ext,
       includes = directiveOf ["include"] raw, foreign = anyLine (foreignAt ["import", "export"]) code, capi = capi,
       ann = member "ANN" other}
    end

  fun scan path = scanText (path, HsSource.universal (Sh.read path))

  (* ---- The filter ---- *)

  val untrustedExt = ["CApiFFI", "CPP", "QuasiQuotes", "TemplateHaskell", "TemplateHaskellQuotes"]
  (* an option that names a preprocessor, a plugin or an option file *)
  fun optionWord w =
    w = "-F" orelse w = "-i"
    orelse List.exists (fn p => String.isPrefix p w) ["-pgm", "-fplugin", "-opt", "-ghci-script", "-package-env"]

  (* why a module may go to no compiler, as E8 said it (CPP, CPP#include,
     TemplateHaskell, ..., capi, option:W), under FLAGS, the words its suite
     compiles it with; none when it may. With CPP admitted, the reason CPP
     of a module that includes no file is dropped *)
  fun reasonsWith {cpp = admitted} (s : scan, flags) =
    let
      val words = #ext s @ List.mapPartial (fn w => if String.isPrefix "-X" w then SOME (String.extract (w, 2, NONE)) else NONE) flags
      val why = List.filter (fn e => member e words) untrustedExt
      val why = if member "-fth" (#ext s) orelse member "-fth" flags then why @ ["TemplateHaskell(-fth)"] else why
      val why = if (#cpp s orelse member "-cpp" flags) andalso not (member "CPP" why)
                then why @ [if #includes s then "CPP#include" else "CPP"] else why
      val why = if #capi s andalso not (member "CApiFFI" why) then why @ ["capi"] else why
      val why = case List.find optionWord (#opts s @ flags) of SOME w => why @ ["option:" ^ w] | NONE => why
    in if admitted andalso not (#includes s) then List.filter (fn r => r <> "CPP") why else why end
  fun reasons x = reasonsWith {cpp = cppAdmitted} x

  (* a candidate's reasons, every module's, sorted, E8's `untrusted` *)
  fun untrustedWith sw (ss : scan list, flags) =
    String.concatWith "," (HsSource.dedup (List.concat (List.map (fn s => reasonsWith sw (s, flags)) ss)))
  fun untrusted x = untrustedWith {cpp = cppAdmitted} x

  (* the flags a Hackage component's cabal file gives its compiles, which
     D40's B reads before CPP is admitted: every ghc-options word, and every
     cpp-options word as the -optP flag Cabal passes *)
  fun cabalFlags text =
    let
      fun indent l = skip (fn c => c = #" " orelse c = #"\t") l 0
      (* a field ghc-options or cpp-options (in any case) that the line
         starts, and what follows its colon *)
      fun fieldOf l =
        let val i = indent l
            val e = skip (fn c => isWord c orelse c = #"-") l i
            val name = lower (String.substring (l, i, e - i))
            val c = skip isWhite l e
        in if c < size l andalso String.sub (l, c) = #":" andalso (name = "ghc-options" orelse name = "cpp-options")
           then SOME (name, String.extract (l, c + 1, NONE)) else NONE end
      fun words (name, text) = List.map (fn w => if name = "cpp-options" then "-optP" ^ w else w) (String.tokens isWhite text)
      (* a field goes on over the lines indented more than its own, blank
         lines between them *)
      fun cont (k, m :: ms, more) =
            if trim m = "" then cont (k, ms, more)
            else if indent m > k then cont (k, ms, m :: more)
            else (m :: ms, more)
        | cont (_, [], more) = ([], more)
      fun go ([], acc) = List.concat (rev acc)
        | go (l :: ls, acc) =
            case fieldOf l of
              NONE => go (ls, acc)
            | SOME (name, first) =>
                let val (rest, more) = cont (indent l, ls, [])
                in go (rest, words (name, String.concatWith " " (first :: rev more)) :: acc) end
    in go (String.fields (fn c => c = #"\n") text, []) end

  (* ---- The copies compiled ---- *)

  (* each pragma {-# KEY ... #-} whose KEY (in any case, at a word's end)
     is one of LANGUAGE (when `language`), OPTIONS and its compilers'
     forms, INCLUDE and ANN, blanked to spaces, its newlines kept *)
  fun blankKeys language t =
    let
      val n = size t
      fun keyAt k =
        let fun is w = k + size w <= n andalso lower (String.substring (t, k, size w)) = w
            fun boundary e = e >= n orelse not (isWord (String.sub (t, e)))
            fun key w = is w andalso boundary (k + size w)
        in (language andalso key "language")
           orelse List.exists (fn s => key ("options" ^ s)) ["_ghc", "_hugs", "_nhc98", "_jhc", "_mhs", "_haddock", ""]
           orelse key "include" orelse key "ann" end
      fun close i = if i + 3 > n then NONE else if String.substring (t, i, 3) = "#-}" then SOME (i + 3) else close (i + 1)
      fun go (i, from, acc) =
        if i + 3 > n then String.concat (rev (String.extract (t, from, NONE) :: acc))
        else if String.substring (t, i, 3) = "{-#" andalso keyAt (skip isWhite t (i + 3)) then
          case close (skip isWhite t (i + 3)) of
            SOME e => go (e, e, CharVector.map (fn #"\n" => #"\n" | _ => #" ") (String.substring (t, i, e - i))
                                 :: String.substring (t, from, i - from) :: acc)
          | NONE => String.concat (rev (String.extract (t, from, NONE) :: acc))
        else go (i + 1, from, acc)
    in go (0, 0, []) end
  (* the 2010 variant: the program must be Haskell 2010 without them *)
  fun blankPragmas t = blankKeys true t
  (* the extension variant: LANGUAGE kept *)
  fun blankOptions t = blankKeys false t

  (* the names RebindableSyntax reads *)
  val syntaxNames = ["fromInteger", "fromRational", "negate", ">>=", ">>", "fail", "ifThenElse", "=="]

  (* each explicit import of the Prelude in code, as E8's pattern finds it:
     qualified or not, and what follows the name, `as M` dropped: hiding,
     a list, or all *)
  fun preludeImports code =
    let
      val n = size code
      fun at i = String.sub (code, i)
      fun eol i = skip (fn c => c <> #"\n") code i
      fun one s =
        let
          val i = skip isWhite code s
          val g1 = String.substring (code, s, i - s)
          fun ws j = let val k = skip isWhite code j in if k > j then SOME k else NONE end
        in
          if not (i + 6 <= n andalso String.substring (code, i, 6) = "import") then NONE
          else case ws (i + 6) of
                 NONE => NONE
               | SOME k =>
                   let
                     val (q, k) = if k + 9 <= n andalso String.substring (code, k, 9) = "qualified"
                                     andalso isSome (ws (k + 9))
                                     andalso valOf (ws (k + 9)) + 7 <= n
                                     andalso String.substring (code, valOf (ws (k + 9)), 7) = "Prelude"
                                  then (true, valOf (ws (k + 9))) else (false, k)
                   in
                     if k + 7 <= n andalso String.substring (code, k, 7) = "Prelude"
                        andalso (k + 7 >= n orelse not (isWord (at (k + 7)))) then
                       let
                         (* the rest: the line, then each line after that
                            starts with the first line's indentation and a
                            space, the spaces greedy across lines *)
                         fun more p =
                           if p < n andalso at p = #"\n" andalso p + 1 + size g1 <= n
                              andalso String.substring (code, p + 1, size g1) = g1 then
                             case ws (p + 1 + size g1) of SOME q => more (eol q) | NONE => p
                           else p
                         val stop = more (eol (k + 7))
                       in SOME ({qualified = q, rest = String.substring (code, k + 7, stop - (k + 7))}, stop) end
                     else NONE
                   end
        end
      fun go ([], _, acc) = rev acc
        | go (s :: ss, from, acc) = if s < from then go (ss, from, acc)
                                    else case one s of SOME (m, stop) => go (ss, stop, m :: acc) | NONE => go (ss, from, acc)
      fun dropAs r =
        let val i = skip isWhite r 0
        in if i > 0 andalso i + 2 <= size r andalso String.substring (r, i, 2) = "as" then
             let val j = skip isWhite r (i + 2)
             in if j > i + 2 andalso j < size r andalso Char.isUpper (String.sub (r, j)) andalso ord (String.sub (r, j)) < 128
                then dropAs (" " ^ String.extract (r, skip (fn c => isWord c orelse c = #".") r (j + 1), NONE))
                else r end
           else r end
      fun kind r =
        let val r = dropAs r
            val i = skip isWhite r 0
        in if wordAt r ("hiding", i) then "hiding" else if i < size r andalso String.sub (r, i) = #"(" then "list" else "all" end
    in List.map (fn {qualified, rest} => (qualified, kind rest)) (go (HsSource.lineStarts code, 0, [])) end

  (* whether g10's copy of a module needs `import RebindableH2010`: it
     imports the Prelude explicitly, and no unqualified import brings all
     of it (an import list, or qualified only) *)
  fun needsRebind code =
    let val ps = preludeImports code
    in not (null ps) andalso not (List.exists (fn (q, k) => not q andalso (k = "all" orelse k = "hiding")) ps) end

  (* `import RebindableH2010` before the text's first import, with a
     semicolon where the imports are in braces *)
  fun inject t =
    let
      val n = size t
      fun at s =
        let val i = if s < n andalso String.sub (t, s) = #">" then s + 1 else s
            val i = skip (fn c => c = #" " orelse c = #"\t") t i
        in if i + 6 <= n andalso String.substring (t, i, 6) = "import" andalso i + 6 < n andalso isWhite (String.sub (t, i + 6))
           then SOME (String.substring (t, s, i - s)) else NONE end
    in
      case List.find (fn s => isSome (at s)) (HsSource.lineStarts t) of
        NONE => t
      | SOME s =>
          let
            val le = case CharVector.findi (fn (i, c) => i >= s andalso c = #"\n") t of SOME (i, _) => i | NONE => n - 1
            val line = trim (String.substring (t, s, Int.max (0, le - s)))
            val front = trim (String.substring (t, 0, s))
            val semi = String.isSuffix ";" line orelse String.isSuffix "{" front
          in String.substring (t, 0, s) ^ valOf (at s) ^ "import RebindableH2010" ^ (if semi then ";" else "") ^ "\n"
             ^ String.extract (t, s, NONE) end
    end
end

(* What a Haskell source says about itself, without parsing it, and the
   rewrites that make a corpus program Haskell 98 (tests/hs/corpus/README.md):
   the literate form, comments, imports, the module's name, pragmas and the
   preprocessor, the import rewrite and the compat layer's imports. Each is
   the one E8 judged the corpus with (the drafts' results/E8/scan.py and
   judge.py), character for character, so that the harness reproduces its
   verdicts; where that one is rough (a string is blanked with the comments,
   an import list is read to its last parenthesis) this is rough the same
   way. *)
structure HsSource =
struct
  (* a character of a regular expression's \w, on text read as Latin-1:
     letters, digits and numbers, and the underscore *)
  fun isWord c =
    Char.isAlphaNum c orelse c = #"_"
    orelse (let val k = ord c
            in List.exists (fn x => x = k) [0xaa, 0xb2, 0xb3, 0xb5, 0xb9, 0xba, 0xbc, 0xbd, 0xbe]
               orelse (k >= 0xc0 andalso k <> 0xd7 andalso k <> 0xf7 andalso k <= 0xff) end)
  (* a space of a regular expression's \s, and of Python's str.split, on
     text read as Latin-1 *)
  fun isWhite c = Char.isSpace c orelse (ord c >= 0x1c andalso ord c <= 0x1f) orelse ord c = 0x85 orelse ord c = 0xa0

  (* the end of a run of characters that satisfy p from i *)
  fun skip p t i = if i < size t andalso p (String.sub (t, i)) then skip p t (i + 1) else i

  (* s without the characters of cs at either end *)
  fun stripChars cs s =
    let val l = skip (fn c => Char.contains cs c) s 0
        fun r k = if k > l andalso Char.contains cs (String.sub (s, k - 1)) then r (k - 1) else k
    in String.substring (s, l, r (size s) - l) end

  (* text as Python reads it: each \r\n and each \r a \n *)
  fun universal t =
    if not (CharVector.exists (fn c => c = #"\r") t) then t
    else
      let
        val n = size t
        fun go (i, acc) =
          if i >= n then String.implode (rev acc)
          else if String.sub (t, i) = #"\r" then
            go (if i + 1 < n andalso String.sub (t, i + 1) = #"\n" then i + 2 else i + 1, #"\n" :: acc)
          else go (i + 1, String.sub (t, i) :: acc)
      in go (0, []) end

  fun lines t = String.fields (fn c => c = #"\n") t
  fun unlines ls = String.concatWith "\n" ls

  (* the code of a literate source: \begin{code} blocks where there are
     any, otherwise the lines after a bird track, each with its track a
     space; every other line empty *)
  fun unlit t =
    if String.isSubstring "\\begin{code}" t then
      let
        fun go (_, [], acc) = rev acc
          | go (on, l :: ls, acc) =
              if String.isPrefix "\\begin{code}" l then go (true, ls, "" :: acc)
              else if String.isPrefix "\\end{code}" l then go (false, ls, "" :: acc)
              else if on then go (on, ls, l :: acc)
              else if String.isPrefix ">" l then go (on, ls, (" " ^ String.extract (l, 1, NONE)) :: acc)
              else go (on, ls, "" :: acc)
      in unlines (go (false, lines t, [])) end
    else unlines (List.map (fn l => if String.isPrefix ">" l then " " ^ String.extract (l, 1, NONE) else "") (lines t))

  (* the text with its comments and strings blanked, newlines kept but in a
     string that a newline ends *)
  fun stripComments t =
    let
      val n = size t
      fun at i = String.sub (t, i)
      fun starts (s, i) = i + size s <= n andalso String.substring (t, i, size s) = s
      fun blank (i, j) = CharVector.tabulate (j - i, fn k => if at (i + k) = #"\n" then #"\n" else #" ")
      fun spaces k = CharVector.tabulate (k, fn _ => #" ")
      fun symbol c = Char.contains "!#$%&*+./<=>?@\\^|~:-" c
      fun go (i, acc) =
        if i >= n then String.concat (rev acc)
        else
          let val c = at i
          in
            if c = #"\"" then
              let fun close j = if j < n andalso at j <> #"\"" andalso at j <> #"\n" then close (if at j = #"\\" then j + 2 else j + 1) else j
                  val j = close (i + 1)
              in go (j + 1, spaces (j + 1 - i) :: acc) end
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

  (* where a line starts: 0, and after each newline *)
  fun lineStarts t =
    0 :: List.mapPartial (fn i => if String.sub (t, i) = #"\n" then SOME (i + 1) else NONE) (List.tabulate (size t, fn i => i))

  fun word t (w, i) = i + size w <= size t andalso String.substring (t, i, size w) = w
                      andalso (i + size w = size t orelse not (isWord (String.sub (t, i + size w))))
  fun modid t i =
    if i < size t andalso Char.isUpper (String.sub (t, i)) andalso ord (String.sub (t, i)) < 128
    then SOME (skip (fn c => isWord c orelse c = #"." orelse c = #"'") t (i + 1)) else NONE
  fun modidNoQuote t i =
    if i < size t andalso Char.isUpper (String.sub (t, i)) andalso ord (String.sub (t, i)) < 128
    then SOME (skip (fn c => isWord c orelse c = #".") t (i + 1)) else NONE

  (* `import` after spaces from a line's start (spaces that may span lines,
     as the expression's \s* does), then spaces, then `safe`, `qualified`
     and a package as the pattern allows, then a module's name: the place
     after `import`'s spaces where the name starts, its end, and where the
     match started *)
  fun importAt {bird, safe, quote, package} t start =
    let
      val n = size t
      val i = if bird andalso start < n andalso String.sub (t, start) = #">" then start + 1 else start
      fun ws i = skip isWhite t i
      val i = ws i
    in
      if not (i + 6 <= n andalso String.substring (t, i, 6) = "import") then NONE
      else
        let
          val j = i + 6
          val k = ws j
        in
          if k = j then NONE
          else
            let
              fun opt (w, k) = if word t (w, k) then let val e = ws (k + size w) in if e > k + size w then e else k end else k
              val k = if safe then opt ("safe", k) else k
              val k = opt ("qualified", k)
              val k = if package andalso k < n andalso String.sub (t, k) = #"\"" then
                        let val e = skip (fn c => c <> #"\"" andalso c <> #"\n") t (k + 1)
                        in if e < n andalso String.sub (t, e) = #"\"" then
                             let val f = ws (e + 1) in if f > e + 1 then f else k end
                           else k end
                      else k
            in
              case (if quote then modid else modidNoQuote) t k of
                SOME e => SOME {head = start, name = k, stop = e, mstop = e}
              | NONE => NONE
            end
        end
    end

  (* a match: where it starts, where the name it is about starts and ends,
     and where it ends *)
  type match = {head : int, name : int, mstop : int, stop : int}

  (* every match of a pattern anchored at a line's start, left to right and
     not overlapping, as re.finditer finds them *)
  fun matches (f : string -> int -> match option) t =
    let
      val starts = lineStarts t
      fun go ([], _, acc) = rev acc
        | go (s :: ss, from, acc) =
            if s < from then go (ss, from, acc)
            else case f t s of
                   SOME (m : match) => go (ss, #stop m, m :: acc)
                 | NONE => go (ss, from, acc)
    in go (starts, 0, []) end

  fun importsOf code =
    List.map (fn {name, stop, ...} => String.substring (code, name, stop - name))
      (matches (importAt {bird = false, safe = true, quote = true, package = true}) code)

  fun dedup xs = Sh.sort (List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else x :: acc) [] xs)

  (* the modules a {-# SOURCE #-} import names *)
  fun bootImports body =
    let
      val n = size body
      fun ws i = skip isWhite body i
      fun at i = if i + 6 <= n andalso String.substring (body, i, 6) = "import" then
                   let val j = ws (i + 6) in
                     if j > i + 6 andalso j + 3 <= n andalso String.substring (body, j, 3) = "{-#" then
                       let val k = ws (j + 3) in
                         if word body ("SOURCE", k) orelse (k + 6 <= n andalso String.substring (body, k, 6) = "SOURCE") then
                           let val l = ws (k + 6) in
                             if l + 3 <= n andalso String.substring (body, l, 3) = "#-}" then
                               let val m = ws (l + 3)
                                   val m = if word body ("qualified", m) then let val e = ws (m + 9) in if e > m + 9 then e else m end else m
                               in case modidNoQuote body m of SOME e => SOME (String.substring (body, m, e - m)) | NONE => NONE end
                             else NONE end
                         else NONE end
                     else NONE end
                 else NONE
      fun go (i, acc) = if i >= n then rev acc else case at i of SOME m => go (i + 1, m :: acc) | NONE => go (i + 1, acc)
    in dedup (go (0, [])) end

  (* the name a module declares, or Main *)
  fun moduleOf code =
    case matches (fn t => fn s =>
                    let val i = skip isWhite t s in
                      if word t ("module", i) then
                        let val j = skip isWhite t (i + 6) in
                          if j > i + 6 then case modid t j of SOME e => SOME {head = s, name = j, mstop = e, stop = e} | NONE => NONE
                          else NONE end
                      else NONE end) code of
      {name, stop, ...} :: _ => String.substring (code, name, stop - name)
    | [] => "Main"

  fun lower s = String.map Char.toLower s
  (* the pragmas {-# KEY ... #-} of a text: each key and its body *)
  fun pragmas t =
    let
      val n = size t
      fun close i = if i + 3 > n then NONE else if String.substring (t, i, 3) = "#-}" then SOME i else close (i + 1)
      fun go (i, acc) =
        if i + 3 > n then rev acc
        else if String.substring (t, i, 3) = "{-#" then
          let val k = skip isWhite t (i + 3)
              val e = skip isWord t k
          in case close e of
               SOME c => go (c + 3, {start = i, stop = c + 3, key = String.substring (t, k, e - k),
                                     body = String.substring (t, e, c - e)} :: acc)
             | NONE => rev acc
          end
        else go (i + 1, acc)
    in go (0, []) end

  (* the extensions a source asks for: LANGUAGE pragmas, and -X words,
     -fglasgow-exts and -cpp of OPTIONS and OPTIONS_GHC *)
  fun extensions body =
    dedup (List.concat (List.map (fn {key, body = b, ...} =>
      if lower key = "language" andalso size b > 0 andalso isWhite (String.sub (b, 0))
         andalso not (CharVector.exists (fn c => c = #"#") b) then
        List.filter (fn x => x <> "") (List.map (stripChars " \t\n\r\f\v") (String.fields (fn c => c = #",") b))
      else if (lower key = "options" orelse lower key = "options_ghc") andalso size b > 0 andalso isWhite (String.sub (b, 0))
              andalso not (CharVector.exists (fn c => c = #"#") b) then
        List.mapPartial (fn w => if String.isPrefix "-X" w then SOME (String.extract (w, 2, NONE))
                                 else if w = "-fglasgow-exts" orelse w = "-cpp" then SOME w else NONE)
          (String.tokens isWhite b)
      else []) (pragmas body)))

  (* a line `#if`, `#ifdef`, `#ifndef`, `#include`, `#define`, `#else` or
     `#endif` *)
  fun directive t =
    List.exists (fn s =>
      s < size t andalso String.sub (t, s) = #"#" andalso
      let val i = skip isWhite t (s + 1)
      in List.exists (fn w => word t (w, i)) ["if", "ifdef", "ifndef", "include", "define", "else", "endif"] end)
      (lineStarts t)

  type scan = {lines : int, lhs : bool, imports : string list, boot : string list, module : string,
               ext : string list, cpp : bool}

  fun scanText (path, raw) =
    let
      val lhs = String.isSuffix ".lhs" path
      val body = if lhs then unlit raw else raw
      val code = stripComments body
      val ext = extensions body
      val newlines = CharVector.foldl (fn (c, k) => if c = #"\n" then k + 1 else k) 0 raw
    in
      {lines = newlines + (if String.isSuffix "\n" raw then 0 else 1), lhs = lhs, imports = dedup (importsOf code),
       boot = bootImports body, module = moduleOf code, ext = ext,
       cpp = directive body orelse List.exists (fn e => e = "CPP" orelse e = "-cpp") ext}
    end

  (* the Report's modules, and what a hierarchical name of each becomes *)
  val report = ["Prelude", "Char", "List", "Monad", "Maybe", "Ratio", "Complex", "Numeric", "Ix", "Array", "IO", "Locale",
                "Time", "CPUTime", "Random", "System", "Directory"]
  val rewrites =
    [("Data.List", "List"), ("Data.Char", "Char"), ("Data.Maybe", "Maybe"), ("Control.Monad", "Monad"), ("Data.Array", "Array"),
     ("Data.Ratio", "Ratio"), ("Data.Complex", "Complex"), ("System.IO", "IO"), ("System.IO.Error", "IO"),
     ("System.Environment", "System"), ("System.Exit", "System"), ("System.CPUTime", "CPUTime"), ("Data.Ix", "Ix"),
     ("System.Random", "Random"), ("System.Time", "Time"), ("System.Locale", "Locale"), ("System.Directory", "Directory"),
     ("System.Cmd", "System"), ("System.Process", "System")]
  fun rewriteOf m = Option.map #2 (List.find (fn (h, _) => h = m) rewrites)

  (* the text with each pragma LANGUAGE or OPTIONS (of GHC, nhc98 or Hugs, in
     any case) blanked to spaces, its newlines kept *)
  fun blankPragmas t =
    let
      val n = size t
      fun keyAt k =
        let fun is w = k + size w <= n andalso lower (String.substring (t, k, size w)) = w
            fun boundary e = e >= n orelse not (isWord (String.sub (t, e)))
        in if is "language" andalso boundary (k + 8) then true
           else if is "options" then
             List.exists (fn s => is ("options" ^ s) andalso boundary (k + 7 + size s)) ["_ghc", "_nhc98", "_hugs"]
             orelse boundary (k + 7)
           else false end
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

  (* whether a source wants the preprocessor, as the corpus's copy is
     judged: a directive, CPP in a LANGUAGE pragma or -cpp in an OPTIONS
     one, before any # of the pragma *)
  fun wantsCpp t =
    let
      val n = size t
      fun upto k = String.substring (t, k, skip (fn c => c <> #"#") t k - k)
      fun cppWord s = List.exists (fn w => w = "CPP") (String.tokens (fn c => not (isWord c)) s)
      fun at i =
        let val k = skip isWhite t (i + 3)
            fun is w = k + size w <= n andalso String.substring (t, k, size w) = w
        in (is "LANGUAGE" andalso cppWord (upto (k + 8))) orelse (is "OPTIONS" andalso String.isSubstring "-cpp" (upto (k + 7))) end
      fun go i = i + 3 <= n andalso ((String.substring (t, i, 3) = "{-#" andalso at i) orelse go (i + 1))
    in directive t orelse go 0 end

  (* re.sub of a pattern anchored at a line's start, `f` the match's
     replacement *)
  fun substitute pattern (f : match -> string) t =
    let
      val ms = matches pattern t
      fun go ([], from, acc) = String.concat (rev (String.extract (t, from, NONE) :: acc))
        | go ((m : match) :: rest, from, acc) =
            go (rest, #stop m, f m :: String.substring (t, from, #head m - from) :: acc)
    in go (ms, 0, []) end

  fun eol t i = skip (fn c => c <> #"\n") t i

  (* the import rewrite: an import of a hierarchical name of a Report module
     imports the Report's, and a qualified one keeps its name with `as` *)
  fun rewriteImports t =
    substitute (fn t => fn s =>
                  case importAt {bird = true, safe = true, quote = false, package = false} t s of
                    SOME {head, name, stop, ...} => SOME {head = head, name = name, stop = eol t stop, mstop = stop}
                  | NONE => NONE)
      (fn {head, name, stop, mstop} =>
         let
           val h = String.substring (t, head, name - head)
           val m = String.substring (t, name, mstop - name)
           val rest = String.substring (t, mstop, stop - mstop)
         in
           case rewriteOf m of
             NONE => String.substring (t, head, stop - head)
           | SOME new =>
               let val r = skip isWhite rest 0
                   val asNamed = r > 0 andalso word rest ("as", r)
               in if String.isSubstring "qualified" h andalso not asNamed then h ^ new ^ " as " ^ m ^ rest
                  else h ^ new ^ rest end
         end) t

  (* what the 2019 nofib's harness takes from outside the Report, which
     compat/NofibCompat.hs defines, and the modules that held only those *)
  val harnessNames = ["<$>", "pure", "forM_", "forM", "replicateM_", "replicateM", "foldl'", "void", "evaluate",
                      "hSetBinaryMode", "hSetEncoding", "utf8", "latin1", "catchIOError", "IOException"]
  val dropImports = ["Control.Exception", "Control.Exception.Base", "Data.Functor", "Control.Applicative"]

  (* an occurrence of `w` in `t` that no name character or dot comes
     before and no name character after *)
  fun occurs (t, w) =
    let
      val n = size t
      fun nameChar c = isWord c orelse c = #"'"
      fun go i =
        i + size w <= n andalso
        ((String.substring (t, i, size w) = w
          andalso (i = 0 orelse (let val c = String.sub (t, i - 1) in not (nameChar c orelse c = #".") end))
          andalso (i + size w = n orelse not (nameChar (String.sub (t, i + size w)))))
         orelse go (i + 1))
    in go 0 end

  (* a line that defines `w` at its start: `w` and then a space *)
  fun definedAtStart (t, w) =
    List.exists (fn s => s + size w < size t andalso String.substring (t, s, size w) = w
                         andalso isWhite (String.sub (t, s + size w))) (lineStarts t)

  fun birdBody t = unlines (List.map (fn l => if String.isPrefix ">" l then " " ^ String.extract (l, 1, NONE) else "") (lines t))

  (* the compat layer's rewrite of a 2019 nofib source: the harness's names
     leave its import lists and come from NofibCompat, the modules that held
     only them go, the import rewrite, and NofibCompat imported where the
     file uses one *)
  fun harnessText (t, path) =
    let
      val lhs = String.isSuffix ".lhs" path
      val t =
        substitute (fn t => fn s =>
                      case importAt {bird = true, safe = false, quote = false, package = false} t s of
                        SOME {head, name, stop, ...} => SOME {head = head, name = name, stop = eol t stop, mstop = stop}
                      | NONE => NONE)
          (fn {head, name, stop, mstop} =>
             let
               val h = String.substring (t, head, name - head)
               val m = String.substring (t, name, mstop - name)
               val rest = String.substring (t, mstop, stop - mstop)
               val track = if String.isPrefix ">" h then ">" else ""
               val whole = String.substring (t, head, stop - head)
             in
               if List.exists (fn d => d = m) dropImports then track
               else
                 let val r = skip isWhite rest 0
                     fun lastClose k = if k <= r then NONE else if String.sub (rest, k - 1) = #")" then SOME (k - 1) else lastClose (k - 1)
                 in
                   if r < size rest andalso String.sub (rest, r) = #"(" andalso isSome (rewriteOf m) then
                     case lastClose (size rest) of
                       NONE => whole
                     | SOME c =>
                         let
                           val inside = String.substring (rest, r + 1, c - r - 1)
                           val after = String.extract (rest, c + 1, NONE)
                           val items = List.filter (fn i => i <> "") (List.map (stripChars " \t\n\r\f\v") (String.fields (fn ch => ch = #",") inside))
                           val keep = List.filter (fn i => not (List.exists (fn n => n = stripChars "() " i) harnessNames)) items
                         in
                           if length keep = length items then whole
                           else if null keep then track
                           else h ^ m ^ " (" ^ String.concatWith ", " keep ^ ")" ^ after
                         end
                   else whole
                 end
             end) t
      val t = rewriteImports t
      (* `module M` in an export list: the rewrite's name, after one space *)
      val t =
        let
          val n = size t
          fun go (i, from, acc) =
            if i + 6 > n then String.concat (rev (String.extract (t, from, NONE) :: acc))
            else if String.substring (t, i, 6) = "module" andalso (i = 0 orelse not (isWord (String.sub (t, i - 1)))) then
              let val j = skip isWhite t (i + 6) in
                if j > i + 6 then
                  case modidNoQuote t j of
                    SOME e =>
                      let val k = skip isWhite t e in
                        if k < n andalso (String.sub (t, k) = #"," orelse String.sub (t, k) = #")") then
                          let val m = String.substring (t, j, e - j)
                          in go (e, e, ("module " ^ getOpt (rewriteOf m, m)) :: String.substring (t, from, i - from) :: acc) end
                        else go (i + 1, from, acc) end
                  | NONE => go (i + 1, from, acc)
                else go (i + 1, from, acc) end
            else go (i + 1, from, acc)
        in go (0, 0, []) end
      val body = if lhs then unlit t else t
      val body = if lhs andalso List.exists (fn s => s + 2 <= size t andalso String.substring (t, s, 2) = "> ") (lineStarts t)
                 then birdBody t else body
      val code = stripComments body
      val used = List.filter (fn n => (if n = "<$>" then String.isSubstring "<$>" code else occurs (code, n))
                                      andalso not (definedAtStart (code, n))) harnessNames
    in
      if null used then t
      else
        let
          val items = String.concatWith ", " (List.map (fn n => if n = "<$>" then "(<$>)" else n) used)
          fun line (p, s) = p ^ "import NofibCompat (" ^ items ^ ")" ^ s ^ "\n"
          (* the first `import` at a line's start, after a track and blanks *)
          val first = List.find (fn s =>
                         let val i = if s < size t andalso String.sub (t, s) = #">" then s + 1 else s
                             val j = skip (fn c => c = #" " orelse c = #"\t") t i
                         in j + 7 <= size t andalso String.substring (t, j, 6) = "import" andalso isWhite (String.sub (t, j + 6)) end)
                       (lineStarts t)
        in
          case first of
            SOME ls =>
              let
                val i = if String.sub (t, ls) = #">" then ls + 1 else ls
                val j = skip (fn c => c = #" " orelse c = #"\t") t i
                val prefix = String.substring (t, ls, j - ls)
                (* t[ls:le] with Python's -1 for no newline *)
                val le = case CharVector.findi (fn (k, c) => k >= ls andalso c = #"\n") t of SOME (k, _) => k | NONE => size t - 1
                val semi = if String.isSuffix ";" (stripChars " \t\n\r\f\v" (String.substring (t, ls, Int.max (0, le - ls)))) then ";" else ""
              in String.substring (t, 0, ls) ^ line (prefix, semi) ^ String.extract (t, ls, NONE) end
          | NONE =>
              let
                (* `module` at a line's start after blanks, then the first
                   word `where` after it, then blanks and an open brace *)
                val header =
                  List.foldl (fn (s, SOME x) => SOME x
                               | (s, NONE) =>
                                   let val i = skip isWhite code s in
                                     if word code ("module", i) then
                                       let
                                         val n = size code
                                         fun find k = if k + 5 > n then NONE
                                                      else if String.substring (code, k, 5) = "where" andalso not (isWord (String.sub (code, k - 1)))
                                                              andalso (k + 5 = n orelse not (isWord (String.sub (code, k + 5)))) then SOME k
                                                      else find (k + 1)
                                       in case find (i + 6) of
                                            SOME w => let val e = skip (fn c => c = #" " orelse c = #"\t") code (w + 5)
                                                          val brace = e < n andalso String.sub (code, e) = #"{"
                                                      in SOME (if brace then e + 1 else e, brace) end
                                          | NONE => NONE
                                       end
                                     else NONE end) NONE (lineStarts code)
              in
                case header of
                  SOME (e, brace) => if lhs then line ("> ", "") ^ t
                                     else String.substring (t, 0, e) ^ "\n" ^ line ("", if brace then ";" else "") ^ String.extract (t, e, NONE)
                | NONE => if lhs then line ("> ", "") ^ t else line ("", "") ^ t
              end
        end
    end
end

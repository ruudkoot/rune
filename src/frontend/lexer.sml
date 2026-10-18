(* Hand-written lexer for Standard ML '97. Produces a vector of tokens so the
   parser can backtrack cheaply. *)
structure Lexer =
struct
  open Token

  type item = token * Source.span

  (* Whether each character is symbolic, by its code: a lookup for every
     character of an identifier, where Char.contains would scan the string
     and build a closure. *)
  val symbolicTable = Vector.tabulate (256, fn i => Char.contains "!%&$#+-/:<=>?@\\~`^|*" (Char.chr i))
  fun isSymbolic c = Vector.sub (symbolicTable, Char.ord c)
  fun isIdentStart c = Char.isAlpha c
  fun isIdentChar c = Char.isAlphaNum c orelse c = #"'" orelse c = #"_"
  fun isHex c = Char.isHexDigit c

  (* The reserved words by their first character, so that an identifier is
     compared with the few that begin as it does. *)
  fun buckets (words : (string * token) list) : (string * token) list vector =
    let
      val a = Array.array (256, [] : (string * token) list)
      fun add (w as (s, _)) =
        let val i = Char.ord (String.sub (s, 0)) in Array.update (a, i, Array.sub (a, i) @ [w]) end
    in
      List.app add words;
      (* A workaround for a bug of MLton 20241230, which miscompiles the
         code this was meant to be
         (docs/bugreport/mlton/SplitTypes/BUGREPORT.md):

             List.app add words; Array.vector a

         MLton's optimiser gives the array and the vector made from it two
         different types of list, so the copy in Array.vector is ill typed:
         `mlton -type-check true` fails in its SSA, and a build without
         the check stops at run time with "control shouldn't reach here".
         An array of lists of pairs that come from another list is what it
         takes; Vector.tabulate does not copy an array and is not
         affected.

         What it costs: on runevm-stack, 3,819 instructions more for every
         compile, 0.06% of compiling examples/hello.sml (and 1,544 fewer
         objects); in the host builds, 256 calls in place of one copy, once
         a run. MLton has fixed the bug after 20241230 (its pull request
         #632); this can go once `make hosts` installs a release with the
         fix. *)
      Vector.tabulate (256, fn i => Array.sub (a, i))
    end
  val reservedBuckets = buckets reserved
  val reservedSymbolicBuckets = buckets reservedSymbolic

  fun lookupReserved (s, tbl) =
    let
      fun go [] = NONE
        | go ((k, t) :: rest) = if k = s then SOME t else go rest
    in
      if s = "" then NONE else go (Vector.sub (tbl, Char.ord (String.sub (s, 0))))
    end

  fun hexVal c =
    if Char.isDigit c then Char.ord c - Char.ord #"0"
    else Char.ord (Char.toLower c) - Char.ord #"a" + 10

  (* A character by its code point, as Unicode writes it: U+03BB. *)
  fun codePoint c = "U+" ^ StringCvt.padLeft #"0" 4 (Int.fmt StringCvt.HEX c)

  (* The lexer of a text: the token at an index, with its span and the index
     after it (whitespace and comments before it skipped), and the index
     after a comment that begins at an index. Both raise Error.CompileError
     where the text is not SML. tokenize reads a file with it, and scan a
     line to colour. *)
  fun lexerOf (name : string, text : string) : {next : int -> token * Source.span * int, skipComment : int -> int} =
    let
      val n = String.size text
      fun span (a, b) : Source.span = {file = name, start = a, stop = b}
      fun err (a, b, msg) = Error.error (span (a, b), msg)
      fun ch i = if i < n then String.sub (text, i) else #"\000"
      fun at i = i < n

      (* The index after the comment that starts at start. The loop has one
         argument and keeps the depth outside it: a tuple of arguments would
         be allocated once per character. *)
      fun skipComment start =
        let
          val depth = ref 1
          fun go i =
            if i >= n then err (start, start + 2, "unterminated comment")
            else
              let val c = String.sub (text, i)
              in
                if c = #"(" andalso ch (i + 1) = #"*" then (depth := !depth + 1; go (i + 2))
                else if c = #"*" andalso ch (i + 1) = #")" then
                  (depth := !depth - 1; if !depth = 0 then i + 2 else go (i + 2))
                else go (i + 1)
              end
        in
          go (start + 2)
        end

      fun digitsWhile (i, p) = if at i andalso p (ch i) then digitsWhile (i + 1, p) else i

      (* Explicit IntInf operations: the hosts that compile this file type an
         integer constant as IntInf.int, Rune as well, but only once lib/basis
         registers IntInf; the sources must not depend on it. *)
      fun parseInt (s, radix : int) : IntInf.int =
        let
          val r = IntInf.fromInt radix
          fun go (i, acc) =
            if i >= String.size s then acc
            else go (i + 1, IntInf.+ (IntInf.* (acc, r), IntInf.fromInt (hexVal (String.sub (s, i)))))
        in go (0, IntInf.fromInt 0) end

      (* Lex a numeric literal starting at i (after an optional ~ at negStart). *)
      fun lexNumber (start, i, neg) =
        let
          fun finishInt (j, v) =
            (INT (if neg then IntInf.~ v else v), span (start, j), j)
        in
          if ch i = #"0" andalso ch (i + 1) = #"w" andalso not neg
             andalso (Char.isDigit (ch (i + 2)) orelse (ch (i + 2) = #"x" andalso isHex (ch (i + 3)))) then
            (if ch (i + 2) = #"x" then
               let val j = digitsWhile (i + 3, isHex)
               in (WORD (parseInt (String.substring (text, i + 3, j - i - 3), 16)), span (start, j), j) end
             else
               let val j = digitsWhile (i + 2, Char.isDigit)
               in (WORD (parseInt (String.substring (text, i + 2, j - i - 2), 10)), span (start, j), j) end)
          else if ch i = #"0" andalso ch (i + 1) = #"x" andalso isHex (ch (i + 2)) then
            let val j = digitsWhile (i + 2, isHex)
            in finishInt (j, parseInt (String.substring (text, i + 2, j - i - 2), 16)) end
          else
            let
              val j = digitsWhile (i, Char.isDigit)
              val isReal = (ch j = #"." andalso Char.isDigit (ch (j + 1)))
                           orelse ((ch j = #"e" orelse ch j = #"E")
                                   andalso (Char.isDigit (ch (j + 1))
                                            orelse (ch (j + 1) = #"~" andalso Char.isDigit (ch (j + 2)))))
            in
              if isReal then
                let
                  val j1 = if ch j = #"." then digitsWhile (j + 1, Char.isDigit) else j
                  val j2 =
                    if (ch j1 = #"e" orelse ch j1 = #"E") then
                      let val k = if ch (j1 + 1) = #"~" then j1 + 2 else j1 + 1
                      in if Char.isDigit (ch k) then digitsWhile (k, Char.isDigit) else j1 end
                    else j1
                in (REAL (String.substring (text, start, j2 - start)), span (start, j2), j2) end
              else finishInt (j, parseInt (String.substring (text, i, j - i), 10))
            end
        end

      (* Lex the body of a string literal starting after the opening quote.
         Returns (chars, index after closing quote). *)
      fun lexStringBody (start, i, acc) =
        if i >= n orelse ch i = #"\n" then err (start, i, "unterminated string literal")
        else
          case ch i of
            #"\"" => (List.rev acc, i + 1)
          | #"\\" => lexEscape (start, i + 1, acc)
          (* the Definition's printable characters are 33 to 126 and space
             (Section 2.2): a control, DEL among them, is written as its
             escape *)
          | c => if Char.ord c < 32 orelse Char.ord c = 127 then
                   err (i, i + 1, "control character " ^ codePoint (Char.ord c) ^ " in string literal (write it as "
                                  ^ Char.toString c ^ ")")
                 else lexStringBody (start, i + 1, Char.ord c :: acc)
      and lexEscape (start, i, acc) =
        let fun cont c = lexStringBody (start, i + 1, Char.ord c :: acc)
        in
          case ch i of
            #"a" => cont #"\a" | #"b" => cont #"\b" | #"t" => cont #"\t"
          | #"n" => cont #"\n" | #"v" => cont #"\v" | #"f" => cont #"\f"
          | #"r" => cont #"\r" | #"\\" => cont #"\\" | #"\"" => cont #"\""
          | #"^" =>
            let val c = ch (i + 1)
            in if Char.ord c >= 64 andalso Char.ord c <= 95 then
                 lexStringBody (start, i + 2, Char.ord c - 64 :: acc)
               else err (i - 1, i + 2, "invalid control escape in string literal")
            end
          (* A code point, which only a wide character or string can hold
             above 255 (elaboration decides, with the type). *)
          | #"u" =>
            if isHex (ch (i + 1)) andalso isHex (ch (i + 2)) andalso isHex (ch (i + 3)) andalso isHex (ch (i + 4)) then
              lexStringBody (start, i + 5, IntInf.toInt (parseInt (String.substring (text, i + 1, 4), 16)) :: acc)
            else err (i - 1, i + 1, "invalid \\u escape")
          | #"U" =>
            if List.all (fn k => isHex (ch (i + k))) [1, 2, 3, 4, 5, 6, 7, 8] then
              let val v = IntInf.toInt (parseInt (String.substring (text, i + 1, 8), 16))
              in if v > 1114111 then err (i - 1, i + 9, "\\U escape out of range (the largest code point is 0x10FFFF)")
                 else lexStringBody (start, i + 9, v :: acc)
              end
            else err (i - 1, i + 1, "invalid \\U escape")
          (* \ddd is the character with that code, up to 999 (Section 2.2):
             above 255 only a wide character or string can hold it, as
             with \u *)
          | c =>
            if Char.isDigit c then
              (if Char.isDigit (ch (i + 1)) andalso Char.isDigit (ch (i + 2)) then
                 lexStringBody (start, i + 3, IntInf.toInt (parseInt (String.substring (text, i, 3), 10)) :: acc)
               else err (i - 1, i + 1, "invalid numeric escape"))
            else if Char.isSpace c then
              (* string gap: \ whitespace \ *)
              let fun skip j =
                    if j >= n then err (start, j, "unterminated string gap")
                    else if ch j = #"\\" then lexStringBody (start, j + 1, acc)
                    else if Char.isSpace (ch j) then skip (j + 1)
                    else err (j, j + 1, "invalid character in string gap")
              in skip i end
            else err (i - 1, i + 1, "invalid escape sequence")
        end

      fun lexSymbolic (i, j) = if at j andalso isSymbolic (ch j) then lexSymbolic (i, j + 1) else j

      (* A character that begins no token, named by its code point: the
         bytes of a UTF-8 character together, a byte that is not UTF-8 by
         itself. *)
      fun unexpected i =
        if Char.ord (ch i) < 128 then err (i, i + 1, "unexpected character " ^ codePoint (Char.ord (ch i)))
        else
          case Utf8.decode (text, i) of
            SOME (c, k) => err (i, i + k, "unexpected character " ^ codePoint c)
          | NONE => err (i, i + 1, "unexpected byte 0x" ^ Int.fmt StringCvt.HEX (Char.ord (ch i)) ^ " (invalid UTF-8)")

      (* Alphanumeric identifier or long identifier. *)
      fun lexAlpha (i) =
        let
          val j = digitsWhile (i, isIdentChar)
          val s = String.substring (text, i, j - i)
        in
          case lookupReserved (s, reservedBuckets) of
            SOME t => (t, span (i, j), j)
          | NONE =>
            if ch j = #"." andalso (isIdentStart (ch (j + 1)) orelse isSymbolic (ch (j + 1))) then
              lexLong (i, [s], j + 1)
            else (ID s, span (i, j), j)
        end
      and lexLong (start, path, i) =
        if isIdentStart (ch i) then
          let
            val j = digitsWhile (i, isIdentChar)
            val s = String.substring (text, i, j - i)
          in
            if isSome (lookupReserved (s, reservedBuckets)) then err (i, j, "reserved word in long identifier")
            else if ch j = #"." andalso (isIdentStart (ch (j + 1)) orelse isSymbolic (ch (j + 1))) then
              lexLong (start, s :: path, j + 1)
            else (LONGID (List.rev path, s), span (start, j), j)
          end
        else
          let
            val j = lexSymbolic (i, i)
            val s = String.substring (text, i, j - i)
          in
            if j = i orelse isSome (lookupReserved (s, reservedSymbolicBuckets)) then
              err (start, j, "malformed long identifier")
            else (LONGID (List.rev path, s), span (start, j), j)
          end

      fun next (i) : (token * Source.span * int) =
        if i >= n then (EOF, span (n, n), n)
        else
          let val c = ch i
          in
            if Char.isSpace c then next (i + 1)
            else if c = #"(" andalso ch (i + 1) = #"*" then next (skipComment i)
            else if Char.isDigit c then lexNumber (i, i, false)
            else if c = #"~" andalso Char.isDigit (ch (i + 1))
                    andalso not (ch (i + 1) = #"0" andalso ch (i + 2) = #"w") then
              lexNumber (i, i + 1, true)
            else if isIdentStart c then lexAlpha i
            else if c = #"'" then
              (* Section 2.4: a type variable is an alphanumeric identifier starting with a prime *)
              let val j = digitsWhile (i + 1, isIdentChar)
              in (TYVAR (String.substring (text, i, j - i)), span (i, j), j) end
            else if c = #"\"" then
              let val (s, j) = lexStringBody (i, i + 1, [])
              in (if List.all (fn c => c <= 255) s then STRING (String.implode (List.map Char.chr s))
                  else WIDESTRING s,
                  span (i, j), j)
              end
            else if c = #"#" andalso ch (i + 1) = #"\"" then
              let val (s, j) = lexStringBody (i, i + 2, [])
              in case s of
                   [c] => (CHAR c, span (i, j), j)
                 | _ => err (i, j, "character literal must contain exactly one character")
              end
            else if c = #"_" then
              (if String.size text >= i + 5 andalso String.substring (text, i, 5) = "_prim"
                  andalso not (isIdentChar (ch (i + 5))) then (PRIM, span (i, i + 5), i + 5)
               else if String.size text >= i + 9 andalso String.substring (text, i, 9) = "_overload"
                  andalso not (isIdentChar (ch (i + 9))) then (OVERLOAD, span (i, i + 9), i + 9)
               else if String.size text >= i + 8 andalso String.substring (text, i, 8) = "_dynamic"
                  andalso not (isIdentChar (ch (i + 8))) then (DYNAMIC, span (i, i + 8), i + 8)
               else if String.size text >= i + 7 andalso String.substring (text, i, 7) = "_export"
                  andalso not (isIdentChar (ch (i + 7))) then (EXPORT, span (i, i + 7), i + 7)
               else if String.size text >= i + 8 andalso String.substring (text, i, 8) = "_virtual"
                  andalso not (isIdentChar (ch (i + 8))) then (VIRTUAL, span (i, i + 8), i + 8)
               else (UNDERSCORE, span (i, i + 1), i + 1))
            else if c = #"." then
              (if ch (i + 1) = #"." andalso ch (i + 2) = #"." then (DOTS, span (i, i + 3), i + 3)
               else err (i, i + 1, "unexpected '.'"))
            else if isSymbolic c then
              let
                val j = lexSymbolic (i, i)
                val s = String.substring (text, i, j - i)
              in
                case lookupReserved (s, reservedSymbolicBuckets) of
                  SOME t => (t, span (i, j), j)
                | NONE => (ID s, span (i, j), j)
              end
            else
              let
                val t =
                  case c of
                    #"(" => LPAREN | #")" => RPAREN | #"[" => LBRACKET | #"]" => RBRACKET
                  | #"{" => LBRACE | #"}" => RBRACE | #"," => COMMA | #";" => SEMI
                  | _ => unexpected i
              in (t, span (i, i + 1), i + 1) end
          end

    in
      {next = next, skipComment = skipComment}
    end

  fun tokenize (file : Source.file) : item vector =
    let
      val {next, ...} = lexerOf (#name file, #text file)
      fun loop (i, acc) =
        let val (t, sp, j) = next i
        in case t of EOF => List.rev ((t, sp) :: acc) | _ => loop (j, (t, sp) :: acc) end
    in
      Vector.fromList (loop (0, []))
    end

  (* ---- the lexer for the eye (docs/plans/repl.md, D13) ----
     What a text is to someone reading it, a piece at a time, for colouring
     it as it is typed: the same tokens as tokenize, with the comments
     between them, and never an error -- what the lexer refuses is a piece
     of its own (Bad): an unterminated string to the end of its line, an
     unexpected character by itself. A text is scanned from the state its
     first line begins in, and scan gives the state its end leaves, so that
     an editor scans a line again only where it or the state before it
     changed. *)
  datatype class = Keyword | Name | LongName | Operator | TyVar | Number | Text | Comment | Bad | Other

  (* where a line begins: in code, in a comment that many deep, or in a
     string's gap (`\` whitespace `\`) *)
  datatype state = Code | InComment of int | InGap

  fun scan (text : string, state : state) : (int * int * class) list * state =
    let
      val n = String.size text
      val {next, ...} = lexerOf ("", text)
      fun ch i = if i < n then String.sub (text, i) else #"\000"
      (* the index after a comment's end, from i at depth d; 0 for the depth
         where it ends, else the depth at the text's end *)
      fun comment (i, d) =
        if i >= n then (n, d)
        else if ch i = #"(" andalso ch (i + 1) = #"*" then comment (i + 2, d + 1)
        else if ch i = #"*" andalso ch (i + 1) = #")" then (if d = 1 then (i + 2, 0) else comment (i + 2, d - 1))
        else comment (i + 1, d)
      (* a string's body from i: SOME the index after its quote, or NONE where
         a line or the text ends first, with the index and whether it ended
         in a gap *)
      fun body (i, gap) : int option * int * bool =
        if i >= n then (NONE, n, gap)
        else if gap then body (i + 1, ch i <> #"\\")
        else
          case ch i of
            #"\"" => (SOME (i + 1), i + 1, false)
          | #"\\" => if Char.isSpace (ch (i + 1)) then body (i + 1, true) else body (i + 2, false)
          | #"\n" => (NONE, i, false)
          | _ => body (i + 1, false)
      fun classOf (t : token, i : int) : class =
        case t of
          ID s => if Char.isAlpha (String.sub (s, 0)) then Name else Operator
        | LONGID _ => LongName
        | TYVAR _ => TyVar
        | INT _ => Number
        | WORD _ => Number
        | REAL _ => Number
        | STRING _ => Text
        | WIDESTRING _ => Text
        | CHAR _ => Text
        | _ => if Char.isAlpha (ch i) orelse ch i = #"_" andalso Char.isAlpha (ch (i + 1)) then Keyword else Other
      fun string (start, from, acc) =
        case body (from, false) of
          (SOME j, _, _) => go (j, (start, j, Text) :: acc)
        | (NONE, j, true) => (List.rev ((start, j, Text) :: acc), InGap)
        | (NONE, j, false) => go (j, (start, j, Bad) :: acc)
      and go (i, acc) =
        if i >= n then (List.rev acc, Code)
        else
          let val c = ch i
          in
            if Char.isSpace c then go (i + 1, acc)
            else if c = #"(" andalso ch (i + 1) = #"*" then
              (case comment (i + 2, 1) of
                 (j, 0) => go (j, (i, j, Comment) :: acc)
               | (j, d) => (List.rev ((i, j, Comment) :: acc), InComment d))
            else if c = #"\"" then string (i, i + 1, acc)
            else if c = #"#" andalso ch (i + 1) = #"\"" then string (i, i + 2, acc)
            else
              let
                (* the handler is the token's alone, so that go stays a loop *)
                val (j, class) =
                  (let val (t, _, j) = next i in (j, classOf (t, i)) end)
                  handle Error.CompileError ({stop, ...}, _) => (Int.min (n, Int.max (i + 1, stop)), Bad)
              in go (j, (i, j, class) :: acc) end
          end
    in
      case state of
        Code => go (0, [])
      | InComment d =>
          (case comment (0, d) of
             (j, 0) => go (j, if j > 0 then [(0, j, Comment)] else [])
           | (j, d') => ([(0, j, Comment)], InComment d'))
      | InGap =>
          (case body (0, true) of
             (SOME j, _, _) => go (j, [(0, j, Text)])
           | (NONE, j, true) => ([(0, j, Text)], InGap)
           | (NONE, j, false) => go (j, [(0, j, Bad)]))
    end
end

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

  (* What no source may hold raw, in any mode and anywhere -- between
     tokens, in a comment or in a literal -- of the code points above 127
     (docs/plans/utf8.md, D5): what each is, or NONE. A literal says them by
     escapes; a comment cannot hold them at all. The marks LRM, RLM and ALM
     and the other default-ignorables are not among them. *)
  fun refusedAbove127 (c : int) : string option =
    if c >= 0x80 andalso c <= 0x9F then SOME "C1 control"
    else if c < 0x2028 then NONE
    else if c = 0x2028 then SOME "line separator"
    else if c = 0x2029 then SOME "paragraph separator"
    else if (c >= 0x202A andalso c <= 0x202E) orelse (c >= 0x2066 andalso c <= 0x2069) then SOME "bidi control"
    else if c = 0xFEFF then SOME "byte order mark"
    else NONE

  (* The bytes of a comment by what its loop does with each: 0 goes on, 1
     is "(", 2 is "*", and 3 is looked at -- a control but TAB, LF and FF,
     DEL, or a byte above 127 -- so that a byte of plain text costs one
     lookup. *)
  val commentClass =
    Vector.tabulate (256, fn i => if i = 40 then 1 else if i = 42 then 2
                                  else if (i >= 32 andalso i < 127) orelse i = 9 orelse i = 10 orelse i = 12 then 0
                                  else 3)

  (* An escape of a code point: \uXXXX, or \UXXXXXXXX above U+FFFF *)
  fun escapeOf c =
    if c <= 0xFFFF then "\\u" ^ StringCvt.padLeft #"0" 4 (Int.fmt StringCvt.HEX c)
    else "\\U" ^ StringCvt.padLeft #"0" 8 (Int.fmt StringCvt.HEX c)

  (* The lexer of a text read in a mode (Source.mode): the token at an
     index, with its span and the index after it (whitespace and comments
     before it skipped), and the index after a comment that begins at an
     index. Both raise Error.CompileError where the text is not SML.
     tokenize reads a file with it, in the file's mode, and scan a line to
     colour.

     What a source may hold raw is the same in every mode (D5): between
     tokens, white space is space, TAB, LF, FF and CR before LF; a comment
     holds any text but the other controls and what refusedAbove127 names;
     a literal holds no control, and nothing that refusedAbove127 names.
     The modes differ in a literal (D6, D7): by default it holds ASCII
     alone, and writes the rest as escapes, of which \U is not one; under
     --unicode a raw character means its code point, which only a wide
     type takes (the literal's mark, Token); under --unicode=latin1 it is
     its own byte. The text is UTF-8: a Latin-1 file is made UTF-8 as it is
     read (Source.readFile), and refused where it looks like UTF-8 itself
     (D3). *)
  fun lexerOf (mode : Source.mode, name : string, text : string)
      : {next : int -> token * Source.span * int, skipComment : int -> int} =
    let
      val n = String.size text
      fun span (a, b) : Source.span = {file = name, start = a, stop = b}
      fun err (a, b, msg) = Error.error (span (a, b), msg)
      fun ch i = if i < n then String.sub (text, i) else #"\000"
      fun at i = i < n
      val latin1 = mode = Source.Unicode Source.Latin1
      val utf8Raw = mode = Source.Unicode Source.Utf8

      (* Under --unicode=latin1, the characters from i, each a byte of the
         file, where they are the UTF-8 of a character: the file was UTF-8
         and not Latin-1 (D3) *)
      fun looksUtf8 i =
        let
          fun bytes (j, m, acc) =
            if m = 0 then acc
            else case Utf8.decode (text, j) handle Subscript => NONE of
                   SOME (c, k) => if c <= 255 then bytes (j + k, m - 1, (Char.chr c, j + k) :: acc) else acc
                 | NONE => acc
          val got = List.rev (bytes (i, 4, []))
        in
          case Utf8.decode (String.implode (List.map #1 got), 0) handle Subscript => NONE of
            SOME (u, k) =>
              if k < 2 then ()
              else err (i, #2 (List.nth (got, k - 1)),
                        "the text looks like UTF-8: " ^ String.concatWith " " (List.map (codePoint o Char.ord o #1) (List.take (got, k)))
                        ^ " are the bytes of " ^ codePoint u ^ " (read the file with --unicode, not --unicode=latin1)")
          | NONE => ()
        end

      (* The character whose bytes begin at i, a byte above 127, by the
         mode's encoding: its code point and how many bytes it has, once
         the rules every context shares are checked; context says where it
         is, for the message *)
      fun above127 (i, context) : int * int =
        case Utf8.decode (text, i) of
          NONE => err (i, i + 1, "invalid UTF-8 (byte 0x" ^ Int.fmt StringCvt.HEX (Char.ord (ch i)) ^ ") " ^ context)
        | SOME (c, k) =>
            case refusedAbove127 c of
              SOME what => err (i, i + k, what ^ " " ^ codePoint c ^ " " ^ context
                                          ^ (if context = "in a comment" then "" else " (write it as " ^ escapeOf c ^ ")"))
            | NONE => ((if latin1 andalso c >= 0xC2 then looksUtf8 i else ()); (c, k))

      (* how many bytes of formatting -- space, TAB, LF, FF, or CR LF -- are
         at i: the white space between tokens and in a string's gap *)
      fun formatting i =
        case ch i of
          #" " => 1 | #"\n" => 1 | #"\t" => 1 | #"\f" => 1
        | #"\r" => if ch (i + 1) = #"\n" then 2 else 0
        | _ => 0

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
                case Vector.sub (commentClass, Char.ord c) of
                  0 => go (i + 1)
                | 1 => if ch (i + 1) = #"*" then (depth := !depth + 1; go (i + 2)) else go (i + 1)
                | 2 => if ch (i + 1) = #")" then (depth := !depth - 1; if !depth = 0 then i + 2 else go (i + 2))
                       else go (i + 1)
                | _ => go (i + odd (i, c))
              end
          (* a control, DEL or a byte above 127 in a comment: how many bytes
             its character has, where the comment may hold it (D4, D5) *)
          and odd (i, c) =
            if Char.ord c >= 128 then #2 (above127 (i, "in a comment"))
            else if c = #"\r" andalso ch (i + 1) = #"\n" then 2
            else err (i, i + 1, "control character " ^ codePoint (Char.ord c) ^ " in a comment"
                                ^ (if c = #"\r" then " (a carriage return not before a line feed)" else ""))
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
         Returns (chars, index after closing quote); rawMark is SOME the
         first raw character above 127 of a literal read under --unicode,
         which the caller resets. *)
      val rawMark : int option ref = ref NONE
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
                 else if Char.ord c < 128 then lexStringBody (start, i + 1, Char.ord c :: acc)
                 else
                   (* a raw character above 127 means its code point (D6):
                      by default it is refused, under --unicode marked *)
                   let
                     val (cp, k) = above127 (i, "in string literal")
                     val () =
                       if mode = Source.Ascii then
                         err (i, i + k, "non-ASCII character " ^ codePoint cp ^ " in string literal ("
                                        ^ (if cp <= 0xFFFF then "write it as " ^ escapeOf cp ^ ", or read the file with --unicode"
                                           else "read the file with --unicode, where it is " ^ escapeOf cp) ^ ")")
                       else if utf8Raw andalso not (isSome (!rawMark)) then rawMark := SOME cp
                       else ()
                   in lexStringBody (start, i + k, cp :: acc) end
      and surrogate v = "surrogate " ^ codePoint v ^ " in an escape: a surrogate is no character"
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
          (* a surrogate is no character, and is refused at every type
             (D9): a deviation, since the Definition's alphabet holds it *)
          | #"u" =>
            if isHex (ch (i + 1)) andalso isHex (ch (i + 2)) andalso isHex (ch (i + 3)) andalso isHex (ch (i + 4)) then
              let val v = IntInf.toInt (parseInt (String.substring (text, i + 1, 4), 16))
              in if v >= 0xD800 andalso v <= 0xDFFF then err (i - 1, i + 5, surrogate v)
                 else lexStringBody (start, i + 5, v :: acc)
              end
            else err (i - 1, i + 1, "invalid \\u escape")
          (* Successor ML's \U, under --unicode only (D7) *)
          | #"U" =>
            if mode = Source.Ascii then err (i - 1, i + 1, "the escape \\U needs --unicode")
            else if List.all (fn k => isHex (ch (i + k))) [1, 2, 3, 4, 5, 6, 7, 8] then
              let val v = IntInf.toInt (parseInt (String.substring (text, i + 1, 8), 16))
              in if v > 1114111 then err (i - 1, i + 9, "\\U escape out of range (the largest code point is 0x10FFFF)")
                 else if v >= 0xD800 andalso v <= 0xDFFF then err (i - 1, i + 9, surrogate v)
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
            else if formatting i > 0 then
              (* string gap: \ formatting \, where formatting is what white
                 space between tokens may be *)
              let fun skip j =
                    if j >= n then err (start, j, "unterminated string gap")
                    else if ch j = #"\\" then lexStringBody (start, j + 1, acc)
                    else case formatting j of
                           0 => err (j, j + 1, "invalid character in string gap")
                         | k => skip (j + k)
              in skip i end
            else err (i - 1, i + 1, "invalid escape sequence")
        end

      fun lexSymbolic (i, j) = if at j andalso isSymbolic (ch j) then lexSymbolic (i, j + 1) else j

      (* A character that begins no token, named by its code point: the
         bytes of a UTF-8 character together, a byte that is not UTF-8 by
         itself. *)
      fun unexpected i =
        if Char.ord (ch i) < 128 then
          err (i, i + 1, "unexpected character " ^ codePoint (Char.ord (ch i))
                         ^ (if ch i = #"\r" then " (a carriage return not before a line feed)" else ""))
        else
          case Utf8.decode (text, i) of
            SOME (c, k) => ((if latin1 andalso c >= 0xC2 then looksUtf8 i else ());
                            err (i, i + k, "unexpected character " ^ codePoint c
                                          ^ (case refusedAbove127 c of SOME what => " (a " ^ what ^ ")" | NONE => "")))
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
            if c = #" " orelse c = #"\n" orelse c = #"\t" orelse c = #"\f" then next (i + 1)
            else if c = #"\r" andalso ch (i + 1) = #"\n" then next (i + 2)
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
              let
                val () = rawMark := NONE
                val (s, j) = lexStringBody (i, i + 1, [])
              in (if not (isSome (!rawMark)) andalso List.all (fn c => c <= 255) s then STRING (String.implode (List.map Char.chr s))
                  else WIDESTRING (s, !rawMark),
                  span (i, j), j)
              end
            else if c = #"#" andalso ch (i + 1) = #"\"" then
              let
                val () = rawMark := NONE
                val (s, j) = lexStringBody (i, i + 2, [])
              in case s of
                   [c] => (CHAR (c, !rawMark), span (i, j), j)
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
      val {next, ...} = lexerOf (#mode file, #name file, #text file)
      fun loop (i, acc) =
        let val (t, sp, j) = next i
        in case t of EOF => List.rev ((t, sp) :: acc) | _ => loop (j, (t, sp) :: acc) end
      (* a byte order mark at the start of UTF-8 text is no part of it
         (D5); elsewhere it is refused *)
      val start = if #mode file <> Source.Unicode Source.Latin1 andalso String.isPrefix "\239\187\191" (#text file) then 3
                  else 0
    in
      Vector.fromList (loop (start, []))
    end

  (* ---- the lexer for the eye (docs/plans/repl.md, D13) ----
     What a text is to someone reading it, a piece at a time, for colouring
     it as it is typed: the same tokens as tokenize, with the comments
     between them, and never an error -- what the lexer refuses is a piece
     of its own (Bad): an unterminated string to the end of its line, an
     unexpected character by itself. A text is scanned from the state its
     first line begins in, and scan gives the state its end leaves, so that
     an editor scans a line again only where it or the state before it
     changed. A line is lexed in the mode of the text it is from: the
     REPL's typed input is UTF-8 under --unicode (ReplSession.typedMode). *)
  datatype class = Keyword | Name | LongName | Operator | TyVar | Number | Text | Comment | Bad | Other

  (* where a line begins: in code, in a comment that many deep, or in a
     string's gap (`\` whitespace `\`) *)
  datatype state = Code | InComment of int | InGap

  fun scan (mode : Source.mode, text : string, state : state) : (int * int * class) list * state =
    let
      val n = String.size text
      val {next, ...} = lexerOf (mode, "", text)
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

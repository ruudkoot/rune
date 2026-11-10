(* Implements: HS_LEXER *)
structure HsLexer :> HS_LEXER =
struct
  structure T = HsToken
  structure C = HsChar

  type options = {hierarchical : bool}
  val defaults : options = {hierarchical = false}

  val asciiNames =
    [("NUL", 0), ("SOH", 1), ("STX", 2), ("ETX", 3), ("EOT", 4), ("ENQ", 5), ("ACK", 6),
     ("BEL", 7), ("BS", 8), ("HT", 9), ("LF", 10), ("VT", 11), ("FF", 12), ("CR", 13),
     ("SO", 14), ("SI", 15), ("DLE", 16), ("DC1", 17), ("DC2", 18), ("DC3", 19), ("DC4", 20),
     ("NAK", 21), ("SYN", 22), ("ETB", 23), ("CAN", 24), ("EM", 25), ("SUB", 26), ("ESC", 27),
     ("FS", 28), ("GS", 29), ("RS", 30), ("US", 31), ("SP", 32), ("DEL", 127)]

  fun allDashes s = size s >= 2 andalso CharVector.all (fn c => c = #"-") s

  val identAscii = Vector.tabulate (128, HsChar.isIdent)
  val symAscii = Vector.tabulate (128, HsChar.isSymbol)

  fun hexCode c = "U+" ^ StringCvt.padLeft #"0" 4 (Int.fmt StringCvt.HEX c)

  fun tokens ({hierarchical} : options, file, src) : T.item vector =
    let
      val n = size src
      val i = ref 0
      val line = ref 1
      val col = ref 1
      val bol = ref true
      val pre : T.trivium list ref = ref []
      val out : T.item list ref = ref []

      fun byte k = if k < n then Char.ord (String.sub (src, k)) else ~1

      fun failAt (a, b, msg) = raise HsSource.Error ({file = file, start = a, stop = b}, msg)
      fun fail msg = failAt (!i, Int.min (n, !i + 1), msg)

      (* The code point at byte k and its width; a byte that begins no
         sequence of UTF-8 is its own code point. *)
      fun decode k =
        let val b = byte k
        in
          if b < 128 then (b, 1)
          else case Utf8.decode (src, k) of SOME cw => cw | NONE => (b, 1)
        end
      fun cpAt k = if k >= n then ~1 else let val b = byte k in if b < 128 then b else #1 (decode k) end

      fun newline () = (line := !line + 1; col := 1; bol := true)

      (* past one character, keeping the line and the column (9.3) *)
      fun step () =
        let val c = byte (!i) in
          if c = 10 orelse c = 12 then (i := !i + 1; newline ())
          else if c = 13 then (i := !i + 1; if byte (!i) = 10 then i := !i + 1 else (); newline ())
          else if c = 9 then (i := !i + 1; col := ((!col - 1) div 8 + 1) * 8 + 1)
          else if c < 128 then (i := !i + 1; col := !col + 1)
          else (i := !i + #2 (decode (!i)); col := !col + 1)
        end

      fun trivium (kind, a) = pre := {kind = kind, start = a, stop = !i} :: !pre

      fun emit (t, a, sl, sc, b) =
        (out := {token = t, start = a, stop = !i, line = sl, column = sc, first = b,
                 trivia = case !pre of [] => [] | (l as [_]) => l | l => List.rev l} :: !out;
         pre := [];
         bol := false)

      (* A run of the characters whose class `pred` accepts, `ascii` the
         same for a byte below 128. *)
      fun scanWhile (ascii : bool vector, pred) =
        let
          val a = !i
          fun loop (j, chars) =
            if j >= n then (j, chars)
            else
              let val b = Char.ord (String.sub (src, j))
              in
                if b < 128 then (if Vector.sub (ascii, b) then loop (j + 1, chars + 1) else (j, chars))
                else
                  let val (cp, w) = decode j
                  in if pred cp then loop (j + w, chars + 1) else (j, chars) end
              end
          val (j, chars) = loop (a, 0)
        in
          i := j; col := !col + chars; String.substring (src, a, j - a)
        end

      fun scanIdent () = scanWhile (identAscii, C.isIdent)
      fun scanSym () = scanWhile (symAscii, C.isSymbol)

      fun isWhite c = c = 32 orelse (c >= 9 andalso c <= 13) orelse (c >= 128 andalso C.classify (cpAt (!i)) = C.White)

      fun whitespace () =
        let
          val a = !i
          (* spaces at once, the rest a character at a time *)
          fun spaces j = if j < n andalso String.sub (src, j) = #" " then spaces (j + 1) else j
          fun loop () =
            let
              val j = spaces (!i)
              val () = (col := !col + (j - !i); i := j)
              val c = byte j
            in
              if c >= 0 andalso isWhite c then (step (); loop ()) else ()
            end
        in loop (); trivium (T.Whitespace, a) end

      fun nestedComment () =
        let
          val a = !i
          val kind = if byte (a + 2) = 35 then T.Pragma else T.BlockComment
          fun loop depth =
            if depth = 0 then ()
            else
              let val c = byte (!i) in
                if c < 0 then failAt (a, a + 2, "unterminated nested comment: no `-}` closes this `{-`")
                else if c = 123 andalso byte (!i + 1) = 45 then (i := !i + 2; col := !col + 2; loop (depth + 1))
                else if c = 45 andalso byte (!i + 1) = 125 then (i := !i + 2; col := !col + 2; loop (depth - 1))
                else (step (); loop depth)
              end
        in
          i := !i + 2; col := !col + 2; loop 1; trivium (kind, a)
        end

      (* from its dashes, which are read, to the end of the line *)
      fun lineComment a =
        let
          fun loop () =
            let val c = byte (!i)
            in if c < 0 orelse c = 10 orelse c = 13 orelse c = 12 then () else (step (); loop ()) end
        in loop (); trivium (T.LineComment, a) end

      fun digitsWhile pred =
        let
          val a = !i
          fun loop () = if pred (byte (!i)) then (i := !i + 1; col := !col + 1; loop ()) else ()
        in loop (); String.substring (src, a, !i - a) end

      fun isDec c = c >= 48 andalso c <= 57
      fun isOct c = c >= 48 andalso c <= 55
      fun isHex c = isDec c orelse (c >= 65 andalso c <= 70) orelse (c >= 97 andalso c <= 102)
      fun hexVal c = if c <= 57 then c - 48 else if c <= 70 then c - 55 else c - 87

      fun value (base, s) =
        CharVector.foldl
          (fn (c, acc) => IntInf.+ (IntInf.* (acc, IntInf.fromInt base), IntInf.fromInt (hexVal (Char.ord c))))
          (IntInf.fromInt 0) s

      fun number () =
        let
          val (a, sl, sc, b) = (!i, !line, !col, !bol)
          val c = byte a
          val c1 = byte (a + 1)
          val c2 = byte (a + 2)
          fun radix (base, pred) =
            (i := !i + 2; col := !col + 2;
             let val v = value (base, digitsWhile pred)
             in emit (T.INTEGER (v, String.substring (src, a, !i - a)), a, sl, sc, b) end)
        in
          if c = 48 andalso (c1 = 120 orelse c1 = 88) andalso isHex c2 then radix (16, isHex)
          else if c = 48 andalso (c1 = 111 orelse c1 = 79) andalso isOct c2 then radix (8, isOct)
          else
            let
              val d = digitsWhile isDec
              fun exponentAt k =
                let val e = byte k in
                  (e = 101 orelse e = 69) andalso
                  (let val s = byte (k + 1)
                   in isDec s orelse ((s = 43 orelse s = 45) andalso isDec (byte (k + 2))) end)
                end
              fun takeExponent () =
                if exponentAt (!i) then
                  (i := !i + 1; col := !col + 1;
                   if not (isDec (byte (!i))) then (i := !i + 1; col := !col + 1) else ();
                   ignore (digitsWhile isDec);
                   true)
                else false
              fun text () = String.substring (src, a, !i - a)
            in
              if byte (!i) = 46 andalso isDec (byte (!i + 1)) then
                (i := !i + 1; col := !col + 1; ignore (digitsWhile isDec); ignore (takeExponent ());
                 emit (T.FLOAT (text ()), a, sl, sc, b))
              else if takeExponent () then emit (T.FLOAT (text ()), a, sl, sc, b)
              else emit (T.INTEGER (value (10, d), d), a, sl, sc, b)
            end
        end

      (* After the backslash of an escape of the literal `what`; NONE is
         `\&`. *)
      fun escape what =
        let
          val a = !i - 1
          val c = byte (!i)
          fun take v = (step (); SOME v)
          fun bad msg = failAt (a, Int.min (n, !i + 1), msg ^ " in " ^ what)
          fun numeric (base, pred) =
            let val v = value (base, digitsWhile pred)
            in
              if IntInf.> (v, IntInf.fromInt 1114111) then
                failAt (a, !i, "a numeric escape above 0x10FFFF in " ^ what)
              else SOME (IntInf.toInt v)
            end
        in
          case c of
            97 => take 7 | 98 => take 8 | 102 => take 12 | 110 => take 10
          | 114 => take 13 | 116 => take 9 | 118 => take 11
          | 92 => take 92 | 34 => take 34 | 39 => take 39
          | 38 => (step (); NONE)
          | 94 =>
              let val d = byte (!i + 1) in
                if (d >= 64 andalso d <= 95) then (step (); step (); SOME (d - 64))
                else bad "a control escape `\\^` not followed by `@`, `A` to `Z`, `[`, `\\`, `]`, `^` or `_`"
              end
          | 111 => if isOct (byte (!i + 1)) then (step (); numeric (8, isOct)) else bad "an octal escape with no digit"
          | 120 => if isHex (byte (!i + 1)) then (step (); numeric (16, isHex)) else bad "a hexadecimal escape with no digit"
          | _ =>
              if isDec c then numeric (10, isDec)
              else
                let
                  (* the longest name, so that \SOH is not \SO then H *)
                  fun matches (name, _) =
                    let
                      val l = size name
                      fun go k = k >= l orelse (byte (!i + k) = Char.ord (String.sub (name, k)) andalso go (k + 1))
                    in go 0 end
                  val best =
                    List.foldl
                      (fn (h, NONE) => if matches h then SOME h else NONE
                        | (h, SOME g) => if matches h andalso size (#1 h) > size (#1 g) then SOME h else SOME g)
                      NONE asciiNames
                in
                  case best of
                    SOME (name, v) => (i := !i + size name; col := !col + size name; SOME v)
                  | NONE => bad "an escape that is none of the Report's"
                end
        end

      fun stringLit () =
        let
          val (a, sl, sc, b) = (!i, !line, !col, !bol)
          val acc = ref []
          fun loop () =
            let val c = byte (!i) in
              if c < 0 orelse c = 10 orelse c = 13 then
                failAt (a, a + 1, "unterminated string literal: no `\"` closes it on its line")
              else if c = 34 then step ()
              else if c = 92 then
                (step ();
                 let val d = byte (!i) in
                   if d >= 0 andalso isWhite d then
                     let
                       fun gap () =
                         let val e = byte (!i) in
                           if e >= 0 andalso isWhite e then (step (); gap ())
                           else if e = 92 then step ()
                           else failAt (a, Int.min (n, !i + 1), "a string gap that does not end in `\\`")
                         end
                     in gap (); loop () end
                   else
                     (case escape "a string literal" of
                        SOME v => acc := v :: !acc
                      | NONE => ();
                      loop ())
                 end)
              else if c < 32 orelse c = 127 then
                failAt (!i, !i + 1, "a control character in a string literal: write it as an escape")
              else (acc := cpAt (!i) :: !acc; step (); loop ())
            end
        in
          step ();
          loop ();
          emit (T.STRING (List.rev (!acc), String.substring (src, a, !i - a)), a, sl, sc, b)
        end

      fun charLit () =
        let
          val (a, sl, sc, b) = (!i, !line, !col, !bol)
          val () = step ()
          val c = byte (!i)
          val v =
            if c = 92 then
              (step ();
               case escape "a character literal" of
                 SOME v => v
               | NONE => failAt (a, !i, "`\\&` in a character literal, which holds one character"))
            else if c < 0 orelse c < 32 orelse c = 127 then
              failAt (a, Int.min (n, !i + 1), "a character literal with a control character or none")
            else if c = 39 then failAt (a, !i + 1, "an empty character literal")
            else let val v = cpAt (!i) in step (); v end
        in
          if byte (!i) = 39 then step ()
          else failAt (a, Int.min (n, !i + 1), "unterminated character literal: no `'` closes it");
          emit (T.CHAR (v, String.substring (src, a, !i - a)), a, sl, sc, b)
        end

      fun symbol () =
        let
          val (a, sl, sc, b) = (!i, !line, !col, !bol)
          val s = scanSym ()
        in
          if allDashes s then lineComment a
          else
            case T.reservedOp s of
              SOME t => emit (t, a, sl, sc, b)
            | NONE => emit (if String.sub (s, 0) = #":" then T.CONSYM s else T.VARSYM s, a, sl, sc, b)
        end

      fun large () =
        let
          val (a, sl, sc, b) = (!i, !line, !col, !bol)
          fun con (prefix, name) = if prefix = "" then T.CONID name else T.QCONID (prefix, name)
          (* A conid has been read, prefix its qualifier so far. *)
          fun qualified (prefix, name) =
            let
              val modname = if prefix = "" then name else prefix ^ "." ^ name
              val (si, sc') = (!i, !col)
              fun restore () = (i := si; col := sc'; emit (con (prefix, name), a, sl, sc, b))
            in
              if byte (!i) <> 46 then emit (con (prefix, name), a, sl, sc, b)
              else
                let val next = cpAt (!i + 1)
                in
                  case C.classify next of
                    C.Large =>
                      (i := !i + 1; col := !col + 1;
                       let val name2 = scanIdent ()
                       in
                         if hierarchical then qualified (modname, name2)
                         else emit (T.QCONID (modname, name2), a, sl, sc, b)
                       end)
                  | C.Small =>
                      (i := !i + 1; col := !col + 1;
                       let val v = scanIdent ()
                       in
                         case T.reservedId v of
                           SOME _ => restore ()
                         | NONE => emit (T.QVARID (modname, v), a, sl, sc, b)
                       end)
                  | _ =>
                      if C.isSymbol next then
                        (i := !i + 1; col := !col + 1;
                         let
                           val (j, c) = (!i, !col)
                           val s = scanSym ()
                           (* the longest lexeme: the longest run of the symbols that
                              is an operator, neither reserved nor dashes, so that
                              `F.--` is `F.-` then `-`, and `F.->` is `F.-` then `>` *)
                           fun boundary k = k = 0 orelse k = size s orelse
                                            let val x = Char.ord (String.sub (s, k)) in x < 128 orelse x >= 192 end
                           fun chars p = CharVector.foldl (fn (ch, n) => if Char.ord ch < 128 orelse Char.ord ch >= 192 then n + 1 else n) 0 p
                           fun operator p = not (allDashes p) andalso not (isSome (T.reservedOp p))
                           fun longest k =
                             if k = 0 then NONE
                             else if boundary k andalso operator (String.substring (s, 0, k)) then SOME (String.substring (s, 0, k))
                             else longest (k - 1)
                         in
                           case longest (size s) of
                             NONE => restore ()
                           | SOME p =>
                               (i := j + size p; col := c + chars p;
                                if String.sub (p, 0) = #":" then emit (T.QCONSYM (modname, p), a, sl, sc, b)
                                else emit (T.QVARSYM (modname, p), a, sl, sc, b))
                         end)
                      else restore ()
                end
            end
        in
          qualified ("", scanIdent ())
        end

      fun small () =
        let
          val (a, sl, sc, b) = (!i, !line, !col, !bol)
          val s = scanIdent ()
        in
          case T.reservedId s of
            SOME t => emit (t, a, sl, sc, b)
          | NONE => emit (T.VARID s, a, sl, sc, b)
        end

      fun single t =
        let val (a, sl, sc, b) = (!i, !line, !col, !bol)
        in i := !i + 1; col := !col + 1; emit (t, a, sl, sc, b) end

      fun loop () =
        if !i >= n then ()
        else
          let val c = byte (!i) in
            (if c = 32 orelse (c >= 9 andalso c <= 13) then whitespace ()
             else
               case c of
                 40 => single T.LPAREN | 41 => single T.RPAREN | 44 => single T.COMMA
               | 59 => single T.SEMI | 91 => single T.LBRACKET | 93 => single T.RBRACKET
               | 96 => single T.BACKQUOTE | 125 => single T.RBRACE
               | 123 => if byte (!i + 1) = 45 then nestedComment () else single T.LBRACE
               | 34 => stringLit ()
               | 39 => charLit ()
               | 58 => symbol ()
               | _ =>
                 let val cp = cpAt (!i) in
                   case C.classify cp of
                     C.Small => small ()
                   | C.Large => large ()
                   | C.Digit =>
                       if c < 128 then number ()
                       else fail ("a digit above ASCII, " ^ hexCode cp ^ ", in a number: the Report's are ASCII (R6)")
                   | C.Symbol => symbol ()
                   | C.White => whitespace ()
                   | _ =>
                       if cp >= 128 then
                         failAt (!i, !i + #2 (decode (!i)),
                                 "the character " ^ hexCode cp ^ " outside a comment or a literal: its general category, " ^
                                 CodePoint.abbreviation (CodePoint.category cp) ^ ", is of none of the Report's classes")
                       else fail ("the character " ^ hexCode cp ^ " outside a comment or a literal")
                 end);
            loop ()
          end
    in
      if n >= 3 andalso String.substring (src, 0, 3) = "\239\187\191" then
        (i := 3; trivium (T.ByteOrderMark, 0))
      else ();
      loop ();
      out := {token = T.EOF, start = n, stop = n, line = !line, column = 0, first = false,
              trivia = List.rev (!pre)} :: !out;
      Vector.fromList (List.rev (!out))
    end
end

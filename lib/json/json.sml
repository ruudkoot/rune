(* JSON (docs/plans/repl.md, The libraries): a reader by recursive descent
   over byte offsets, which checks the UTF-8 of strings with lib/unicode, and
   a writer that escapes only what the RFC requires. *)

(* Implements: JSON *)
structure Json :> JSON =
struct
  datatype value =
      Null
    | Bool of bool
    | Number of string
    | String of string
    | Array of value list
    | Object of (string * value) list

  exception Syntax of int * string

  val maxDepth = 512

  fun isDigit c = c >= #"0" andalso c <= #"9"

  (* the end of the number that begins at i, or ~1 where the text is not
     one: a minus or not; 0, or a digit from 1 and digits; a point and
     digits or not; an e or E, a sign or not, and digits, or not *)
  fun numberEnd (s, i) =
    let
      val n = size s
      fun at j = if j < n then String.sub (s, j) else #"\000"
      fun digits j = if isDigit (at j) then digits (j + 1) else j
      val i1 = if at i = #"-" then i + 1 else i
      val i2 = if at i1 = #"0" then i1 + 1
               else if isDigit (at i1) then digits i1
               else ~1
      val i3 = if i2 < 0 then ~1
               else if at i2 = #"." then (if isDigit (at (i2 + 1)) then digits (i2 + 1) else ~1)
               else i2
      val i4 = if i3 < 0 then ~1
               else if at i3 = #"e" orelse at i3 = #"E" then
                 let val j = if at (i3 + 1) = #"+" orelse at (i3 + 1) = #"-" then i3 + 2 else i3 + 1
                 in if isDigit (at j) then digits j else ~1 end
               else i3
    in
      i4
    end

  fun decode s =
    let
      val n = size s
      fun at i = if i < n then String.sub (s, i) else #"\000"
      fun fail (i, msg) = raise Syntax (i, msg)
      fun blanks i =
        case at i of
          #" " => blanks (i + 1) | #"\t" => blanks (i + 1)
        | #"\n" => blanks (i + 1) | #"\r" => blanks (i + 1)
        | _ => i
      fun literal (i, word, v) =
        if String.isPrefix word (String.extract (s, i, SOME (Int.min (size word, n - i))))
        then (v, i + size word)
        else fail (i, "expected " ^ word)
      fun hex4 i =
        let
          fun h j =
            let val c = at j
            in
              if isDigit c then ord c - ord #"0"
              else if c >= #"a" andalso c <= #"f" then ord c - ord #"a" + 10
              else if c >= #"A" andalso c <= #"F" then ord c - ord #"A" + 10
              else fail (j, "expected a hexadecimal digit")
            end
        in
          ((h i * 16 + h (i + 1)) * 16 + h (i + 2)) * 16 + h (i + 3)
        end
      (* a string that begins after the quote at i - 1 *)
      fun string i =
        let
          fun go (j, acc) =
            if j >= n then fail (j, "unterminated string")
            else
              case at j of
                #"\"" => (String.concat (rev acc), j + 1)
              | #"\\" =>
                  (case at (j + 1) of
                     #"\"" => go (j + 2, "\"" :: acc)
                   | #"\\" => go (j + 2, "\\" :: acc)
                   | #"/" => go (j + 2, "/" :: acc)
                   | #"b" => go (j + 2, "\b" :: acc)
                   | #"f" => go (j + 2, "\f" :: acc)
                   | #"n" => go (j + 2, "\n" :: acc)
                   | #"r" => go (j + 2, "\r" :: acc)
                   | #"t" => go (j + 2, "\t" :: acc)
                   | #"u" =>
                       let
                         val c = hex4 (j + 2)
                       in
                         if c >= 0xD800 andalso c <= 0xDBFF then
                           if at (j + 6) = #"\\" andalso at (j + 7) = #"u" then
                             let val d = hex4 (j + 8)
                             in
                               if d >= 0xDC00 andalso d <= 0xDFFF then
                                 go (j + 12, Utf8.encode (0x10000 + (c - 0xD800) * 0x400 + (d - 0xDC00)) :: acc)
                               else fail (j + 6, "a high surrogate without its low one")
                             end
                           else fail (j, "a high surrogate without its low one")
                         else if c >= 0xDC00 andalso c <= 0xDFFF then fail (j, "a low surrogate alone")
                         else go (j + 6, Utf8.encode c :: acc)
                       end
                   | _ => fail (j, "an escape that JSON does not have"))
              | c =>
                  if ord c < 0x20 then fail (j, "a control character in a string")
                  else if ord c < 0x80 then go (j + 1, String.str c :: acc)
                  else
                    (case Utf8.decode (s, j) of
                       SOME (_, k) => go (j + k, String.substring (s, j, k) :: acc)
                     | NONE => fail (j, "a string that is not UTF-8"))
        in
          go (i, [])
        end
      fun value (i, depth) =
        let val i = blanks i
        in
          case at i of
            #"{" => if depth >= maxDepth then fail (i, "nested too deeply") else members (i + 1, depth + 1)
          | #"[" => if depth >= maxDepth then fail (i, "nested too deeply") else elements (i + 1, depth + 1)
          | #"\"" => let val (str, j) = string (i + 1) in (String str, j) end
          | #"t" => literal (i, "true", Bool true)
          | #"f" => literal (i, "false", Bool false)
          | #"n" => literal (i, "null", Null)
          | _ =>
              let val j = numberEnd (s, i)
              in if j < 0 then fail (i, "expected a value") else (Number (String.substring (s, i, j - i)), j) end
        end
      and elements (i, depth) =
        let
          val i = blanks i
          fun more (j, acc) =
            let val j = blanks j
            in
              case at j of
                #"," => let val (v, k) = value (j + 1, depth) in more (k, v :: acc) end
              | #"]" => (Array (rev acc), j + 1)
              | _ => fail (j, "expected , or ]")
            end
        in
          if at i = #"]" then (Array [], i + 1)
          else let val (v, j) = value (i, depth) in more (j, [v]) end
        end
      and members (i, depth) =
        let
          fun member j =
            let val j = blanks j
            in
              if at j <> #"\"" then fail (j, "expected a name in quotes")
              else
                let
                  val (name, k) = string (j + 1)
                  val k = blanks k
                in
                  if at k <> #":" then fail (k, "expected :")
                  else let val (v, l) = value (k + 1, depth) in ((name, v), l) end
                end
            end
          fun more (j, acc) =
            let val j = blanks j
            in
              case at j of
                #"," => let val (m, k) = member (j + 1) in more (k, m :: acc) end
              | #"}" => (Object (rev acc), j + 1)
              | _ => fail (j, "expected , or }")
            end
          val i = blanks i
        in
          if at i = #"}" then (Object [], i + 1)
          else let val (m, j) = member i in more (j, [m]) end
        end
      val (v, i) = value (0, 0)
      val i = blanks i
    in
      if i < n then fail (i, "text after the value") else v
    end

  (* a string in quotes, with what the RFC requires escaped; a byte that
     is not part of the string's UTF-8 is written as the character of its
     value, \u00XX, since JSON text holds characters and not bytes *)
  fun escape str =
    let
      fun hex b = "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX b)
      fun esc c =
        case c of
          #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | #"\r" => "\\r"
        | #"\t" => "\\t" | #"\b" => "\\b" | #"\f" => "\\f"
        | c => if ord c < 0x20 then hex (ord c) else String.str c
      val n = size str
      (* the pieces from byte i, where the UTF-8 is not valid throughout *)
      fun pieces (i, acc) =
        if i >= n then String.concat (rev acc)
        else
          let val c = String.sub (str, i)
          in
            if ord c < 0x80 then pieces (i + 1, esc c :: acc)
            else
              case Utf8.decode (str, i) of
                SOME (_, k) => pieces (i + k, String.substring (str, i, k) :: acc)
              | NONE => pieces (i + 1, hex (ord c) :: acc)
          end
    in
      "\"" ^ (if Utf8.isValid str then String.translate esc str else pieces (0, [])) ^ "\""
    end

  fun number str = if size str > 0 andalso numberEnd (str, 0) = size str then str else raise Domain

  (* write v; indent is NONE for compact text, SOME (step, level) otherwise *)
  fun write indent v =
    let
      fun line (SOME (step, level)) = "\n" ^ CharVector.tabulate (step * level, fn _ => #" ")
        | line NONE = ""
      fun deeper (SOME (step, level)) = SOME (step, level + 1)
        | deeper NONE = NONE
      val colon = if isSome indent then ": " else ":"
      fun many (opening, closing, items, f) =
        case items of
          [] => opening ^ closing
        | _ => opening ^ String.concatWith "," (map (fn x => line (deeper indent) ^ f x) items)
               ^ line indent ^ closing
    in
      case v of
        Null => "null"
      | Bool true => "true"
      | Bool false => "false"
      | Number str => number str
      | String str => escape str
      | Array vs => many ("[", "]", vs, write (deeper indent))
      | Object ms => many ("{", "}", ms, fn (k, x) => escape k ^ colon ^ write (deeper indent) x)
    end

  val encode = write NONE
  fun encodeIndented step = write (SOME (step, 0))

  fun int i = Number (if i < 0 then "-" ^ Int.toString (~ i) else Int.toString i)
    handle Overflow => Number ("-" ^ String.extract (Int.toString i, 1, NONE))

  fun toInt (Number str) =
        if CharVector.all (fn c => isDigit c orelse c = #"-") str andalso size str > 0 then
          (Int.fromString (if String.sub (str, 0) = #"-" then "~" ^ String.extract (str, 1, NONE) else str)
           handle Overflow => NONE)
        else NONE
    | toInt _ = NONE

  fun member (name, Object ms) = Option.map #2 (List.find (fn (k, _) => k = name) ms)
    | member _ = NONE
end

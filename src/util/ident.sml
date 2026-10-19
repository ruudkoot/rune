(* The one definition of an identifier's characters (docs/plans/utf8.md,
   D10 and M6), which the lexer and every other place that takes a name
   from a text use: the REPL's printer, highlighter, completion, line
   scanner, commands and debugger, the Jupyter kernel and runedoc.

   An alphanumeric identifier is ASCII by default. Under --unicode it may
   hold the code points of the profile of lib/unicode's Identifier: XID
   less the default ignorables and the lookalikes of Standard ML's
   punctuation and digits, frozen at Unicode 18.0.0, and it is in NFC.
   Symbolic identifiers, labels and numbers stay ASCII. A name the lexer
   took is the bytes of its span, so the places that scan a text for names
   take every byte above 127 for a part of one: the lexer has checked it,
   by the profile, where it is one. *)
structure Ident =
struct
  (* an ASCII character that may begin an alphanumeric identifier *)
  fun isStartAscii (c : char) : bool = Char.isAlpha c

  (* an ASCII character that may follow in one *)
  fun isContinueAscii (c : char) : bool = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"

  (* a byte of a name in a text: an ASCII character of an alphanumeric
     identifier, or a byte of a character above 127 *)
  fun isNameByte (c : char) : bool = isContinueAscii c orelse Char.ord c >= 128

  (* a byte that may begin a name in a text *)
  fun isStartByte (c : char) : bool = Char.isAlpha c orelse Char.ord c >= 128

  (* a code point that may begin or follow in an alphanumeric identifier
     under --unicode (Identifier's profile) *)
  fun isStart (c : int) : bool = Identifier.isStart c
  fun isContinue (c : int) : bool = Identifier.isContinue c

  (* whether a name is alphanumeric: of ASCII as Standard ML has it, or of
     the profile *)
  fun isAlphanumeric (name : string) : bool =
    name <> ""
    andalso (if CharVector.all (fn c => Char.ord c < 128) name
             then isStartAscii (String.sub (name, 0)) andalso CharVector.all isContinueAscii name
             else Identifier.isAlphanumeric name)

  (* whether a name is symbolic: what an alphanumeric one cannot begin as *)
  fun isSymbolic (name : string) : bool = name <> "" andalso not (isStartByte (String.sub (name, 0)))

  (* why the profile refuses a code point that XID_Continue holds, in the
     words of an error: SOME the reason, or NONE where it does not *)
  fun refusal (c : int) : string option =
    case Identifier.exclusion c of
      SOME Identifier.Ignorable => SOME "a default ignorable character, which shows nothing"
    | SOME (Identifier.Lookalike p) => SOME ("a lookalike of " ^ String.str p)
    | NONE => NONE

  (* A name spelt in ASCII alone, for an anchor (D14): a character above
     127 as u and its code point in lowercase hexadecimal, so that the
     name U+03BB is u3bb; ASCII as it is *)
  fun asciiSpelling (name : string) : string =
    if CharVector.all (fn c => Char.ord c < 128) name then name
    else
      String.concat (List.rev (Utf8.foldl (fn (c, acc) =>
                                             (if c < 128 then String.str (Char.chr c)
                                              else "u" ^ String.map Char.toLower (Int.fmt StringCvt.HEX c)) :: acc)
                                          [] name))
end

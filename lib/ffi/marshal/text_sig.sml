(* Explicit foreign text boundaries with preserved Windows code units.

   Area: Foreign interfaces *)
signature FOREIGN_TEXT =
sig
  (* Bytes are uninterpreted; UTF-16 consumes and produces WTF-8 SML text. *)
  datatype encoding = Bytes | Utf8 | Wtf8 | Utf16
  (* A byte position and the reason conversion cannot satisfy its policy. *)
  exception Error of {offset : int, message : string}
  (* `encode {encoding, littleEndian, terminated, text}` copies native text.

     UTF-8 is strict. WTF-8 permits lone surrogates; UTF-16 preserves them.
     Terminated text rejects embedded NUL and appends a native terminator. *)
  val encode : {encoding : encoding, littleEndian : bool, terminated : bool, text : string} -> string
  (* `decode {encoding, littleEndian, terminated, bytes}` reads bounded text.

     Terminated input must contain a terminator within these bytes. UTF-16
     pairs become scalar UTF-8; lone surrogate code units remain WTF-8.
     Odd UTF-16 byte counts and malformed UTF-8/WTF-8 raise `Error`. *)
  val decode : {encoding : encoding, littleEndian : bool, terminated : bool, bytes : string} -> string
end

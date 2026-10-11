(* Bytes written as hexadecimal digits, two to a byte, and read back.

   Area: Digests *)
signature HEX =
sig
  (* `fromBytes s` is the bytes of `s` as lower-case hexadecimal.

     Example: `fromBytes "\001\171" = "01ab"` *)
  val fromBytes : string -> string

  (* `toBytes h` is the bytes that the hexadecimal `h` writes, in either
     case, or `NONE` when `h` has an odd length or a character that is no
     hexadecimal digit.

     Law: `toBytes (fromBytes s) = SOME s`

     Example: `toBytes "01AB" = SOME "\001\171" andalso toBytes "1" = NONE` *)
  val toBytes : string -> string option
end

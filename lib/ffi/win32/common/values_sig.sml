(* Portable integer projections of the selected Windows SDK macros.

   Area: Foreign interfaces *)
signature WIN32_VALUES =
sig
  (* `lowWord value` implements `LOWORD`, retaining bits zero through fifteen. *)
  val lowWord : Word64.word -> Word16.word
  (* `highWord value` implements `HIWORD`, retaining bits sixteen through thirty-one. *)
  val highWord : Word64.word -> Word16.word
  (* `rgb {red, green, blue}` implements `RGB` for explicit byte components.

     `Word8.word` makes the macro's byte projection explicit in the SML type. *)
  val rgb : {red : Word8.word, green : Word8.word, blue : Word8.word} -> Word32.word
  (* `red colour` implements `GetRValue`, ignoring other and palette bits. *)
  val red : Word32.word -> Word8.word
  (* `green colour` implements `GetGValue`, ignoring other and palette bits. *)
  val green : Word32.word -> Word8.word
  (* `blue colour` implements `GetBValue`, ignoring other and palette bits. *)
  val blue : Word32.word -> Word8.word
  (* `xFromLParam value` implements `GET_X_LPARAM` with signed 16-bit extension. *)
  val xFromLParam : Int64.int -> int
  (* `yFromLParam value` implements `GET_Y_LPARAM` with signed 16-bit extension. *)
  val yFromLParam : Int64.int -> int
end

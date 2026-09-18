(* requires: Byte Word8 Word8Vector Word8VectorSlice Word8Array Word8ArraySlice Substring *)
(* uses: spec-sigs/BYTE.sml *)
(* Byte matches BYTE. *)
structure TestByteSig =
struct
  structure C : SPEC_BYTE = Byte
  val () = T.check ("Byte:BYTE/matches", fn () => true)
  val () = T.check ("Byte:BYTE/usable", fn () => C.byteToChar (C.charToByte #"a") = #"a")
end

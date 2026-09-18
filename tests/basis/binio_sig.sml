(* requires: BinIO Word8 Word8Vector *)
(* uses: spec-sigs/BIN_IO_IMP.sml *)
(* BinIO matches the imperative part of BIN_IO, and its element and vector
   types are Word8.word and Word8Vector.vector. *)
structure TestBinIOSig =
struct
  structure C : SPEC_BIN_IO_IMP = BinIO
  val () = T.check ("BinIO:BIN_IO/matches", fn () => true)
  val () = T.check ("BinIO:BIN_IO/vector-is-Word8Vector",
                    fn () => (Word8Vector.fromList [] : C.vector) = (Word8Vector.fromList [] : BinIO.vector))
  val () = T.check ("BinIO:BIN_IO/elem-is-Word8",
                    fn () => (Word8.fromInt 7 : C.elem) = (Word8.fromInt 7 : BinIO.elem))
end

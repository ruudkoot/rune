(* signature PACK_WORD, transcribed from https://smlfamily.github.io/Basis/pack-word.html *)
signature SPEC_PACK_WORD =
sig
  val bytesPerElem : int
  val isBigEndian : bool
  val subVec : Word8Vector.vector * int -> LargeWord.word
  val subVecX : Word8Vector.vector * int -> LargeWord.word
  val subArr : Word8Array.array * int -> LargeWord.word
  val subArrX : Word8Array.array * int -> LargeWord.word
  val update : Word8Array.array * int * LargeWord.word -> unit
end

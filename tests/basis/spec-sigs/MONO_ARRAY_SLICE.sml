(* signature MONO_ARRAY_SLICE, transcribed from
   https://smlfamily.github.io/Basis/mono-array-slice.html

   The constraints of the instances (`structure Word8ArraySlice :>
   MONO_ARRAY_SLICE where type vector = Word8Vector.vector where type
   vector_slice = Word8VectorSlice.slice where type array = Word8Array.array
   where type elem = Word8.word`, and the same for CharArraySlice with the
   Char structures and char) are in tests/basis/word8arrayslice_sig.sml and
   tests/basis/chararrayslice_sig.sml. *)
signature SPEC_MONO_ARRAY_SLICE =
sig
  type elem
  type array
  type slice
  type vector
  type vector_slice

  val length : slice -> int
  val sub : slice * int -> elem
  val update : slice * int * elem -> unit
  val full : array -> slice
  val slice : array * int * int option -> slice
  val subslice : slice * int * int option -> slice
  val base : slice -> array * int * int
  val vector : slice -> vector
  val copy : {src : slice, dst : array, di : int} -> unit
  val copyVec : {src : vector_slice, dst : array, di : int} -> unit
  val isEmpty : slice -> bool
  val getItem : slice -> (elem * slice) option
  val appi : (int * elem -> unit) -> slice -> unit
  val app : (elem -> unit) -> slice -> unit
  val modifyi : (int * elem -> elem) -> slice -> unit
  val modify : (elem -> elem) -> slice -> unit
  val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
  val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
  val findi : (int * elem -> bool) -> slice -> (int * elem) option
  val find : (elem -> bool) -> slice -> elem option
  val exists : (elem -> bool) -> slice -> bool
  val all : (elem -> bool) -> slice -> bool
  val collate : (elem * elem -> order) -> slice * slice -> order
end

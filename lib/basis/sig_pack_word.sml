(* Reading and writing a word in a vector or an array of bytes, in a fixed
   byte order.

   A structure of this signature packs words of `bytesPerElem` bytes: the
   name says how many bits and which end comes first, so `PackWord32Big` puts
   the most significant byte first and `PackWord32Little` the least. This is
   what a program uses to read a binary file or a protocol whose layout is
   given in bytes, whatever the byte order of the machine it runs on.

   Positions are counted in words, not in bytes: element `i` of a vector is
   the bytes from `bytesPerElem * i` on.

   Area: Numbers

   Status: optional

   See also: `WORD`, `PACK_REAL`, `BYTE`, `MONO_VECTOR`

   Implementation: `PackWord/sizes`. The library has `PackWord16`,
   `PackWord32` and `PackWord64`, each `Big` and `Little`. *)
signature PACK_WORD =
sig
  (* The number of bytes of one word.

     Example: `PackWord32Big.bytesPerElem = 4` *)
  val bytesPerElem : int

  (* Whether the most significant byte comes first. *)
  val isBigEndian : bool

  (* `subVec (v, i)` is the word at position `i` of the byte vector `v`, with zeros in the bits above it.

     Raises: `Subscript` if `i < 0` or if the bytes of element `i` are not
     all in `v`.

     Reading: `PackWord.subVec/Subscript-not-Overflow`. The bound is tested
     without the product `bytesPerElem * (i + 1)`, so a huge `i` raises
     `Subscript` and not `Overflow`. *)
  val subVec : Word8Vector.vector * int -> LargeWord.word

  (* `subVecX (v, i)` is the word at position `i` of `v`, with its top bit copied into the bits above it.

     Raises: `Subscript` if the bytes of element `i` are not all in `v`. *)
  val subVecX : Word8Vector.vector * int -> LargeWord.word

  (* `subArr (arr, i)` is the word at position `i` of the byte array `arr`, with zeros above it.

     Raises: `Subscript` if the bytes of element `i` are not all in `arr`. *)
  val subArr : Word8Array.array * int -> LargeWord.word

  (* `subArrX (arr, i)` is the word at position `i` of `arr`, with its top bit copied into the bits above it.

     Raises: `Subscript` if the bytes of element `i` are not all in `arr`. *)
  val subArrX : Word8Array.array * int -> LargeWord.word

  (* `update (arr, i, w)` writes the low `bytesPerElem` bytes of `w` at position `i` of `arr`.

     What does not fit in that many bytes is dropped.

     Raises: `Subscript` if the bytes of element `i` are not all in `arr`. *)
  val update : Word8Array.array * int * LargeWord.word -> unit
end

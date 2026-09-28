(* Reading and writing a real number in a vector or an array of bytes, in its
   IEEE 754 encoding and a fixed byte order.

   `PackRealBig` writes the most significant byte of the encoding first and
   `PackRealLittle` the least, so a program can read or write a binary file
   whose layout is given, whatever the byte order of the machine. The bytes
   are the encoding itself: the sign, the exponent and the significand as
   IEEE 754 lays them out.

   Area: Numbers

   Status: optional

   See also: `REAL`, `PACK_WORD`, `BYTE`, `IEEE_REAL`

   Implementation: `PackReal/encodings`. `PackReal` and `PackReal64` write
   the 8 bytes of binary64; `PackReal32` the 4 bytes of binary32, and a NaN
   becomes the quiet NaN of its sign, so a payload is lost. *)
signature PACK_REAL =
sig
  (* The type of the reals this structure packs: `Real.real` for `PackReal`, `Real32.real` for `PackReal32`. *)
  type real

  (* The number of bytes of one real: 8 for binary64, 4 for binary32.

     Example: `PackReal64Big.bytesPerElem = 8` *)
  val bytesPerElem : int

  (* Whether the most significant byte of the encoding comes first.

     Example: `PackReal64Little.isBigEndian = false` *)
  val isBigEndian : bool

  (* `toBytes r` is the encoding of `r` as a vector of `bytesPerElem` bytes.

     Example: `PackReal64Big.toBytes 1.0 = Word8Vector.fromList [0wx3F, 0wxF0,
     0w0, 0w0, 0w0, 0w0, 0w0, 0w0]` *)
  val toBytes : real -> Word8Vector.vector

  (* `fromBytes v` is the real whose encoding is the bytes of `v`.

     Raises: `Subscript` if `v` has fewer than `bytesPerElem` bytes; a longer
     vector is read from its start.

     Law: `fromBytes (toBytes r) = r`, except that a NaN comes back as some
     NaN

     Example: `Real.== (PackReal64Little.fromBytes (PackReal64Little.toBytes
     2.5), 2.5) = true` *)
  val fromBytes : Word8Vector.vector -> real

  (* `subVec (v, i)` is the real at position `i` of the byte vector `v`, counting in reals.

     Its bytes are those from `bytesPerElem * i` up to `bytesPerElem * (i + 1)`.

     Raises: `Subscript` if `i < 0` or `v` is shorter than `bytesPerElem * (i
     + 1)`, a product that is taken without overflowing, so that a huge `i`
     raises `Subscript` as well.

     Example: `Real.== (PackReal64Big.subVec (Word8Vector.concat
     [PackReal64Big.toBytes 0.5, PackReal64Big.toBytes 1.5], 1), 1.5) = true`

     Example: `Real.== (PackReal64Big.subVec (PackReal64Big.toBytes 1.0, valOf
     Int.maxInt) handle Subscript => ~1.0, ~1.0) = true` *)
  val subVec : Word8Vector.vector * int -> real

  (* `subArr (arr, i)` is the real at position `i` of the byte array `arr`.

     Raises: `Subscript` if `i < 0` or `arr` is shorter than `bytesPerElem *
     (i + 1)`.

     Example: `Real.== (PackReal64Little.subArr (Word8Array.tabulate (8, fn _ =>
     0w0), 0), 0.0) = true` *)
  val subArr : Word8Array.array * int -> real

  (* `update (arr, i, r)` writes the encoding of `r` at position `i` of `arr`.

     Raises: `Subscript` if `i < 0` or `arr` is shorter than `bytesPerElem *
     (i + 1)`.

     Law: `(update (arr, i, r); subArr (arr, i)) = r`, except that a NaN comes
     back as some NaN

     Example: `let val a = Word8Array.array (8, 0w0) in PackReal64Little.update
     (a, 0, 1.0); Word8Array.sub (a, 7) end = 0wx3F` *)
  val update : Word8Array.array * int * real -> unit
end

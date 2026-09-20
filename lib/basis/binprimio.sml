(* BinPrimIO: readers and writers of bytes.

   Implements: PRIM_IO where type array = Word8Array.array where type vector =
   Word8Vector.vector where type elem = Word8.word where type pos =
   Position.int *)
structure BinPrimIO =
  RunePrimIOFn (structure V = Word8Vector
                structure A = Word8Array
                structure VS = Word8VectorSlice
                structure AS = Word8ArraySlice
                val someElem = RuneFile.zeroByte
                type pos = Position.int
                val compare = Position.compare
                val index = SOME {fromInt = Position.fromInt, toInt = Position.toInt})

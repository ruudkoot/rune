(* BinPrimIO: readers and writers of bytes. *)
structure BinPrimIO =
  RunePrimIOFn (structure V = Word8Vector
                structure A = Word8Array
                structure VS = Word8VectorSlice
                structure AS = Word8ArraySlice
                val someElem = RuneFile.zeroByte
                type pos = Position.int
                val compare = Position.compare
                val index = SOME {fromInt = Position.fromInt, toInt = Position.toInt})

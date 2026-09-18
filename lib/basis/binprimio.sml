(* BinPrimIO: readers and writers of bytes. *)
structure BinPrimIO =
  RunePrimIOFn (structure V = Word8Vector
                structure A = Word8Array
                structure VS = Word8VectorSlice
                structure AS = Word8ArraySlice
                val someElem = RuneFile.zeroByte)

(* TextPrimIO: readers and writers of characters.

   Implements: PRIM_IO where type array = CharArray.array where type vector =
   CharVector.vector where type elem = Char.char *)
structure TextPrimIO =
  RunePrimIOFn (structure V = CharVector
                structure A = CharArray
                structure VS = CharVectorSlice
                structure AS = CharArraySlice
                val someElem = #"\000"
                type pos = Position.int
                val compare = Position.compare
                val index = SOME {fromInt = Position.fromInt, toInt = Position.toInt})

(* TextPrimIO: readers and writers of characters. *)
structure TextPrimIO =
  RunePrimIOFn (structure V = CharVector
                structure A = CharArray
                structure VS = CharVectorSlice
                structure AS = CharArraySlice
                val someElem = #"\000"
                type pos = Position.int
                val compare = Position.compare
                val index = SOME {fromInt = Position.fromInt, toInt = Position.toInt})

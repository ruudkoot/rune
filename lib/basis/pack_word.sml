(* PackWord<N>Big and PackWord<N>Little: words of N bits in the bytes of
   Word8 vectors and arrays, most significant byte first (big) or last. *)
functor RunePackWordFn (val bytesPerElem : int val isBigEndian : bool) =
struct
  val bytesPerElem = bytesPerElem
  val isBigEndian = isBigEndian
  local
    val bits = Word.fromInt (Int.* (8, bytesPerElem))
    (* where the k-th byte (0 the least significant) of element i is *)
    fun place (i, k) =
      Int.+ (Int.* (bytesPerElem, i), if isBigEndian then Int.- (Int.- (bytesPerElem, 1), k) else k)
    (* "Subscript if i < 0 or if length < bytesPerElem * (i + 1)" *)
    fun check (length, i) =
      if Int.< (i, 0) orelse Int.< (length, Int.* (bytesPerElem, Int.+ (i, 1))) then raise Subscript else ()
    fun get sub (seq, i) =
      let
        fun go (k, w) =
          if Int.< (k, 0) then w
          else go (Int.- (k, 1), Word.orb (Word.<< (w, 0w8), Word8.toLarge (sub (seq, place (i, k)))))
      in go (Int.- (bytesPerElem, 1), 0w0) end
    (* "extends the sign bit (most significant bit)" *)
    fun extend w =
      if Word.>= (bits, Word.fromInt Word.wordSize) then w
      else if Word.andb (w, Word.<< (0w1, Word.- (bits, 0w1))) <> 0w0
      then Word.orb (w, Word.notb (Word.- (Word.<< (0w1, bits), 0w1)))
      else w
  in
    fun subVec (v, i) = (check (Word8Vector.length v, i); get Word8Vector.sub (v, i))
    fun subVecX (v, i) = extend (subVec (v, i))
    fun subArr (a, i) = (check (Word8Array.length a, i); get Word8Array.sub (a, i))
    fun subArrX (a, i) = extend (subArr (a, i))
    (* "stores the bytesPerElem low-order bytes of the word w" *)
    fun update (a, i, w) =
      let
        fun go k =
          if Int.>= (k, bytesPerElem) then ()
          else (Word8Array.update (a, place (i, k), Word8.fromLarge (Word.>> (w, Word.fromInt (Int.* (8, k)))));
                go (Int.+ (k, 1)))
      in check (Word8Array.length a, i); go 0 end
  end
end

structure PackWord16Big = RunePackWordFn (val bytesPerElem = 2 val isBigEndian = true)
structure PackWord16Little = RunePackWordFn (val bytesPerElem = 2 val isBigEndian = false)
structure PackWord32Big = RunePackWordFn (val bytesPerElem = 4 val isBigEndian = true)
structure PackWord32Little = RunePackWordFn (val bytesPerElem = 4 val isBigEndian = false)
structure PackWord64Big = RunePackWordFn (val bytesPerElem = 8 val isBigEndian = true)
structure PackWord64Little = RunePackWordFn (val bytesPerElem = 8 val isBigEndian = false)

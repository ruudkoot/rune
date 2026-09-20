(* PackRealBig and PackRealLittle, and PackReal64Big and PackReal64Little
   (Real64 is Real): the 8 bytes of IEEE 754 binary64, most significant
   byte first (big) or last. *)
functor RunePackRealFn (val isBigEndian : bool) =
struct
  type real = Real.real
  val bytesPerElem = 8
  val isBigEndian = isBigEndian
  local
    val toBits = _prim "real_to_bits" : real -> word
    val fromBits = _prim "real_from_bits" : word -> real
    structure W = RunePackWordFn (val bytesPerElem = 8 val isBigEndian = isBigEndian)
  in
    fun toBytes r =
      let val a = Word8Array.array (8, Word8.fromInt 0)
      in W.update (a, 0, toBits r); Word8Array.vector a end
    (* "Subscript if the argument vector does not have length at least
       bytesPerElem; otherwise the first bytesPerElem bytes are used" *)
    fun fromBytes v = fromBits (W.subVec (v, 0))
    fun subVec (v, i) = fromBits (W.subVec (v, i))
    fun subArr (a, i) = fromBits (W.subArr (a, i))
    fun update (a, i, r) = W.update (a, i, toBits r)
  end
end

structure PackRealBig = RunePackRealFn (val isBigEndian = true)
structure PackRealLittle = RunePackRealFn (val isBigEndian = false)
structure PackReal64Big = PackRealBig
structure PackReal64Little = PackRealLittle

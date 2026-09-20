(* PackReal32Big and PackReal32Little: the 4 bytes of IEEE 754 binary32,
   most significant byte first (big) or last. The bits are worked out from the
   value (a binary64 that binary32 represents) with toManExp, so a NaN is
   packed as the quiet NaN of its sign. *)
functor RunePackReal32Fn (val isBigEndian : bool) =
struct
  type real = Real32.real
  val bytesPerElem = 4
  val isBigEndian = isBigEndian
  local
    structure W = RunePackWordFn (val bytesPerElem = 4 val isBigEndian = isBigEndian)
    fun toBits (r : real) : word =
      let
        val x = Real32.toLarge r
        val body =
          if Real.isNan x then 0wx7FC00000
          else if not (Real.isFinite x) then 0wx7F800000
          else if Real.== (x, 0.0) then 0w0
          else
            let val {man, exp} = Real.toManExp (Real.abs x)   (* 1/2 <= man < 1 *)
            in
              if exp >= ~125 then
                Word.orb (Word.<< (Word.fromInt (exp + 126), 0w23),
                          Word.fromInt (Real.trunc (Real.fromManExp {man = man, exp = 24}) - 8388608))
              else Word.fromInt (Real.trunc (Real.fromManExp {man = Real.abs x, exp = 149}))
            end
      in if Real.signBit x then Word.orb (0wx80000000, body) else body end
    fun fromBits (w : word) : real =
      let
        val e = Word.toInt (Word.andb (Word.>> (w, 0w23), 0wxFF))
        val f = Word.toInt (Word.andb (w, 0wx7FFFFF))
        val a =
          if e = 255 then (if f = 0 then Real.posInf else Real.- (Real.posInf, Real.posInf))
          else if e = 0 then Real.fromManExp {man = Real.fromInt f, exp = ~149}
          else Real.fromManExp {man = Real.fromInt (f + 8388608), exp = e - 150}
        val x = if Word.andb (w, 0wx80000000) = 0w0 then a else Real.~ a
      in Real32.fromLarge IEEEReal.TO_NEAREST x end   (* exact *)
  in
    fun toBytes r =
      let val a = Word8Array.array (4, Word8.fromInt 0)
      in W.update (a, 0, toBits r); Word8Array.vector a end
    (* "Subscript if the argument vector does not have length at least
       bytesPerElem; otherwise the first bytesPerElem bytes are used" *)
    fun fromBytes v = fromBits (W.subVec (v, 0))
    fun subVec (v, i) = fromBits (W.subVec (v, i))
    fun subArr (a, i) = fromBits (W.subArr (a, i))
    fun update (a, i, r) = W.update (a, i, toBits r)
  end
end

(* Implements: PACK_REAL where type real = Real32.real

   Status: optional *)
structure PackReal32Big = RunePackReal32Fn (val isBigEndian = true)
(* Implements: PACK_REAL where type real = Real32.real

   Status: optional *)
structure PackReal32Little = RunePackReal32Fn (val isBigEndian = false)

(* MurmurHash2, 32 bits: the bytes four at a time, little-endian, each
   mixed by the constant m into the hash, which began as the seed and the
   length; the last one to three bytes; the hash mixed once more. As
   ipykernel's murmur2_x86, which JupyterLab's debugger names cells by. *)
structure Murmur2 :> MURMUR2 =
struct
  val m : Word32.word = 0wx5BD1E995

  fun byte (s : string, i : int) : Word32.word = Word32.fromInt (Char.ord (String.sub (s, i)))

  fun hash {seed : Word32.word, data : string} : Word32.word =
    let
      val n = String.size data
      val whole = n - n mod 4
      fun blocks (i, h) =
        if i >= whole then h
        else
          let
            val k = Word32.orb (Word32.orb (byte (data, i), Word32.<< (byte (data, i + 1), 0w8)),
                                Word32.orb (Word32.<< (byte (data, i + 2), 0w16), Word32.<< (byte (data, i + 3), 0w24)))
            val k = Word32.* (k, m)
            val k = Word32.xorb (k, Word32.>> (k, 0w24))
            val k = Word32.* (k, m)
          in blocks (i + 4, Word32.xorb (Word32.* (h, m), k)) end
      val h = blocks (0, Word32.xorb (seed, Word32.fromInt n))
      val h =
        case n mod 4 of
          0 => h
        | r =>
            let
              val k = if r = 3 then Word32.<< (byte (data, whole + 2), 0w16) else 0w0
              val k = if r >= 2 then Word32.orb (k, Word32.<< (byte (data, whole + 1), 0w8)) else k
              val k = Word32.orb (k, byte (data, whole))
            in Word32.* (Word32.xorb (h, k), m) end
      val h = Word32.xorb (h, Word32.>> (h, 0w13))
      val h = Word32.* (h, m)
    in
      Word32.xorb (h, Word32.>> (h, 0w15))
    end
end

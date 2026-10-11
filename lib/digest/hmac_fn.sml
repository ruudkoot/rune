(* HmacFn: HMAC over a hash function; HmacSha256 is it over Sha256.

   Implements: HMAC *)
functor HmacFn (structure Hash : DIGEST) :> HMAC =
struct
  val size = Hash.size

  fun pad (key, byte) =
    let
      val key = if String.size key > Hash.blockSize then Hash.digest key else key
      val key = key ^ CharVector.tabulate (Hash.blockSize - String.size key, fn _ => #"\000")
    in
      String.map (fn c => Char.chr (Word.toInt (Word.xorb (Word.fromInt (Char.ord c), byte)))) key
    end

  fun macParts {key, parts} =
    let
      val inner = Hash.finish (foldl (fn (p, c) => Hash.update (c, p)) (Hash.update (Hash.empty, pad (key, 0wx36))) parts)
    in
      Hash.finish (Hash.update (Hash.update (Hash.empty, pad (key, 0wx5c)), inner))
    end

  fun mac {key, message} = macParts {key = key, parts = [message]}

  fun equal (a, b) =
    String.size a = String.size b
    andalso
      let
        fun go (i, acc) =
          if i = String.size a then acc = 0w0
          else go (i + 1, Word.orb (acc, Word.xorb (Word.fromInt (Char.ord (String.sub (a, i))),
                                                   Word.fromInt (Char.ord (String.sub (b, i))))))
      in
        go (0, 0w0)
      end
end

(* HmacSha256: HMAC-SHA-256, the code RFC 4231's vectors check.

   Implements: HMAC *)
structure HmacSha256 = HmacFn (structure Hash = Sha256)

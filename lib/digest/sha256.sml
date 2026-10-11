(* Sha256: SHA-256 of FIPS 180-4, on Word32.

   Implements: DIGEST *)
structure Sha256 :> DIGEST =
struct
  val name = "SHA-256"
  val size = 32
  val blockSize = 64

  (* the eight words of the hash, the bytes not yet a block, and how many
     bytes have been read *)
  type context = {h : Word32.word vector, pending : string, length : int}

  val k : Word32.word vector = Vector.fromList [
    0wx428a2f98, 0wx71374491, 0wxb5c0fbcf, 0wxe9b5dba5, 0wx3956c25b, 0wx59f111f1, 0wx923f82a4, 0wxab1c5ed5,
    0wxd807aa98, 0wx12835b01, 0wx243185be, 0wx550c7dc3, 0wx72be5d74, 0wx80deb1fe, 0wx9bdc06a7, 0wxc19bf174,
    0wxe49b69c1, 0wxefbe4786, 0wx0fc19dc6, 0wx240ca1cc, 0wx2de92c6f, 0wx4a7484aa, 0wx5cb0a9dc, 0wx76f988da,
    0wx983e5152, 0wxa831c66d, 0wxb00327c8, 0wxbf597fc7, 0wxc6e00bf3, 0wxd5a79147, 0wx06ca6351, 0wx14292967,
    0wx27b70a85, 0wx2e1b2138, 0wx4d2c6dfc, 0wx53380d13, 0wx650a7354, 0wx766a0abb, 0wx81c2c92e, 0wx92722c85,
    0wxa2bfe8a1, 0wxa81a664b, 0wxc24b8b70, 0wxc76c51a3, 0wxd192e819, 0wxd6990624, 0wxf40e3585, 0wx106aa070,
    0wx19a4c116, 0wx1e376c08, 0wx2748774c, 0wx34b0bcb5, 0wx391c0cb3, 0wx4ed8aa4a, 0wx5b9cca4f, 0wx682e6ff3,
    0wx748f82ee, 0wx78a5636f, 0wx84c87814, 0wx8cc70208, 0wx90befffa, 0wxa4506ceb, 0wxbef9a3f7, 0wxc67178f2]

  val empty : context =
    {h = Vector.fromList [0wx6a09e667, 0wxbb67ae85, 0wx3c6ef372, 0wxa54ff53a,
                          0wx510e527f, 0wx9b05688c, 0wx1f83d9ab, 0wx5be0cd19],
     pending = "", length = 0}

  (* the sum of words, modulo 2^32 *)
  infix 6 ++
  fun a ++ b = Word32.+ (a, b)
  val andb = Word32.andb
  val orb = Word32.orb
  val xorb = Word32.xorb
  val notb = Word32.notb
  fun rotr (x, n) = orb (Word32.>> (x, Word.fromInt n), Word32.<< (x, Word.fromInt (32 - n)))
  fun shr (x, n) = Word32.>> (x, Word.fromInt n)

  (* the hash after the block of s that begins at i *)
  fun compress (h : Word32.word vector, s : string, i : int) =
    let
      val w = Array.array (64, 0w0 : Word32.word)
      fun byte j = Word32.fromInt (Char.ord (String.sub (s, i + j)))
      fun load t =
        if t < 16 then
          (Array.update (w, t, orb (orb (Word32.<< (byte (4 * t), 0w24), Word32.<< (byte (4 * t + 1), 0w16)),
                                    orb (Word32.<< (byte (4 * t + 2), 0w8), byte (4 * t + 3))));
           load (t + 1))
        else if t < 64 then
          let
            val x = Array.sub (w, t - 15)
            val y = Array.sub (w, t - 2)
            val s0 = xorb (xorb (rotr (x, 7), rotr (x, 18)), shr (x, 3))
            val s1 = xorb (xorb (rotr (y, 17), rotr (y, 19)), shr (y, 10))
          in
            Array.update (w, t, Array.sub (w, t - 16) ++ s0 ++ Array.sub (w, t - 7) ++ s1);
            load (t + 1)
          end
        else ()
      val () = load 0
      fun round (t, a, b, c, d, e, f, g, hh) =
        if t = 64 then (a, b, c, d, e, f, g, hh)
        else
          let
            val s1 = xorb (xorb (rotr (e, 6), rotr (e, 11)), rotr (e, 25))
            val ch = xorb (andb (e, f), andb (notb e, g))
            val t1 = hh ++ s1 ++ ch ++ Vector.sub (k, t) ++ Array.sub (w, t)
            val s0 = xorb (xorb (rotr (a, 2), rotr (a, 13)), rotr (a, 22))
            val maj = xorb (xorb (andb (a, b), andb (a, c)), andb (b, c))
            val t2 = s0 ++ maj
          in
            round (t + 1, t1 ++ t2, a, b, c, d ++ t1, e, f, g)
          end
      fun hv j = Vector.sub (h, j)
      val (a, b, c, d, e, f, g, hh) = round (0, hv 0, hv 1, hv 2, hv 3, hv 4, hv 5, hv 6, hv 7)
    in
      Vector.fromList [hv 0 ++ a, hv 1 ++ b, hv 2 ++ c, hv 3 ++ d, hv 4 ++ e, hv 5 ++ f, hv 6 ++ g, hv 7 ++ hh]
    end

  fun update ({h, pending, length} : context, s) =
    let
      val all = pending ^ s
      val blocks = String.size all div 64
      fun go (j, h) = if j = blocks then h else go (j + 1, compress (h, all, 64 * j))
    in
      {h = go (0, h), pending = String.extract (all, 64 * blocks, NONE), length = length + String.size s}
    end

  fun wordBytes x =
    String.implode (map (fn n => Char.chr (Word32.toInt (andb (shr (x, n), 0wxFF)))) [24, 16, 8, 0])

  (* the padding: 0x80, zeros, and the length in bits as 64 bits *)
  fun finish (c as {length, ...} : context) =
    let
      val zeros = (55 - length mod 64) mod 64
      val bits = IntInf.fromInt length * 8
      fun lenByte n = Char.chr (IntInf.toInt (IntInf.mod (IntInf.~>> (bits, Word.fromInt (8 * n)), 256)))
      val padding = "\128" ^ CharVector.tabulate (zeros, fn _ => #"\000")
                    ^ CharVector.tabulate (8, fn j => lenByte (7 - j))
      val {h, ...} = update (c, padding)
    in
      String.concat (map wordBytes (Vector.foldr (op ::) [] h))
    end

  fun digest s = finish (update (empty, s))
end

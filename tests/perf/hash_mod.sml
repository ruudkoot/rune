(* Pickle.hash's algorithm until functors-units M4, which made it rx2fw
   (lib/compiler/util/pickle.sml): four lanes of
   (h * k + x) mod p a byte, by literal primes -- the hashing of the
   fingerprints that took 36% of the cycles of MLton's compiler built in
   units at tier 2 while tier 2 divided by idiv (docs/plans/functors-units.md,
   M1, E7) -- here from each of eight offsets of 8 KB of printable text.
   The numbers stay below 2^30, so that every int size gives the same. *)
fun hash (s : string, from : int) : string =
  let
    val n = String.size s
    fun go (i, a, b, c, d) =
      if i = n then (a, b, c, d)
      else
        let val x = Char.ord (String.sub (s, i))
        in go (i + 1, (a * 31 + x) mod 16777213, (b * 37 + x) mod 16777199, (c * 41 + x) mod 16777183,
               (d * 43 + x) mod 16777153)
        end
    val (a, b, c, d) = go (from, 7, 11, 13, 17)
    fun hex6 n = StringCvt.padLeft #"0" 6 (Int.fmt StringCvt.HEX n)
  in
    String.map Char.toLower (hex6 a ^ hex6 b ^ hex6 c ^ hex6 d)
  end
(* the text: a linear congruential generator of 16 bits *)
val seed = ref 1
fun next () = (seed := (!seed * 75 + 74) mod 65537; !seed)
val text = CharVector.tabulate (8192, fn _ => Char.chr (32 + next () mod 95))
fun loop k = if k = 8 then () else (print (hash (text, k) ^ "\n"); loop (k + 1))
val () = loop 0

(* System.Random 1.1 cfdfe6f09ad414fde5b855cc5f90207533413241 pure subset.
   Copyright University of Glasgow 2001; BSD notice in random-1.1/LICENSE.
   IntInf preserves the source Int32 state arithmetic on 31-bit SML hosts. *)
structure BenchHaskellRandomOne =
struct
  structure I = IntInf
  type state = I.int * I.int
  fun seed n : state =
    let val s = I.andb (I.fromInt n, 2147483647)
        val (q, r) = I.divMod (s, 2147483562)
    in (I.+ (r, 1), I.+ (I.mod (q, 2147483398), 1)) end
  fun next (s1, s2) =
    let val k = I.quot (s1, 53668)
        val a = I.- (I.* (40014, I.- (s1, I.* (k, 53668))), I.* (k, 12211))
        val s1 = if I.< (a, 0) then I.+ (a, 2147483563) else a
        val k = I.quot (s2, 52774)
        val b = I.- (I.* (40692, I.- (s2, I.* (k, 52774))), I.* (k, 3791))
        val s2 = if I.< (b, 0) then I.+ (b, 2147483399) else b
        val z = I.- (s1, s2)
    in (if I.< (z, 1) then I.+ (z, 2147483562) else z, (s1, s2)) end
  fun range (lo, hi) state =
    if I.> (lo, hi) then range (hi, lo) state else
    let val k = I.+ (I.- (hi, lo), 1) val target = I.* (k, 1000)
        fun loop mag value gen =
          if I.>= (mag, target) then (I.+ (lo, I.mod (value, k)), gen)
          else let val (x, nextState) = next gen
                   val value = I.+ (I.* (value, 2147483562), I.- (x, 1))
               in loop (I.* (mag, 2147483562)) value nextState end
    in loop 1 0 state end
end

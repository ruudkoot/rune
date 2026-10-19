(* System.Random 1.1 cfdfe6f09ad414fde5b855cc5f90207533413241 pure subset.
   Copyright University of Glasgow 2001; BSD notice in random-1.1/LICENSE.
   Word32 retains source Int32 states; Schrage intermediates fit signed32.
   Random Integer range accumulation remains arbitrary precision. *)
structure BenchHaskellRandomOne =
struct
  structure I = IntInf
  structure W = Word32
  type state = W.word * W.word
  fun negative x = W.andb (x, 0wx80000000) <> 0w0
  fun seed n : state =
    let val s = W.andb (W.fromInt n, 0wx7fffffff)
        val q = W.div (s, 0w2147483562) val r = W.mod (s, 0w2147483562)
    in (W.+ (r, 0w1), W.+ (W.mod (q, 0w2147483398), 0w1)) end
  fun next (s1, s2) =
    let val k = W.div (s1, 0w53668)
        val a = W.- (W.* (0w40014, W.- (s1, W.* (k, 0w53668))), W.* (k, 0w12211))
        val s1 = if negative a then W.+ (a, 0w2147483563) else a
        val k = W.div (s2, 0w52774)
        val b = W.- (W.* (0w40692, W.- (s2, W.* (k, 0w52774))), W.* (k, 0w3791))
        val s2 = if negative b then W.+ (b, 0w2147483399) else b
        val z = W.- (s1, s2)
        val z = if negative z orelse z = 0w0 then W.+ (z, 0w2147483562) else z
    in (W.toLargeInt z, (s1, s2)) end
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

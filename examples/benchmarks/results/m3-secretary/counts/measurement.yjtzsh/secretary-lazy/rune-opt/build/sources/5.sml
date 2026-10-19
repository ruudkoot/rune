structure BenchSecretary =
struct
  structure S = BenchStream
  structure L = BenchLazy
  structure R = BenchHaskellRandomOne
  structure I = IntInf
  fun randoms state = L.delay (fn () =>
    let val (value, next) = R.range (1, 100) state
    in S.Cons (L.delay (fn () => value), randoms next) end)
  fun nub seen xs = L.delay (fn () => case L.force xs of S.Nil => S.Nil
    | S.Cons (x, rest) =>
        let val value = L.force x
        in if List.exists (fn old => value = old) seen
           then L.force (nub seen rest) else S.Cons (x, nub (value :: seen) rest) end)
  fun take 0 _ = S.empty ()
    | take n xs = L.delay (fn () => case L.force xs of S.Nil => S.Nil
      | S.Cons (x, rest) => S.Cons (x, take (n - 1) rest))
  fun drop 0 xs = xs
    | drop n xs = case L.force xs of S.Nil => S.empty () | S.Cons (_, rest) => drop (n - 1) rest
  fun lazyTrial k raw =
    let val xs = take 100 (nub [] raw)
        val best = S.foldPrefix (fn (value, old) => I.max (value, old)) 0 k xs
        val after = S.dropWhile (fn value => I.< (value, best)) (drop k xs)
    in case L.force after of S.Nil => false | S.Cons (value, _) => L.force value = 100 end
  fun strictPermutation draw gen =
    let fun collect 0 _ _ = []
          | collect n seen state =
              let val (value, next) = draw state
              in if List.exists (fn old => value = old) seen then collect n seen next
                 else value :: collect (n - 1) (value :: seen) next end
    in collect 100 [] gen end
  fun strictTrial k xs =
    let val best = List.foldl I.max 0 (List.take (xs, k))
        fun after [] = false | after (value :: rest) =
          if I.< (value, best) then after rest else value = 100
    in after (List.drop (xs, k)) end
  fun seeds first last = L.delay (fn () => if first > last then S.Nil
    else S.Cons (L.delay (fn () => first), seeds (first + 1) last))
  fun lazy n k =
    let val tries = S.map (fn seed => lazyTrial k (randoms (R.seed seed))) (seeds 1 n)
        val count = S.foldl (fn (_, total) => total + 1) 0 (S.filter (fn value => value) tries)
    in (count, Real.fromInt count / Real.fromInt n) end
  fun strict n k =
    let val tries = List.tabulate (n, fn seed =>
          strictTrial k (strictPermutation (R.range (1, 100)) (R.seed (seed + 1))))
        val count = List.length (List.filter (fn value => value) tries)
    in (count, Real.fromInt count / Real.fromInt n) end
end

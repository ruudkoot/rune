functor BenchIntegerFn (D : BENCH_SUSPEND) =
struct
  structure S = BenchCellSequenceFn (D)
  structure W = Word64
  structure I = IntInf
  structure M = BenchSigned64
  fun bool true : W.word = 0w1 | bool false = 0w0
  fun bigGcd (a, b) =
    let fun loop (x, y) = if y = 0 then x else loop (y, I.mod (x, y))
    in loop (I.abs a, I.abs b) end
  fun bigLcm (a, b) = if a = 0 orelse b = 0 then 0 else I.abs (I.* (I.quot (a, bigGcd (a, b)), b))
  val machine = [W.+, W.-, W.*, M.divide, M.modulo, M.quotient, M.remainder, M.gcd, M.lcm,
    fn (a, b) => bool (a = b), fn pair => bool (M.less pair), fn pair => bool (M.leq pair),
    fn (a, b) => bool (M.less (b, a)), fn (a, b) => bool (M.leq (b, a))]
  val arbitrary = List.map (fn f => fn pair => W.fromLargeInt (f pair))
    [I.+, I.-, I.*, I.div, I.mod, I.quot, I.rem, bigGcd, bigLcm] @
    [fn (a : I.int, b) => bool (a = b), fn (a, b) => bool (I.< (a, b)), fn (a, b) => bool (I.<= (a, b)),
     fn (a, b) => bool (I.> (a, b)), fn (a, b) => bool (I.>= (a, b))]
  fun enum plus leq (start, step, limit) = D.delay (fn () =>
    if leq (start, limit) then S.Cons (S.value start, D.delay (fn () => D.force (enum plus leq (plus (start, step), step, limit)))) else S.Nil)
  fun concatMap f xs = D.delay (fn () => case D.force xs of S.Nil => S.Nil
    | S.Cons (x, rest) => D.force (S.append (f (D.force x)) (concatMap f rest)))
  fun pairs opn plus leq (start, step, limit) =
    concatMap (fn a => S.map (fn b => opn (a, b)) (enum plus leq (start, step, limit)))
      (enum plus leq (start, step, limit))
  fun consume values =
    let fun loop xs count hash = case D.force xs of S.Nil => (count, hash)
          | S.Cons (x, rest) =>
              let val value = D.force x
              in loop rest (count + 1) (W.+ (W.* (hash, 0w1664525), value)) end
    in loop values 0 0w1013904223 end
  fun run (start : I.int, step : I.int, limit : I.int) =
    let val machineRange = (W.fromLargeInt start, W.fromLargeInt step, W.fromLargeInt limit)
        fun jobs ([], []) = []
          | jobs (m :: ms, b :: bs) =
              let val machineResult = consume (pairs m W.+ M.leq machineRange)
                  val arbitraryResult = consume (pairs b I.+ I.<= (start, step, limit))
              in machineResult :: arbitraryResult :: jobs (ms, bs) end
          | jobs _ = raise Fail "integer operation table mismatch"
    in jobs (machine, arbitrary) end
end

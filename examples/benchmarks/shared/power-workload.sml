functor BenchPowerWorkloadFn (TreeNumber : BENCH_POWER_NUMBER) =
struct
  structure R = BenchPowerFn (BenchPowerRational)
  structure I = BenchPowerFn (TreeNumber)
  structure L = BenchLazy
  structure S = BenchStream
  (* Retain shared sine/cosine, Catalan, geometric and tree-series knots. *)
  val cosine : R.series option ref = ref NONE
  val sinx = L.delay (fn () => L.force (R.integral (valOf (!cosine))))
  val cosx = R.subtract R.one (R.integral sinx)
  val _ = cosine := SOME cosx
  val ts = S.fix (fn s => S.Cons (I.coefficient TreeNumber.one,I.square s))
  val list = S.fix (fn s => S.Cons (I.coefficient TreeNumber.one,s))
  val tree = S.fix (fn s => S.Cons (I.coefficient TreeNumber.zero,I.compose list s))
  fun output n = String.concatWith "\n" [
    R.render n (R.subtract sinx (R.squareRoot (R.subtract R.one (R.square cosx)))),
    R.render n (R.subtract (R.divide sinx cosx)
      (R.revert (R.integral (R.divide R.one (R.add R.one (R.square R.x)))))),
    I.render n ts,I.render n tree] ^ "\n"
end

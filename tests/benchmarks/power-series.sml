structure BenchPowerTests =
struct
  structure R = Benchmark.Workload.R
  structure I = Benchmark.Workload.I
  structure L = BenchLazy
  structure S = BenchStream
  val _ = T.check ("power/integral-emits-zero-before-operand", fn () => (S.head (R.integral (L.delay (fn () => raise Fail "unexpected demand"))) = (0,1)))
  val _ = T.check ("power/zero-extraction-does-not-inspect-spine", fn () => (R.render 0 (L.delay (fn () => raise Fail "unexpected demand")) = "[]"))
  val _ = T.check ("power/finite-product-has-no-extra-zero", fn () => (I.render 8 (I.multiply I.x I.x) = "[0,0,1]"))
  val _ = T.check ("power/finite-derivative", fn () => (I.render 8 (I.derivative (I.square I.x)) = "[0,2]"))
  val _ = T.check ("power/finite-integration", fn () => (R.render 8 (R.integral R.x) = "[0 % 1,0 % 1,1 % 2]"))
  val _ = T.check ("power/common-leading-zero-division", fn () => (R.render 8 (R.divide R.x R.x) = "[1 % 1]"))
  val _ = T.check ("power/zero-over-zero-fails", fn () => ((R.render 1 (R.divide R.zero R.zero);false) handle Fail _ => true))
  val _ = T.check ("power/Catalan-coefficients", fn () => (I.render 10 Benchmark.Workload.ts = "[1,1,2,5,14,42,132,429,1430,4862]"))
  val _ = T.check ("power/tree-coefficients", fn () => (I.render 10 Benchmark.Workload.tree = "[0,1,1,2,5,14,42,132,429,1430]"))
  val _ = T.check ("power/exact-sine-coefficients", fn () => (R.render 6 Benchmark.Workload.sinx = "[0 % 1,1 % 1,0 % 1,(-1) % 6,0 % 1,1 % 120]"))
  val _ = T.check ("power/exact-cosine-coefficients", fn () => (R.render 6 Benchmark.Workload.cosx = "[1 % 1,0 % 1,(-1) % 2,0 % 1,1 % 24,0 % 1]"))
  val forced = ref 0
  val shared = S.cons (L.delay (fn () => (forced := !forced+1;(3,7))),R.zero)
  val _ = T.check ("power/coefficient-sharing", fn () => (S.head shared = (3,7) andalso S.head shared = (3,7) andalso !forced=1))
  val _ = T.check ("power/division-pattern-demand-order",fn () =>
    let val numerator = S.cons(L.delay(fn () => raise Fail "numerator"),R.zero)
        val denominator = L.delay(fn () => raise Fail "denominator")
    in (R.render 1 (R.divide numerator denominator);false)
       handle Fail message => message="numerator" end)
end

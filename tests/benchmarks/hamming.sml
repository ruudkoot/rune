structure BenchHammingTests =
struct
  structure B = Benchmark
  structure L = BenchLazy
  val _ = T.check("hamming/signed-wrap",fn () =>
    B.signed 9223372036854775808 = ~9223372036854775808 andalso
    B.signed ~9223372036854775809 = 9223372036854775807)
  val _ = T.check("hamming/two-component-carry",fn () =>
    B.multiply 5 (900000000000000000,2) = (500000000000000000,14))
  val _ = T.check("hamming/high-component-overflow",fn () =>
    B.multiply 2 (0,4611686018427387904) = (0,~9223372036854775808))
  val _ = T.check("hamming/fixed-width-render",fn () =>
    B.render(42,1) = "1000000000000000042" andalso
    B.render(~42,1) = "1-00000000000000042")
  val _ = T.check("hamming/shared-merged-prefix",fn () =>
    B.interval(B.stream()) 0 20 =
      ["1","2","3","4","5","6","8","9","10","12","15","16","18","20","24","25","27","30","32","36"])
  val trace : string list ref = ref []
  fun leaf name value = L.delay(fn () =>
    (trace := !trace @ [name]; B.Cons((value,0),L.delay(fn () => raise Fail "unused merge tail"))))
  val _ = T.check("hamming/merge-force-order-and-sharing",fn () =>
    let val merged = B.merge(leaf "left" 1)(leaf "right" 1)
        val B.Cons(value,_) = L.force merged
        val _ = L.force merged
    in value=(1,0) andalso !trace=["left","right"] end)
  val calls = ref 0
  val _ = T.check("hamming/strict-mapped-head-memoized",fn () =>
    let val mapped = B.map(fn value => (calls := !calls+1;value))(leaf "mapped" 2)
        val B.Cons(value,_) = L.force mapped
        val _ = L.force mapped
    in value=(2,0) andalso !calls=1 end)
  val _ = T.check("hamming/empty-interval-no-demand",fn () =>
    B.interval(L.delay(fn () => raise Fail "unneeded stream")) 0 0 = [])
end

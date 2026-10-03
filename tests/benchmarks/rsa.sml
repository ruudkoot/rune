structure BenchRsaTests =
struct
  structure N = BenchRsaFn(BenchNeed)
  structure S = BenchRsaFn(BenchStrict)
  structure L = BenchLazy
  val absent : IntInf.int L.delay = L.delay(fn () => raise Fail "unneeded base")
  val _ = T.check("rsa/zero-exponent-demand",fn () => N.power 0 17 absent=1)
  val _ = T.check("rsa/zero-exponent-unit-modulus",fn () => N.power 0 1 absent=1)
  val _ = T.check("rsa/empty-block-code",fn () => BenchNeed.force(N.code "")=0 andalso BenchStrict.force(S.code "")=0)
  val _ = T.check("rsa/base128-code",fn () => BenchNeed.force(N.code "AB")=8386 andalso BenchStrict.force(S.code "AB")=8386)
  val _ = T.check("rsa/odd-exponent",fn () => N.power 3 17 (N.code "A")=7)
  val _ = T.check("rsa/even-exponent",fn () => N.power 4 17 (N.code "A")=13)
  val _ = T.check("rsa/empty-ciphertext",fn () => N.encrypt ""="" andalso S.encrypt ""="")
  val _ = T.check("rsa/source-block-size",fn () => N.blockSize=70 andalso S.blockSize=70)
end

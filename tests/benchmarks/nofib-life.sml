structure BenchLifeTests =
struct
  structure N = BenchNofibLifeFn(BenchNeed)
  structure S = BenchNofibLifeFn(BenchStrict)
  structure L = BenchLazy
  val centre : int L.delay = L.delay(fn () => raise Fail "unneeded centre")
  val zero = N.Q.value 0
  val one = N.Q.value 1
  val _ = T.check("life/birth-skips-centre",fn () => N.element((one,one,one),(zero,centre,zero),(zero,zero,zero))=1)
  val _ = T.check("life/death-skips-centre",fn () => N.element((zero,zero,zero),(zero,centre,zero),(zero,zero,zero))=0)
  val _ = T.check("life/survival-demands-centre",fn () =>
    ((N.element((one,one,zero),(zero,centre,zero),(zero,zero,zero));false)handle Fail _ => true))
  val vertical = [[0,0,0,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,0,0,0]]
  val horizontal = [[0,0,0,0,0],[0,0,0,0,0],[0,1,1,1,0],[0,0,0,0,0],[0,0,0,0,0]]
  fun board rows = N.Q.fromList(List.map N.Q.fromList rows)
  fun rows board = List.map N.Q.toList(N.Q.toList board)
  val _ = T.check("life/synchronous-blinker",fn () => rows(N.generation 5 (board vertical))=horizontal)
  val _ = T.check("life/blinker-second-step",fn () => rows(N.generation 5 (N.generation 5 (board vertical)))=vertical)
  val _ = T.check("life/source-fixpoint-indices",fn () => #1(N.fixpoint 5)=0 andalso #1(N.fixpoint 15)=5)
  val _ = T.check("life/lazy-strict-display",fn () => N.render(N.fixpoint 15)=S.render(S.fixpoint 15))
end

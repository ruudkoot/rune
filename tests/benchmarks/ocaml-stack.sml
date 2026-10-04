structure BenchStackTests =
struct
  structure S = BenchOcamlStack
  val _ = T.check("stack/empty",fn () => let val stack : int S.stack = S.create() in S.length stack=0 end)
  val _ = T.check("stack/pop-empty",fn () =>
    ((S.pop(S.create():int S.stack);false)handle S.Empty => true))
  val _ = T.check("stack/last-in-first-out",fn () =>
    let val stack = S.create()
        val _ = List.app(fn n => S.push n stack)[1,2,3]
    in S.length stack=3 andalso S.pop stack=3 andalso S.pop stack=2 andalso
       S.pop stack=1 andalso S.length stack=0 end)
  val _ = T.check("stack/fold-order",fn () => S.fold(fn (acc,x) => acc*10+x)0(S.integers 3)=321)
  val _ = T.check("stack/fold-preserves-stack",fn () =>
    let val stack=S.integers 4
    in S.fold op + 0 stack=10 andalso S.length stack=4 andalso S.top stack=4 end)
  val _ = T.check("stack/fold-input",fn () => S.foldRun 3=15150)
  val _ = T.check("stack/push-pop-input",fn () => S.pushPopRun 20=20)
  val _ = T.check("stack/zero-iterations",fn () => S.foldRun 0=0 andalso S.pushPopRun 0=0)
  val _ = T.check("stack/exception-identity",fn () =>
    ((S.pop(S.create():int S.stack);false)handle S.Empty => true | Empty => false))
end

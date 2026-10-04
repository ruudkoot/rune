structure BenchConstraintTests =
struct
  structure N = BenchConstraintsFn(BenchNeed)
  structure S = BenchConstraintsFn(BenchStrict)
  structure L = BenchLazy
  fun counts size = List.map(fn method => List.length(N.Q.toList(N.search method (N.queens size))))
    [N.bt,N.bm,N.bjbt,N.bjbt',N.fc]
  val _ = T.check("constraints/five-solvers",fn () => counts 4=[2,2,2,2,2] andalso counts 6=[4,4,4,4,4])
  val _ = T.check("constraints/zero-source-behavior",fn () => counts 0=[1,0,1,1,1])
  val _ = T.check("constraints/strict-lazy",fn () =>
    let val problem=S.queens 4
        val results=List.map(fn method => List.length(S.Q.toList(S.search method problem)))
          [S.bt,S.bm,S.bjbt,S.bjbt',S.fc]
    in results=counts 4 end)
  val _ = T.check("constraints/earliest-oldest-conflict",fn () =>
    N.earliest(N.queens 4)[(3,1),(2,2),(1,1)]=SOME(3,1))
  val _ = T.check("constraints/union-order",fn () =>
    N.Q.toList(N.union(N.Q.fromList[2,1])(N.Q.fromList[1,3,3,2,4]))=[2,1,3,4])
  val poison : N.label L.delay = L.delay(fn () => raise Fail "unneeded root label")
  val _ = T.check("constraints/prune-keeps-root-label-lazy",fn () =>
    let val tree=L.delay(fn () => N.Node(poison,N.Q.empty()))
    in case L.force(N.filterTree(fn _ => true)tree)of N.Node _ => true end)
  val _ = T.check("constraints/backjump-skips-remaining-siblings",fn () =>
    let val labels=N.Q.cons(N.value([(2,1)],N.value(N.Known(N.Q.fromList[1]))))
          (L.delay(fn () => raise Fail "unneeded siblings"))
    in N.Q.toList(N.combine labels (N.Q.empty()))=[1]end)
  val _ = T.check("constraints/cache-future-row",fn () =>
    let val problem=N.queens 4
        val table=N.fillTable[(1,1)]problem(N.Q.tail(N.emptyTable problem))
        val row=N.Q.toList(N.Q.head table)
    in List.map N.knownConflict row=[true,true,false,false]end)
  val calls=ref 0
  val _ = T.check("constraints/mapped-label-sharing",fn () =>
    let val tree=L.delay(fn () => N.Node(N.value 10,N.Q.empty()))
        val mapped=N.mapTree(fn n => (calls := !calls+1;n+1))tree
    in N.label mapped=11 andalso N.label mapped=11 andalso !calls=1 end)
end

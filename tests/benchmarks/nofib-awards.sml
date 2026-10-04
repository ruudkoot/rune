structure BenchAwardsTests =
struct
  structure N = BenchAwardsFn(BenchNeed)
  structure S = BenchAwardsFn(BenchStrict)
  val _ = T.check("awards/combinations-not-permutations",fn () =>
    N.Q.toList(N.permutations 3 [1,2,3,4]) = [[1,2,3],[1,2,4],[1,3,4],[2,3,4]])
  val _ = T.check("awards/short-input",fn () => N.Q.toList(N.permutations 3 [1,2])=[])
  val _ = T.check("awards/stable-quicksort",fn () =>
    N.Q.toList(N.sortLe(fn ((a,_),(b,_)) => a<=b)(N.Q.fromList[(2,"a"),(1,"b"),(2,"c"),(1,"d")])) =
      [(1,"b"),(1,"d"),(2,"a"),(2,"c")])
  fun checkedOrder (a,b) = if a<>0 andalso b<>0 then raise Fail "unneeded right sort" else a<=b
  val _ = T.check("awards/lazy-sort-suffix",fn () =>
    N.Q.head(N.sortLe checkedOrder (N.Q.fromList[0,2,1]))=0)
  val _ = T.check("awards/strict-sort-suffix",fn () =>
    ((S.Q.head(S.sortLe checkedOrder (S.Q.fromList[0,2,1]));false)handle Fail _ => true))
  val _ = T.check("awards/threshold-is-inclusive",fn () =>
    let val (award,(sum,items)) = N.Q.head(N.awards[20,20,30])
    in award="Gold" andalso BenchLazy.force sum=70 andalso items=[20,20,30] end)
  val _ = T.check("awards/remove-duplicate-occurrences",fn () => N.difference[2,1,2,3][2,2]=[1,3])
  val _ = T.check("awards/tier-and-smallest-total-priority",fn () =>
    let val chosen = N.Q.toList(N.findAwards(N.Q.value[20,20,30,1,1,50]))
        val normalized = List.map(fn (award,(sum,items)) => (award,(BenchLazy.force sum,items)))chosen
    in normalized=[("Gold",(70,[20,20,30])),("Bronze",(52,[1,1,50]))] end)
  val _ = T.check("awards/all-input-cycle-variants",fn () =>
    List.all(fn i => N.render i=S.render i)(List.tabulate(100,fn n => n)))
end

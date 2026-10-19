structure BenchSccTests =
struct
  structure N = BenchSccFn(BenchNeed)
  structure S = BenchSccFn(BenchStrict)
  val _ = T.check("scc/original-order",fn () =>
    N.components N.edges N.vertices = [[1],[2],[7,5,6],[3,4]])
  val _ = T.check("scc/lazy-strict",fn () => N.components N.edges N.vertices = S.components S.edges S.vertices)
  val _ = T.check("scc/empty",fn () => N.components [] [] = [])
  val _ = T.check("scc/disconnected-order",fn () => N.components [] [1,2,3] = [[1],[2],[3]])
  val _ = T.check("scc/cycle",fn () =>
    List.length(N.components[(1,2),(2,3),(3,1)][1,2,3])=1)
  val _ = T.check("scc/duplicate-edges",fn () =>
    N.components[(1,2),(1,2),(2,1)][1,2] = N.components[(1,2),(2,1)][1,2])
  val _ = T.check("scc/finish-list-no-premature-demand",fn () =>
    let val unused : int N.Q.sequence = BenchLazy.delay(fn () => raise Fail "unused finish list")
        val (seen,_) = N.dfs(N.range[])(N.Q.value [],unused)(N.Q.fromList[1,2])
    in BenchLazy.force seen=[2,1] end)
  val _ = T.check("scc/lazy-pair-finish-before-visited",fn () =>
    let val (_,finished) = N.dfs(fn _ => raise Fail "unused neighbour traversal")
          (N.Q.value [],N.Q.empty())(N.Q.fromList[1])
    in N.Q.head finished=1 end)
  val _ = T.check("scc/tuple-field-sharing",fn () =>
    let val calls = ref 0
        fun neighbours x = (calls := !calls+1;N.Q.fromList(if x=1 then [2] else []))
        val (seen,finished) = N.dfs neighbours (N.Q.value [],N.Q.empty())(N.Q.fromList[1])
    in BenchLazy.force seen=[2,1] andalso N.Q.toList finished=[1,2] andalso !calls=2 end)
end

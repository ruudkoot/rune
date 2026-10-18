structure D=BenchDomFn(struct val checkInitialized=true end)
structure R=BenchDomReader
val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/dom-lt-originals/"
val graphs=R.graphs(R.read(base^"cases/graphs.in"))
val expected=R.results(R.read(base^"repair-threshold.parents"))
fun check [] [] index=(print("PASS "^Int.toString index^" original/model graphs, initialized arrays\n"))
 |check(g::gs)(want::rest)index=
    let val actual=D.idom g
    in if actual=want then check gs rest(index+1)
       else(print("FAIL graph "^Int.toString index^"\n");raise Fail "dominator mismatch")end
 |check _ _ _=raise Fail "graph count"
val _=check graphs expected 0

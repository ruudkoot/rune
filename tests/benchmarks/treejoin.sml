structure BenchTreeJoinTests =
struct
  fun value n=BenchLazy.delay(fn()=>n)
  val skipped=ref 0
  val unused : int BenchLazy.delay = BenchLazy.delay(fn()=>(skipped := !skipped+1;raise Fail "unused relation field"))
  val left=TreeJoin.insert(value 1)(value 1,unused,value 9)(TreeJoin.empty())
  val right=TreeJoin.insert(value 2)(value 2,value 7,value 4)(TreeJoin.empty())
  val _=T.check("treejoin/unmatched-field-demand",fn()=>TreeJoin.lines(TreeJoin.join left right(TreeJoin.empty()))=[] andalso !skipped=0)
  val _=T.check("treejoin/lookup-boundary",fn()=>case TreeJoin.lookup 1 left of SOME(a,_,c)=>BenchLazy.force a=1 andalso BenchLazy.force c=9|NONE=>false)
  val _=T.check("treejoin/missing-key",fn()=>case TreeJoin.lookup 3 right of NONE=>true|_=>false)
  val matched=TreeJoin.insert(value 9)(value 9,value 7,value 4)(TreeJoin.empty())
  val clean=TreeJoin.insert(value 1)(value 1,value 5,value 9)(TreeJoin.empty())
  val _=T.check("treejoin/full-joined-record",fn()=>TreeJoin.lines(TreeJoin.join clean matched(TreeJoin.empty()))=["1 5 9 9 7\n"])
  val duplicate=TreeJoin.insert(value 1)(value 1,value 5,value 9)clean
  val _=T.check("treejoin/duplicate-key-rejected",fn()=>(TreeJoin.lookup 1 duplicate;false)handle Fail _=>true)
end

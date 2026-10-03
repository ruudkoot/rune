structure BenchGCNegativeTests =
struct
  fun rejected f=(f();false)handle Fail _=>true
  val immutable=GC.checkedTree 2(GC.makeTree 2)
  val _=T.check("gc/complete-immutable-tree",fn()=>immutable=7)
  val _=T.check("gc/incorrect-balanced-shape-rejected",fn()=>rejected(fn()=>(GC.checkedTree 1(GC.Node(GC.makeTree 1,GC.Empty,0));())))
  val _=T.check("gc/compensating-labels-rejected",fn()=>rejected(fn()=>(GC.checkedTree 1(GC.Node(GC.Node(GC.Empty,GC.Empty,1),GC.Node(GC.Empty,GC.Empty,~1),0));())))
  val mutable=GC.newNode 2
  val _=GC.populate 2 mutable
  val _=T.check("gc/complete-mutable-tree",fn()=>GC.checkedMutable 2 mutable=7)
  val _=case mutable of GC.MutNode(l,_,_)=>l:=GC.MutEmpty|_=>raise Fail "test tree"
  val _=T.check("gc/missing-subtree-rejected",fn()=>rejected(fn()=>(GC.checkedMutable 2 mutable;())))
  val table=Benchmark.new()
  val _=List.app(Benchmark.insert table)(List.tabulate(128,fn i=>i+1))
  val _=T.check("hash/full-table",fn()=>Benchmark.validate 128(!table)=8256)
  val _=T.check("hash/high-word",fn()=>Benchmark.hash 128=158)
  val{count,mask,buckets}= !table
  val _=Array.update(buckets,0,(1,999)::Array.sub(buckets,0))
  val _=T.check("hash/corrupt-pair-rejected",fn()=>rejected(fn()=>(Benchmark.validate 128(!table);())))
end

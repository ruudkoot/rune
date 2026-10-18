structure D=BenchDomFn(struct val checkInitialized=true end)
val graph=BenchDomGraph.fromAdj[(0,[1,2]),(1,[3]),(2,[3]),(3,[])]
val pairs=D.idom(0,graph)
val _=List.app(fn(node,parent)=>print(Int.toString node^" "^Int.toString parent^"\n"))pairs

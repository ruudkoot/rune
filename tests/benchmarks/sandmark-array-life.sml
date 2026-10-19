structure ArrayLifePilot =
struct
 structure K=BenchArrayLife
 fun board rows=Array.fromList(List.map Array.fromList rows)
 fun rows array=Array.foldr(fn(row,rest)=>Array.foldr op:: [] row::rest)[]array
 val _=T.check("array-life/boundary-zero",fn()=>K.get(board[[1]])~1 0=0 andalso K.get(board[[1]])0 1=0)
 val _=T.check("array-life/single-cell-dies",fn()=>rows(K.run 1(board[[1]]))=[[0]])
 val _=T.check("array-life/block-stable",fn()=>let val b=[[1,1],[1,1]]in rows(K.run 3(board b))=b end)
 val _=T.check("array-life/blinker",fn()=>rows(K.run 1(board[[0,0,0],[1,1,1],[0,0,0]]))=[[0,1,0],[0,1,0],[0,1,0]])
 val _=T.check("array-life/blinker-period",fn()=>let val b=[[0,0,0],[1,1,1],[0,0,0]]in rows(K.run 2(board b))=b end)
 val _=T.check("array-life/zero-generations",fn()=>rows(K.run 0(board[[1,0],[0,1]]))=[[1,0],[0,1]])

 val _=T.check("array-life/previous-buffer",fn()=>
   let val(current,previous)=K.runBuffers 1(board[[0,0,0],[1,1,1],[0,0,0]])
   in rows current=[[0,1,0],[0,1,0],[0,1,0]]andalso rows previous=[[0,0,0],[1,1,1],[0,0,0]]end)
 val _=T.check("array-life/distinct-buffers",fn()=>
   let val(current,previous)=K.runBuffers 2(board[[1,1],[1,1]])
       val _=Array.update(Array.sub(current,0),0,9)
   in K.get previous 0 0=1 end)

 val _=T.check("array-life/checker-accepts",fn()=> #1(Benchmark.check(board[[1,1],[1,1]])"block.board" 0w0)=4)
 val _=T.check("array-life/checker-rejects-perturbation",fn()=>
   ((Benchmark.check(board[[0,1],[1,1]])"block.board" 0w0;false)handle Fail _=>true))
end

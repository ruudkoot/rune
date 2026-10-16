structure FannkuchReduxTests =
struct
 structure K=BenchFannkuchRedux
 fun image({p,...}:K.permutation)=Array.foldr(fn(x,xs)=>x::xs)[]p
 fun read path=let val input=TextIO.openIn path val text=TextIO.inputAll input in TextIO.closeIn input;text end
 fun rejected thunk=(thunk();false)handle Fail _=>true
 val _=T.check("fannkuchredux/full-63bit-factorial-table",fn()=>IntInf.toString(Array.sub(K.facts,20))="2432902008176640000")
 val _=T.check("fannkuchredux/factoradic-order",fn()=>List.map(fn i=>image(K.setup 3 i))[0,1,2,3,4,5]=[[0,1,2],[1,0,2],[1,2,0],[2,1,0],[2,0,1],[0,2,1]])
 val _=T.check("fannkuchredux/original-zero-first-convention",fn()=>K.count(K.setup 3 0)=1 andalso K.count(K.setup 3 5)=1)
 val _=T.check("fannkuchredux/checked-terminal-carry",fn()=>let val state=K.setup 3 5 val _=K.next state in Array.foldl(fn(x,ok)=>ok andalso x=0)true(#c state)end)
 val _=T.check("fannkuchredux/empty-trailing-chunk",fn()=>K.chunk 3 6 6=(0,0))
 val _=T.check("fannkuchredux/six-permutation-aggregate",fn()=>K.chunk 3 0 6=(2,2))
 val _=T.check("fannkuchredux/all32-chunks-edge",fn()=>(K.checkOutput 3(read "edge.expected");true))
 val _=T.check("fannkuchredux/original-full-smoke",fn()=>(K.checkOutput 5(read "smoke.expected");true))
 val _=T.check("fannkuchredux/rejects-output-perturbation",fn()=>rejected(fn()=>K.checkOutput 3("x"^String.extract(read "edge.expected",1,NONE))))
 val _=T.check("fannkuchredux/rejects-extra-fixture",fn()=>rejected(fn()=>K.checkOutput 3(read "edge.expected"^"extra")))
end

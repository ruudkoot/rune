structure BinaryTrees5Tests =
struct
 open BenchBinaryTree
 val make=BenchBinaryTrees5.make
 fun read path=let val input=TextIO.openIn path val text=TextIO.inputAll input in TextIO.closeIn input;text end
 fun rejected thunk=(thunk();false)handle Fail _=>true
 val _=T.check("binarytrees5/empty",fn()=>BenchBinaryTrees5.check Empty=0)
 val _=T.check("binarytrees5/leaf",fn()=>BenchBinaryTrees5.check(make 0)=1)
 val _=T.check("binarytrees5/asymmetric-checks-both-children",fn()=>BenchBinaryTrees5.check(Node(Empty,make 0))=2)
 val _=T.check("binarytrees5/complete-tree-formula",fn()=>List.all(fn d=>BenchBinaryTrees5.check(make d)=BenchBinaryTrees5.power2(d+1)-1)(List.tabulate(8,fn i=>i)))
 val _=T.check("binarytrees5/original-full-smoke",fn()=>(BenchBinaryTrees5.checkOutput 6(read "6.expected");true))
 val _=T.check("binarytrees5/minimum-depth-clamp",fn()=>(BenchBinaryTrees5.checkOutput 0(read "6.expected");true))
 val _=T.check("binarytrees5/rejects-output-perturbation",fn()=>rejected(fn()=>BenchBinaryTrees5.checkOutput 6("x"^String.extract(read "6.expected",1,NONE))))
 val _=T.check("binarytrees5/rejects-unconsumed-fixture",fn()=>rejected(fn()=>BenchBinaryTrees5.checkOutput 6(read "6.expected"^"extra")))
end

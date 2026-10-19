structure SortingPilot =
struct
 structure N=BenchSortingFn(BenchNeed)
 structure S=BenchSortingFn(BenchStrict)
 fun insert x []=[x] | insert x(y::ys)=if x<=y then x::y::ys else y::insert x ys
 fun sorted xs=List.foldl(fn(x,ys)=>insert x ys)[]xs
 val algorithmsN=[("heap",N.heapSort),("insert",N.insertSort),("merge",N.mergeSort),
   ("quick",N.quickSort),("partition-quick",N.quickSort2),("quicker",N.quickerSort),
   ("tree",N.treeSort),("twig-tree",N.treeSort2)]
 val algorithmsS=[("heap",S.heapSort),("insert",S.insertSort),("merge",S.mergeSort),
   ("quick",S.quickSort),("partition-quick",S.quickSort2),("quicker",S.quickerSort),
   ("tree",S.treeSort),("twig-tree",S.treeSort2)]
 fun words 0=[[]]
   | words n=List.concat(List.map(fn xs=>List.map(fn x=>x::xs)[~1,0,1])(words(n-1)))
 val inputs=List.concat(List.tabulate(6,words))
 val _=List.app(fn(name,sort)=>T.check("sorting/lazy-"^name,fn()=>List.all
   (fn xs=>N.Q.toList(sort Int.compare(N.Q.fromList xs))=sorted xs)inputs))algorithmsN
 val _=List.app(fn(name,sort)=>T.check("sorting/strict-"^name,fn()=>List.all
   (fn xs=>S.Q.toList(sort Int.compare(S.Q.fromList xs))=sorted xs)inputs))algorithmsS
 val _=T.check("sorting/complete-pipeline",fn()=>List.all(fn xs=>
   N.Q.toList(N.mangle Int.compare(N.Q.fromList xs))=sorted xs andalso
   S.Q.toList(S.mangle Int.compare(S.Q.fromList xs))=sorted xs)inputs)

 val taggedN=N.Q.fromList[(1,0),(0,1),(1,2),(0,3),(1,4)]
 fun compareN ((a,_),(b,_))=Int.compare(a,b)
 val _=T.check("sorting/tagged-N-heapSort",fn()=>List.map #2(N.Q.toList(N.heapSort compareN taggedN))=[1,3,4,0,2])
 val _=T.check("sorting/tagged-N-insertSort",fn()=>List.map #2(N.Q.toList(N.insertSort compareN taggedN))=[3,1,4,2,0])
 val _=T.check("sorting/tagged-N-mergeSort",fn()=>List.map #2(N.Q.toList(N.mergeSort compareN taggedN))=[1,3,0,2,4])
 val _=T.check("sorting/tagged-N-quickSort",fn()=>List.map #2(N.Q.toList(N.quickSort compareN taggedN))=[3,1,4,2,0])
 val _=T.check("sorting/tagged-N-quickSort2",fn()=>List.map #2(N.Q.toList(N.quickSort2 compareN taggedN))=[3,1,4,2,0])
 val _=T.check("sorting/tagged-N-quickerSort",fn()=>List.map #2(N.Q.toList(N.quickerSort compareN taggedN))=[3,1,2,4,0])
 val _=T.check("sorting/tagged-N-treeSort",fn()=>List.map #2(N.Q.toList(N.treeSort compareN taggedN))=[1,3,0,2,4])
 val _=T.check("sorting/tagged-N-treeSort2",fn()=>List.map #2(N.Q.toList(N.treeSort2 compareN taggedN))=[1,3,0,2,4])
 val _=T.check("sorting/tagged-N-mangle",fn()=>List.map #2(N.Q.toList(N.mangle compareN taggedN))=[3,1,2,0,4])

 val taggedS=S.Q.fromList[(1,0),(0,1),(1,2),(0,3),(1,4)]
 fun compareS ((a,_),(b,_))=Int.compare(a,b)
 val _=T.check("sorting/tagged-S-heapSort",fn()=>List.map #2(S.Q.toList(S.heapSort compareS taggedS))=[1,3,4,0,2])
 val _=T.check("sorting/tagged-S-insertSort",fn()=>List.map #2(S.Q.toList(S.insertSort compareS taggedS))=[3,1,4,2,0])
 val _=T.check("sorting/tagged-S-mergeSort",fn()=>List.map #2(S.Q.toList(S.mergeSort compareS taggedS))=[1,3,0,2,4])
 val _=T.check("sorting/tagged-S-quickSort",fn()=>List.map #2(S.Q.toList(S.quickSort compareS taggedS))=[3,1,4,2,0])
 val _=T.check("sorting/tagged-S-quickSort2",fn()=>List.map #2(S.Q.toList(S.quickSort2 compareS taggedS))=[3,1,4,2,0])
 val _=T.check("sorting/tagged-S-quickerSort",fn()=>List.map #2(S.Q.toList(S.quickerSort compareS taggedS))=[3,1,2,4,0])
 val _=T.check("sorting/tagged-S-treeSort",fn()=>List.map #2(S.Q.toList(S.treeSort compareS taggedS))=[1,3,0,2,4])
 val _=T.check("sorting/tagged-S-treeSort2",fn()=>List.map #2(S.Q.toList(S.treeSort2 compareS taggedS))=[1,3,0,2,4])
 val _=T.check("sorting/tagged-S-mangle",fn()=>List.map #2(S.Q.toList(S.mangle compareS taggedS))=[3,1,2,0,4])

 val _=T.check("sorting/inorder-prefix-defers-right",fn()=>
   let val tree=N.Q.value(N.Branch(N.Q.value 2,
         N.Q.value(N.Branch(N.Q.value 1,N.tip(),N.tip())),
         BenchNeed.delay(fn()=>raise Fail "unneeded right subtree")))
   in N.Q.head(N.readTree tree)=1 end)

 val _=T.check("sorting/merge-guard-calls-N",fn()=>
   let val calls=ref 0
       fun compare pair=(calls:= !calls+1;Int.compare pair)
       val result=N.Q.toList(N.merge compare(N.Q.fromList[1])(N.Q.fromList[2]))
   in result=[1,2]andalso !calls=2 end)
 val _=T.check("sorting/run-guard-calls-N",fn()=>
   let val calls=ref 0
       fun compare pair=(calls:= !calls+1;Int.compare pair)
       val result=N.Q.toList(N.mergeSort compare(N.Q.fromList[2,1]))
   in result=[1,2]andalso !calls=2 end)

 val _=T.check("sorting/merge-guard-calls-S",fn()=>
   let val calls=ref 0
       fun compare pair=(calls:= !calls+1;Int.compare pair)
       val result=S.Q.toList(S.merge compare(S.Q.fromList[1])(S.Q.fromList[2]))
   in result=[1,2]andalso !calls=2 end)
 val _=T.check("sorting/run-guard-calls-S",fn()=>
   let val calls=ref 0
       fun compare pair=(calls:= !calls+1;Int.compare pair)
       val result=S.Q.toList(S.mergeSort compare(S.Q.fromList[2,1]))
   in result=[1,2]andalso !calls=2 end)
end

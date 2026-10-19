functor SparseTests(D:BENCH_SUSPEND)=struct
 structure X=BenchFluidSparseFn(D)
 structure F=X.F
 structure L=BenchLazy
 fun number n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun tuple(a,b)="("^number a^","^number b^")"
 fun showTrie root=case L.force root of X.Null=>"N"|X.Leaf v=>"L"^number(D.force v)
   |X.Fork(a,b)=>"F("^showTrie a^","^showTrie b^")"
 fun showAssociations values="["^String.concatWith","(List.map(fn(i,v)=>tuple(i,D.force v))(F.toList values))^"]"
 fun dump a=let val X.Array(bnds,size,default,root)=L.force a
   in String.concatWith"|"[tuple bnds,number size,case default of NONE=>"Nothing"|SOME v=>"Just "^number(D.force v),
      showTrie root,showAssociations(X.associations a),showAssociations(X.sparseAssociations a)]end
 fun pairs values=F.fromList(List.map(fn(i,v)=>(i,X.cell v))values)
 val input=TextIO.openIn"tests/out/benchmarks/nofib-fluid-originals/sparse.reference"
 val index=ref 0
 fun check a=let val actual=dump a
     val expected=case TextIO.inputLine input of NONE=>raise Fail"oracle EOF"
       |SOME s=>String.substring(s,0,size s-1)
   in if actual=expected then print("PASS sparse shape, defaults and values "^Int.toString(!index)^"\n")
      else(print("ACTUAL "^actual^"\nEXPECTED "^expected^"\n");raise Fail"sparse array oracle");index:= !index+1 end
 fun eq a b=D.force a=D.force b
 fun add a b=D.delay(fn()=>D.force a+D.force b)
 fun sub a b=D.delay(fn()=>D.force a-D.force b)
 fun run(lo,hi,values,updates,acc)=let
     val a=X.listArray(lo,hi)(F.fromList values)
     val b=X.defListArray eq(lo,hi)(X.cell 0)(F.fromList values)
     val arrays=[a,b,X.update eq a(pairs updates),X.update eq b(pairs updates),
       X.accum eq sub a(pairs acc),X.accum eq sub b(pairs acc),
       X.amap(fn v=>D.delay(fn()=>2*D.force v))b,
       X.ixmap(lo,hi)(fn i=>hi-(i-lo))a,
       X.accumArray eq add(X.cell 0)(lo,hi)(pairs(acc@acc)),
       X.defArray eq(lo,hi)(X.cell 0)(pairs(ListPair.zip(List.tabulate(length values,fn n=>lo+n),values)))]
   in List.app check arrays end
 val _=List.app run [(~3,~4,[],[],[]),(~3,~3,[~3],[(~3,~1)],[(~3,1),(~3,0),(~3,2),(~3,1),(~3,0),(~3,0),(~3,1)]),(~3,~2,[~3,2],[(~3,2),(~2,1)],[(~2,~1),(~3,~2),(~3,~1),(~3,~2),(~2,2),(~2,1),(~3,2)]),(~3,~1,[~3,4,5],[(~1,1),(~3,2),(~2,~4)],[(~1,0),(~1,~2),(~2,1),(~3,~2),(~2,~1),(~3,2),(~3,1)]),(~3,0,[2,4,4,1],[(0,3),(~3,1),(~1,2)],[(~1,1),(~3,~2),(~1,~1),(~1,0),(0,~3),(~3,0),(~1,~3)]),(~3,1,[~3,5,3,2,4],[(1,~5),(0,3),(~1,3)],[(~3,0),(0,0),(~2,0),(~3,~2),(0,3),(1,2),(1,2)]),(~3,3,[~2,~3,0,2,1,~5,~4],[(~2,2),(1,~1),(3,~1)],[(0,~3),(~2,~1),(~3,~1),(~2,~2),(3,1),(0,1),(~3,0)]),(~3,4,[~3,4,~2,~5,0,0,~3,~4],[(3,~3),(~2,~4),(~3,~1)],[(~2,1),(0,0),(0,0),(2,2),(4,~1),(2,1),(0,0)]),(~3,5,[~2,~5,5,5,~3,~3,2,~3,~2],[(3,1),(~3,~4),(4,~3)],[(~2,~3),(4,3),(~1,~2),(~3,~1),(~1,0),(~1,~3),(~3,~2)]),(~3,11,[1,1,0,2,5,0,~4,5,3,5,~5,1,4,5,0],[(10,~4),(6,~2),(~3,2)],[(2,~1),(~1,1),(~1,~2),(10,1),(2,~1),(8,0),(1,3)]),(~3,12,[4,~3,~2,~3,0,~5,0,~1,2,2,~1,2,~3,1,~1,5],[(12,1),(2,~1),(~1,~4)],[(~2,~2),(10,~3),(4,2),(~1,~1),(9,~2),(8,~3),(3,3)]),(~3,13,[5,~2,~2,2,1,2,~1,~5,3,~2,~5,0,3,0,~1,1,5],[(4,2),(2,~4),(5,2)],[(~2,~2),(6,~1),(10,0),(~3,0),(~1,0),(~2,0),(2,~1)]),(~3,27,[0,~5,3,~3,2,1,2,4,1,~2,~4,5,~5,~3,~3,4,~4,2,~2,~4,~5,~4,5,0,~2,~1,~3,~2,5,2,2],[(15,1),(20,~4),(10,~2)],[(10,3),(~2,3),(10,~3),(~2,~3),(5,~3),(5,3),(6,~1)])]
 val _=TextIO.closeIn input
end
structure A=SparseTests(BenchNeed)
structure B=SparseTests(BenchStrict)

structure Benchmark =
struct
  val name="gc_bench"
  datatype tree=Empty|Node of tree*tree*int
  datatype mutable=MutEmpty|MutNode of mutable ref*mutable ref*int
  fun treeSize depth=let fun power 0=1|power n=2*power(n-1)in power(depth+1)-1 end
  fun makeTree 0=Node(Empty,Empty,0)
    |makeTree d=Node(makeTree(d-1),makeTree(d-1),0)
  fun newNode i=MutNode(ref MutEmpty,ref MutEmpty,i)
  fun populate 0 _=()
    |populate d(MutNode(left,right,_))=
      let val l=newNode d val _=left:=l val r=newNode d val _=right:=r
      in populate(d-1)l;populate(d-1)r end
    |populate _ MutEmpty=raise Fail "empty mutable population"
  fun observe Empty=(0,0)
    |observe(Node(l,r,i))=let val(a,b)=observe l val(c,d)=observe r in (1+a+c,i+b+d)end
  fun observeMutable MutEmpty=(0,0)
    |observeMutable(MutNode(l,r,i))=let val(a,b)=observeMutable(!l)val(c,d)=observeMutable(!r)in(1+a+c,i+b+d)end
  fun leftDepth MutEmpty=0|leftDepth(MutNode(l,_,_))=leftDepth(!l)
  fun checkedTree depth tree=
    let fun walk(d,Empty)=if d<0 then 0 else raise Fail "immutable GC tree shape"
          |walk(d,Node(l,r,i))=if d<0 orelse i<>0 then raise Fail "immutable GC tree label"
            else 1+walk(d-1,l)+walk(d-1,r)
        val nodes=walk(depth,tree)
    in if nodes=treeSize depth then nodes else raise Fail "immutable GC tree differs"end
  fun checkedMutable depth tree=
    let fun walk(d,_,MutEmpty)=if d<0 then(0,0)else raise Fail "mutable GC tree shape"
          |walk(d,want,MutNode(l,r,i))=if d<0 orelse i<>want then raise Fail "mutable GC tree label"
            else let val(a,b)=walk(d-1,d,!l)val(c,e)=walk(d-1,d,!r)in(1+a+c,i+b+e)end
        val(nodes,values)=walk(depth,depth,tree)val wanted=2*treeSize depth-depth-2
    in if nodes=treeSize depth andalso values=wanted then nodes else raise Fail "mutable GC tree differs"end
  fun run[longDepth,size,minDepth,maxDepth]=
    let val retained=BenchInput.between(0,19)(BenchInput.integer longDepth)
        val arraySize=BenchInput.between(2,500000)(BenchInput.integer size)
        val first=BenchInput.between(0,22)(BenchInput.integer minDepth)
        val last=BenchInput.between(first,22)(BenchInput.integer maxDepth)
        val immutable=makeTree retained
        val _=checkedTree retained immutable
        val mutable=newNode retained val _=populate retained mutable
        val array=Array.array(arraySize,0.0)
        fun fill i=if i>=arraySize div 2 then()else(Array.update(array,i,1.0/Real.fromInt(i+1));fill(i+1))
        val _=fill 0
        fun construction depth=
          let val iterations=2*treeSize last div treeSize depth
              fun top(0,count)=count
                |top(i,count)=let val root=newNode depth val _=populate depth root val nodes=checkedMutable depth root
                  in top(i-1,IntInf.+(count,IntInf.fromInt nodes))end
              fun bottom(0,count)=count
                |bottom(i,count)=let val nodes=checkedTree depth(makeTree depth)
                  in bottom(i-1,IntInf.+(count,IntInf.fromInt nodes))end
          in IntInf.+(top(iterations,0),bottom(iterations,0))end
        fun depths(d,count)=if d>last then count else depths(d+2,IntInf.+(count,construction d))
        val total=depths(first,0)
        val left=checkedTree retained immutable val right=checkedMutable retained mutable
        val _=if leftDepth mutable=0 then()else raise Fail "original left-depth walk"
        fun check i=if i=arraySize then()else
          let val actual=Array.sub(array,i)val wanted=if i<arraySize div 2 then 1.0/Real.fromInt(i+1)else 0.0
          in if BenchInput.closeReal(actual,wanted,0.0,4.440892098500626E~16)then check(i+1)else raise Fail "retained GC array differs"end
        val _=check 0
    in IntInf.toString total^" "^Int.toString left^" "^Int.toString right^" "^Int.toString arraySize end
    |run _=raise Fail "gc_bench expects retained-depth array-size min-depth max-depth"
end

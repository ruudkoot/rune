(* Ported from the pinned Sandmark/Benchmark Game source.
   Original attribution and BSD notices are retained in binarytrees5/upstream. *)
structure BenchBinaryTrees5 =
struct
  open BenchBinaryTree
  fun make 0=Node(Empty,Empty)
    | make depth=
        let val d=depth-1 val right=make d val left=make d
        in Node(left,right)end
  fun check Empty=0
    | check(Node(left,right))=
        let val r=check right val l=check left in 1+l+r end
  fun power2 n=Word.toInt(Word.<<(0w1,Word.fromInt n))
  fun run requested emit=
    let
      val minDepth=4
      val maxDepth=Int.max(minDepth+2,requested)
      val stretchDepth=maxDepth+1
      val stretch=check(make stretchDepth)
      val _=emit("stretch tree of depth "^Int.toString stretchDepth^"\t check: "^Int.toString stretch^"\n")
      val retained=make maxDepth
      fun loopDepths first=
        let val bound=(maxDepth-first)div 2+1
            fun level i=if i>=bound then ()else
              let val depth=first+i*2
                  val iterations=power2(maxDepth-depth+minDepth)
                  val total=ref 0
                  fun trees j=if j>iterations then ()else
                    let val result=check(make depth)
                    in total:= !total+result;trees(j+1)end
                  val _=trees 1
              in emit(Int.toString iterations^"\t trees of depth "^Int.toString depth^"\t check: "^Int.toString(!total)^"\n");level(i+1)end
        in level 0 end
      val _=loopDepths minDepth
    in emit("long lived tree of depth "^Int.toString maxDepth^"\t check: "^Int.toString(check retained)^"\n")end
  fun checkOutput requested expected =
    let val position=ref 0
        fun emit text=
          let val n=String.size text
          in if !position+n<=String.size expected andalso
                String.substring(expected,!position,n)=text
             then position:= !position+n else raise Fail "binary tree output differs"end
        val _=run requested emit
    in if !position=String.size expected then ()else raise Fail "binary tree output incomplete"end
end

(* SML/NJ 75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0; original notice in LICENSE. *)
structure Benchmark =
struct
  val name = "binary-trees"
  datatype tree = Empty | Node of tree * tree
  fun make 0 = Node(Empty,Empty)
    | make depth = let val d=depth-1 in Node(make d,make d) end
  fun checksum (Node(Empty,_)) = 1
    | checksum (Node(left,right)) = 1+checksum left+checksum right
    | checksum Empty = raise Fail "invalid tree"
  fun run [size] =
        let val depth = BenchInput.between (6,21) (BenchInput.integer size)
            val stretch = checksum(make(depth+1))
            val retained = make depth
            fun copies(d,n,total) = if n=0 then total else copies(d,n-1,IntInf.+(total,IntInf.fromInt(checksum(make d))))
            fun levels(d,total) = if d>depth then total else
              let val n = Word.toInt(Word.<<(0w1,Word.fromInt(depth-d+4)))
              in levels(d+2,IntInf.+(total,copies(d,n,IntInf.fromInt 0))) end
            val work = levels(4,IntInf.fromInt 0)
        in Int.toString stretch ^ " " ^ IntInf.toString work ^ " " ^ Int.toString(checksum retained) end
    | run _ = raise Fail "binary-trees expects depth"
end

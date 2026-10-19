structure Benchmark =
struct
  structure K = BenchFibHeapsFn(BenchStrict)
  val name = "fibheaps-strict"
  fun histogram path =
    let val input=TextIO.openIn path
        val text=TextIO.inputAll input
        val _=TextIO.closeIn input
        val result=Array.array(1968,0)
        fun entry line = case String.tokens Char.isSpace line of [key,count] =>
              Array.update(result,BenchInput.between(0,1967)(BenchInput.integer key),BenchInput.integer count)
            | _ => raise Fail "invalid histogram row"
        val _=List.app entry (String.tokens(fn c => c= #"\n")text)
    in result end
  fun run [size,path] =
    let val n=BenchInput.between(0,600000)(BenchInput.integer size)
        val expected=histogram path
        fun consume left right count total previous =
          case BenchStrict.force left of K.Q.Nil =>
            (case BenchStrict.force right of K.Q.Nil =>
              if count=n andalso Array.foldl(fn (remaining,ok) => remaining=0 andalso ok)true expected
              then Int.toString count ^ ":" ^ Int.toString total else raise Fail "heap histogram differs"
             | _ => raise Fail "heap lengths differ")
          | K.Q.Cons(x,xs) => case BenchStrict.force right of K.Q.Nil => raise Fail "heap lengths differ"
            | K.Q.Cons(y,ys) =>
                let val a=BenchStrict.force x
                    val b=BenchStrict.force y
                    val _=if a=b andalso a>=previous andalso a>=0 andalso a<1968 then () else raise Fail "heap values differ"
                    val remaining=Array.sub(expected,a)
                    val _=if remaining>0 then Array.update(expected,a,remaining-1)else raise Fail "unexpected heap value"
                in consume xs ys (count+1)(total+a)a end
    in consume(K.sorted K.deleteMutable n)(K.sorted K.deleteFunctional n)0 0 ~1 end
    | run _ = raise Fail "fibheaps expects size histogram"
end

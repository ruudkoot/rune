structure Benchmark =
struct
 structure D=BenchNeed
 structure K=BenchSortingFn(D)
 val name="sorting-lazy"
 fun read path=let val input=BinIO.openIn path
                   val bytes=BinIO.inputAll input
                   val _=BinIO.closeIn input
               in BenchUTF8.decode(Byte.bytesToString bytes)end
 fun compareRows left right=case D.force left of K.Q.Nil=>(case D.force right of K.Q.Nil=>EQUAL | _=>LESS)
   | K.Q.Cons(x,xs)=>case D.force right of K.Q.Nil=>GREATER
     | K.Q.Cons(y,ys)=>case Int.compare(D.force x,D.force y)of EQUAL=>compareRows xs ys | result=>result
 fun hashLine values hash=List.foldl(fn(value,h)=>Word64.+(Word64.fromInt value,Word64.*(h,0w31)))hash(values@[10])
 fun run [count,path,fixture]=
   let val n=BenchInput.between(0,3000)(BenchInput.integer count)
       val expected=BenchUTF8.lines(read fixture)
       val lineCount=List.length expected
       fun once()=
         let val input=K.Q.fromList(List.map K.Q.fromList(BenchUTF8.lines(read path)))
             fun consume rows wanted hash=case D.force rows of K.Q.Nil=>
                   if List.null wanted then Word64.toLargeIntX hash else raise Fail "sort lost lines"
               | K.Q.Cons(row,rest)=>case wanted of []=>raise Fail "sort added lines"
                 | want::tail=>let val actual=K.Q.toList(D.force row)
                              in if actual=want then consume rest tail(hashLine actual hash)
                                 else raise Fail "sorted line differs"end
         in consume(K.mangle(fn(a,b)=>compareRows a b)input)expected 0w0 end
       fun loop 0 total=Int.toString n^":"^Int.toString lineCount^":"^IntInf.toString total
         | loop left total=loop(left-1)(IntInf.+(total,once()))
   in loop n(IntInf.fromInt 0)end
   | run _=raise Fail "sorting expects repetitions input-file sorted-fixture"
end

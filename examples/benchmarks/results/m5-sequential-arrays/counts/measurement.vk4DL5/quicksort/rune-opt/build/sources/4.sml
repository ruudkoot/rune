(* Complete result consumption and validation added by the portable drivers. *)
structure BenchOCamlArrayChecks =
struct
  structure K = BenchOCamlArrayKernels
  structure R = BenchOCamlRandom
  fun summary count total (hash:Word32.word) =
    Int.toString count^":"^IntInf.toString total^":"^Word32.toString hash
  fun step (value,(count,total,hash:Word32.word)) =
    (count+1,IntInf.+(total,IntInf.fromInt value),Word32.+(Word32.*(hash,0w131),Word32.fromInt value))
  fun sort make sort n =
    let val state=make()
        val counts=Array.array(n,0)
        val array=Array.tabulate(n,fn _ =>
          let val value=R.integer state n
          in Array.update(counts,value,Array.sub(counts,value)+1);value end)
        val _=sort array
        fun consume i previous accumulator = if i=n then
              if Array.foldl(fn(left,ok)=>left=0 andalso ok)true counts then
                let val(count,total,hash)=accumulator in summary count total hash end
              else raise Fail "sort lost elements"
          else let val value=Array.sub(array,i)
                   val _=if value>=previous andalso value>=0 andalso value<n then ()else raise Fail "sort order differs"
                   val left=Array.sub(counts,value)
                   val _=if left>0 then Array.update(counts,value,left-1)else raise Fail "sort multiplicities differ"
               in consume(i+1)value(step(value,accumulator))end
    in consume 0 ~1(0,IntInf.fromInt 0,0w0)end
  fun expected path =
    let val input=TextIO.openIn path
        val text=TextIO.inputAll input
        val _=TextIO.closeIn input
    in List.map BenchInput.integer(String.tokens Char.isSpace text)end
  fun matrix get size values =
    let fun loop i j remaining accumulator =
          if i=size then
            if List.null remaining then
              let val(count,total,hash)=accumulator in summary count total hash end
            else raise Fail "extra matrix fixture values"
          else if j=size then loop(i+1)0 remaining accumulator
          else case remaining of []=>raise Fail "missing matrix fixture values"
            | want::rest => let val value=get i j
                in if value=want then loop i(j+1)rest(step(value,accumulator))
                   else raise Fail "matrix value differs"end
    in loop 0 0 values(0,IntInf.fromInt 0,0w0)end
  fun multiply size path =
    let val state=R.default()
        fun input ()=Array.tabulate(size,fn _=>Array.tabulate(size,fn _=>R.integer state 100))
        val x=input()
        val y=input()
        val result=Array.tabulate(size,fn _=>Array.array(size,0))
        val _=K.multiply result x y
    in matrix(fn i=>fn j=>Array.sub(Array.sub(result,i),j))size(expected path)end
  fun floyd size path =
    let val state=R.seed512()
        val adjacency=Array.tabulate(size,fn _=>Array.tabulate(size,fn _=>
          if R.integer state 2=0 then K.Infinity else K.Value(R.integer state 100)))
        val _=K.for 0(size-1)(fn i=>Array.update(Array.sub(adjacency,i),i,K.Value 0))
        val _=K.floyd adjacency
        fun get i j=case Array.sub(Array.sub(adjacency,i),j)of K.Infinity=> ~1 | K.Value n=>n
    in matrix get size(expected path)end
end

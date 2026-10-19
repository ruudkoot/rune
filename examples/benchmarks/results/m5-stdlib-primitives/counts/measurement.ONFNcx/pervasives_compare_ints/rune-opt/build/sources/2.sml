structure BenchStdlibPrimitives =
struct
  type statistics = {calls:int,sum:Word32.word,negative:int,zero:int,positive:int}
  fun for first last f=if first>last then () else(f first;for(first+1)last f)
  fun compareInt(a:int,b)=if a<b then ~1 else if a=b then 0 else 1
  fun compareList([],[])=0 | compareList([],_) = ~1 | compareList(_,[])=1
    | compareList(x::xs,y::ys)=let val result=compareInt(x,y)
      in if result=0 then compareList(xs,ys)else result end
  fun order LESS = ~1 | order EQUAL=0 | order GREATER=1
  fun summarize count operation : statistics =
    let val sum=ref(0w0:Word32.word)val negative=ref 0 val zero=ref 0 val positive=ref 0
        val _=for 1 count(fn i=>
          let val value=operation i
          in sum:=Word32.+(!sum,Word32.fromInt value);
             if value<0 then negative:= !negative+1
             else if value=0 then zero:= !zero+1 else positive:= !positive+1 end)
    in {calls=count,sum= !sum,negative= !negative,zero= !zero,positive= !positive}end
  fun render({calls,sum,negative,zero,positive}:statistics)=
    Int.toString calls^":"^Word32.toString sum^":"^Int.toString negative^":"^
    Int.toString zero^":"^Int.toString positive
  fun createArray length =
    let val original=Array.array(length,0)
    in Array.tabulate(length,fn i=>let val _=Array.sub(original,i)in i end)end
  fun validateArray array =
    let fun loop i=if i=Array.length array then true
          else Array.sub(array,i)=i andalso loop(i+1)
    in if loop 0 then ()else raise Fail "incorrect result: stdlib array contents differ"end
  fun arrayForAll test array =
    let fun loop i=if i=Array.length array then true
          else test(Array.sub(array,i))andalso loop(i+1)
    in loop 0 end
  fun arrayOperation name array =
    let val length=Array.length array
    in case name of
      "array_fold"=>(fn _=>Array.foldl(fn(x,total)=>total+x)0 array)
    | "array_iter"=>(fn _=>(Array.app(fn i=>if i>2*length then raise Fail "source array assertion"else())array;0))
    | "array_forall"=>(fn _=>if arrayForAll(fn i=>i<2*length)array then 0
        else raise Fail "source array forall assertion")
    | _=>raise Fail "unknown stdlib array operation"end
  fun runArray name [lengthText,countText] =
    let val length=BenchInput.between(0,10000)(BenchInput.integer lengthText)
        val count=BenchInput.between(0,100000)(BenchInput.integer countText)
        val array=createArray length
        val result=summarize count(arrayOperation name array)
        val _=validateArray array
        val n=IntInf.fromInt length
        val value=if name="array_fold"then IntInf.div(IntInf.*(n,IntInf.-(n,1)),2)else 0
        val expected=IntInf.*(IntInf.fromInt count,value)
    in if #sum result=Word32.fromLargeInt expected then render result
       else raise Fail "incorrect result: stdlib array reduction differs"end
    |runArray _ _=raise Fail "stdlib array expects length and iterations"
  val listA = [1,2,3]
  val listB = [3,1,2]
  fun comparison name =case name of
      "pervasives_compare_lists"=>(fn _=>compareList(listA,listB))
    | "pervasives_compare_ints"=>(fn i=>compareInt(i,42))
    | "pervasives_compare_floats"=>(fn i=>order(Real.compare(Real.fromInt i,5.0)))
    | "pervasives_compare_strings"=>(fn i=>order(String.compare(Int.toString i,"I am a fish.")))
    | "pervasives_equal_ints"=>(fn i=>if i=42 then 1 else 0)
    | _=>raise Fail "unsupported stdlib comparison"
  fun runComparison name [countText] =
    let val count=BenchInput.between(0,1000000)(BenchInput.integer countText)
        val result=summarize count(comparison name)
        val expected=
          if name="pervasives_compare_lists"orelse name="pervasives_compare_strings"then ~count
          else if name="pervasives_equal_ints"then(if count>=42 then 1 else 0)
          else let val pivot=if name="pervasives_compare_ints"then 42 else 5
               in Int.max(count-pivot,0)-Int.min(count,pivot-1)end
    in if #sum result=Word32.fromInt expected then render result
       else raise Fail "incorrect result: stdlib comparison differs"end
    |runComparison _ _=raise Fail "stdlib comparison expects iterations"
end

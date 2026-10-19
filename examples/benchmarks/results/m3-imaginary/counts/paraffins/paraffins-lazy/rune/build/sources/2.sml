structure BenchParaffins =
struct
  fun integers lo hi = if lo>hi then [] else lo::integers(lo+1)hi
  fun triples m = List.concat(List.map(fn i=>List.map(fn j=>(i,j,m-i-j))(integers i ((m-i)div 2)))(integers 0 (m div 3)))
  fun quadruples m = List.concat(List.map(fn i=>List.concat(List.map(fn j=>
    List.map(fn k=>(i,j,k,m-i-j-k))(integers (Int.max(j,Real.ceil(Real.fromInt m/2.0)-i-j)) ((m-i-j)div 2)))
    (integers i ((m-i)div 3))))(integers 0 (m div 4)))
  fun show xs="["^String.concatWith","(List.map Int.toString xs)^"]"
  fun format(a,b,c,d)=show a^"\n"^show b^"\n"^show c^"\n"^show d^"\n"
  fun run calculate [size,reps,reference] =
    let val n=BenchInput.between(1,15)(BenchInput.integer size)
        val r=BenchInput.between(1,1000)(BenchInput.integer reps)
        val _=if List.exists(fn p=>p=reference)["expected/smoke.txt","expected/normal.txt","expected/large.txt"]then()else raise Fail "paraffin reference path"
        val f=TextIO.openIn reference val expected=TextIO.inputAll f val _=TextIO.closeIn f
        fun sum xs=List.foldl(fn(x,a)=>a+x)0 xs
        fun one()=let val result as(a,b,c,d)=calculate n
          in if format result=expected then sum a+sum b+sum c+sum d else raise Fail "paraffin counts differ"end
    in IntInf.toString(BenchInput.repeat r one)end
    |run _ _=raise Fail "paraffins expects carbon-count repetitions reference"
end

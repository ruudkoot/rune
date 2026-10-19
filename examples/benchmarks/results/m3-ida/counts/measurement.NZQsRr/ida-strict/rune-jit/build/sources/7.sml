functor BenchIdaDriverFn(B:sig val calculate:int->int->string->string end)=struct
 fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
 fun run[count,width,path]=
   B.calculate(BenchInput.between(0,3000)(BenchInput.integer count))
     (BenchInput.between(2,3)(BenchInput.integer width))(read path)
   |run _=raise Fail "expected repetition count, puzzle width and reference"
end

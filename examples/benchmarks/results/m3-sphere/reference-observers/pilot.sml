structure A=BenchSphereFn(BenchNeed)
structure B=BenchSphereFn(BenchStrict)
fun show(r,g,b)=Real.toString r^" "^Real.toString g^" "^Real.toString b^"\n"
val _=List.app(fn(_,_,v)=>print(show(A.components v)))(BenchStream.take 3(A.ray 30))
val _=List.app(fn(_,_,v)=>print(show(B.components v)))(BenchStream.take 3(B.ray 30))

structure A=BenchSphereFn(BenchNeed)
structure B=BenchSphereFn(BenchStrict)
val wanted=(0.3873607150475331,0.4792659542441786,0.5909764326374696)
fun check label (r,g,b)=
 let val _=print(label^" "^String.concatWith" "(List.map(Real.fmt(StringCvt.GEN(SOME 17)))[r,g,b])^"\n")
     val(er,eg,eb)=wanted
 in T.check(label,fn()=>List.all(fn(x,e)=>BenchInput.closeReal(x,e,1.0E~9,1.0E~9))[(r,er),(g,eg),(b,eb)])end
val (first,x,y)=A.camera A.lookfrom A.lookat A.vup 45.0 100.0
val _=check"sphere/single-pixel/lazy"(A.components(A.pixel A.world A.lights 33.0 74.0 first x y))
val (first,x,y)=B.camera B.lookfrom B.lookat B.vup 45.0 100.0
val _=check"sphere/single-pixel/strict"(B.components(B.pixel B.world B.lights 33.0 74.0 first x y))

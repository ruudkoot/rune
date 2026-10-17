structure A=BenchLinearFn(BenchNeed)
structure B=BenchLinearFn(BenchStrict)
val _=BenchStream.foldl(fn((count,error,residual),())=>
 print(Int.toString count^" "^Real.fmt(StringCvt.GEN(SOME 9))(A.B.value error)^" "^
 Real.fmt(StringCvt.GEN(SOME 9))(A.B.value residual)^"\n"))()(A.stats 2 10)
val _=BenchStream.foldl(fn((count,error,residual),())=>
 print(Int.toString count^" "^Real.fmt(StringCvt.GEN(SOME 9))(B.B.value error)^" "^
 Real.fmt(StringCvt.GEN(SOME 9))(B.B.value residual)^"\n"))()(B.stats 2 10)

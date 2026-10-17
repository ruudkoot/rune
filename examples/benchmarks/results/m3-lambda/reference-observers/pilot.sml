structure A=BenchLambdaFn(BenchNeed)
structure B=BenchLambdaFn(BenchStrict)
val _=List.app(fn n=>(print(A.evaluate"simple"n);print(A.evaluate"monad"n);
 print(B.evaluate"simple"n);print(B.evaluate"monad"n)))[0,1,10,80]

structure A=BenchLambdaFn(BenchNeed)
structure B=BenchLambdaFn(BenchStrict)
structure DA=BenchLambdaDriverFn(A)
structure DB=BenchLambdaDriverFn(B)
val _=List.app(fn style=>(print(DA.run style["100","260"]^"\\n");print(DB.run style["100","260"]^"\\n")))["simple","monad"]

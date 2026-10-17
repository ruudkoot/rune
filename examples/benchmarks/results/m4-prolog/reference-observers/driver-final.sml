structure K=BenchPrologFn(BenchNeed)
structure Driver=BenchPrologDriverFn(K)
structure Main=struct
val base="tests/out/benchmarks/prolog-originals/"
val _=print(Driver.run false["200",base^"source/runtime_files/stdlib",base^"source/prolog.stdin",base^"stack/normal.text"]^"\n")
val _=print(Driver.run true["200",base^"source/runtime_files/stdlib",base^"source/prolog.stdin",base^"pure/normal.text"]^"\n")
end
structure K=BenchPrologFn(BenchStrict)
structure Driver=BenchPrologDriverFn(K)
structure StrictMain=struct
val base="tests/out/benchmarks/prolog-originals/"
val _=print(Driver.run false["200",base^"source/runtime_files/stdlib",base^"source/prolog.stdin",base^"stack/normal.text"]^"\n")
val _=print(Driver.run true["200",base^"source/runtime_files/stdlib",base^"source/prolog.stdin",base^"pure/normal.text"]^"\n")
end

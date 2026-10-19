structure K=BenchVeritasFn(BenchStrict)
structure Check=BenchVeritasCheckFn(K)
val _=print("RESULT "^Check.run(CommandLine.arguments())^"\n")

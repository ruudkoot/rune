structure K=BenchAnnaFn(BenchStrict)
structure Check=BenchAnnaCheckFn(K)
val _=print("RESULT "^Check.run(CommandLine.arguments())^"\n")

structure K=BenchAnnaFn(BenchNeed)
structure Check=BenchAnnaCheckFn(K)
val _=print("RESULT "^Check.run(CommandLine.arguments())^"\n")

structure K=BenchHpgFn(BenchNeed)
structure Check=BenchHpgCheckFn(K)
val _=if Check.run["100","8","4","10","6","6","5EC4901296811DF0","D97AC3B2A11B93D6","713067A9C6975A3C"]="100"then print"PASS source 100-repetition HPG smoke loop\n"else raise Fail"repetitions"

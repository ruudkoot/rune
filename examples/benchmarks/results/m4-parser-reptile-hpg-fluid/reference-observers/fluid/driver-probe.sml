structure K=BenchFluidFn(BenchNeed)
structure Check=BenchFluidCheckFn(K)
val _=if Check.run["35","/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/nofib-fluid-originals/source/fluid.stdin","9DCE0361F540E943"]="35"then print"PASS source 35-repetition Fluid smoke loop\n"else raise Fail"repetitions"

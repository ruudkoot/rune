structure D=BenchDomFn(struct val checkInitialized=false end)
structure Driver=BenchDomDriverFn(D)
val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/dom-lt-originals/"
val result=Driver.run[base^"source/ghc-examples.in","400",base^"corpus.parents"]
val _=if result="2238783"then print(result^"\n")else raise Fail "normal dominator checksum"

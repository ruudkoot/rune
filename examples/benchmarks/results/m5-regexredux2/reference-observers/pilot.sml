val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/regexredux2-originals/"
val _=List.app(fn profile=>print(profile^" "^BenchRegexRedux2.run[base^profile^".fasta",base^profile^".output"]^"\n"))["smoke","normal","large"]

structure Lazy=BenchMateFn(struct val eagerMoves=false end)
structure Strict=BenchMateFn(struct val eagerMoves=true end)
val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/mate-originals/source/runtime_files/"
val refbase="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/mate-originals/"
fun check(profile,name)=
  let val input=Lazy.read(base^name^".prob")
      val expected=Lazy.read(refbase^profile^".stdout")
      val _=if Lazy.problem("runtime_files/"^name^".prob")input=expected then (print(profile^" lazy PASS\n");TextIO.flushOut TextIO.stdOut)else raise Fail "lazy mismatch"
      val _=if Strict.problem("runtime_files/"^name^".prob")input=expected then (print(profile^" strict PASS\n");TextIO.flushOut TextIO.stdOut)else raise Fail "strict mismatch"
  in ()end
val _=List.app check[("smoke","heathcote3"),("normal","kohtz"),("large","holzhausen")]

val _=print "SUMMARY 6 checks, 0 failed\n"

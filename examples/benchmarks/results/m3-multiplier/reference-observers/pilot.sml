structure Lazy=BenchMultiplierFn(struct val eagerBinary=false end)
structure Strict=BenchMultiplierFn(struct val eagerBinary=true end)
val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/multiplier-originals/"
fun render xs=String.implode(rev(BenchStream.foldl(fn(c,cs)=>c::cs)[]xs))
fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
val expected=read(base^"smoke-short.trace")
val _=if render(Lazy.trace 32 16)=expected then print"lazy PASS\n"else raise Fail"lazy multiplier mismatch"
val _=if render(Strict.trace 32 16)=expected then print"strict PASS\n"else raise Fail"strict multiplier mismatch"

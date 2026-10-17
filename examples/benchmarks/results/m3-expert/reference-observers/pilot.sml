structure Lazy=BenchExpertFn(struct val eagerTerms=false end)
structure Strict=BenchExpertFn(struct val eagerTerms=true end)
fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/expert-originals/"
val animals=read(base^"source/runtime_files/animals")
val replies=read(base^"source/expert.stdin")
fun render xs=String.implode(rev(BenchStream.foldl(fn(c,cs)=>c::cs)[]xs))
val _=TextIO.output(TextIO.stdOut,render(Lazy.processText animals replies))
val _=print "STRICT\n"
val _=TextIO.output(TextIO.stdOut,render(Strict.processText animals replies))

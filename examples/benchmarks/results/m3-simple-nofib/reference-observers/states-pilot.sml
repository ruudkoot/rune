structure Need=BenchSimpleNofibFn(val strict=false val gridMax=100)
structure Strict=BenchSimpleNofibFn(val strict=true val gridMax=100)
fun bits x=
  let val bytes=PackReal64Big.toBytes x
  in String.concat(List.tabulate(8,fn i=>
    let val s=Word8.fmt StringCvt.HEX(Word8Vector.sub(bytes,i))
    in if size s=1 then"0"^s else s end))end
fun emit step out name compute=
  let val(totals,state)=compute step
      val _=List.app(fn cell=>TextIO.output(out,"T\t"^bits(BenchLazy.force cell)^"\n"))totals
      val _=List.app(fn(n,a)=>
        let val b=Need.A.bounds a
            val _=TextIO.output(out,n^"\n")
        in List.app(fn(i,j)=>TextIO.output(out,Int.toString i^","^Int.toString j^"\t"^bits(Need.A.sub a(i,j))^"\n"))(Need.A.positions b)end)(Need.arrays state)
  in()end
fun emitStrict step out name compute=
  let val(totals,state)=compute step
      val _=List.app(fn cell=>TextIO.output(out,"T\t"^bits(BenchLazy.force cell)^"\n"))totals
      val _=List.app(fn(n,a)=>
        let val b=Strict.A.bounds a
            val _=TextIO.output(out,n^"\n")
        in List.app(fn(i,j)=>TextIO.output(out,Int.toString i^","^Int.toString j^"\t"^bits(Strict.A.sub a(i,j))^"\n"))(Strict.A.positions b)end)(Strict.arrays state)
  in()end

val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-0-need.state"
val _=emit 0 out "need" Need.compute
val _=TextIO.closeOut out
val _=print("state 0 need complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-0-strict.state"
val _=emitStrict 0 out "strict" Strict.compute
val _=TextIO.closeOut out
val _=print("state 0 strict complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-2-need.state"
val _=emit 2 out "need" Need.compute
val _=TextIO.closeOut out
val _=print("state 2 need complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-2-strict.state"
val _=emitStrict 2 out "strict" Strict.compute
val _=TextIO.closeOut out
val _=print("state 2 strict complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-5-need.state"
val _=emit 5 out "need" Need.compute
val _=TextIO.closeOut out
val _=print("state 5 need complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-5-strict.state"
val _=emitStrict 5 out "strict" Strict.compute
val _=TextIO.closeOut out
val _=print("state 5 strict complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-20-need.state"
val _=emit 20 out "need" Need.compute
val _=TextIO.closeOut out
val _=print("state 20 need complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-20-strict.state"
val _=emitStrict 20 out "strict" Strict.compute
val _=TextIO.closeOut out
val _=print("state 20 strict complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-100-need.state"
val _=emit 100 out "need" Need.compute
val _=TextIO.closeOut out
val _=print("state 100 need complete\n")
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/state-100-strict.state"
val _=emitStrict 100 out "strict" Strict.compute
val _=TextIO.closeOut out
val _=print("state 100 strict complete\n")

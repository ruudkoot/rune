structure Need=BenchSimpleNofibFn(val strict=false val gridMax=100)
structure Strict=BenchSimpleNofibFn(val strict=true val gridMax=100)
fun bits x=
  let val bytes=PackReal64Big.toBytes x
  in String.concat(List.tabulate(8,fn i=>
    let val s=Word8.fmt StringCvt.HEX(Word8Vector.sub(bytes,i))
    in if size s=1 then"0"^s else s end))end
fun emit out name compute=
  let val(totals,state)=compute 1
      val _=List.app(fn cell=>TextIO.output(out,"T\t"^bits(BenchLazy.force cell)^"\n"))totals
      val _=List.app(fn(n,a)=>
        let val b=Need.A.bounds a
            val _=TextIO.output(out,n^"\n")
        in List.app(fn(i,j)=>TextIO.output(out,Int.toString i^","^Int.toString j^"\t"^bits(Need.A.sub a(i,j))^"\n"))(Need.A.positions b)end)(Need.arrays state)
  in()end
val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/pilot-need.state"
val _=emit out "need" Need.compute
val _=TextIO.closeOut out

fun emitStrict out name compute=
  let val(totals,state)=compute 1
      val _=List.app(fn cell=>TextIO.output(out,"T\t"^bits(BenchLazy.force cell)^"\n"))totals
      val _=List.app(fn(n,a)=>
        let val b=Strict.A.bounds a
            val _=TextIO.output(out,n^"\n")
        in List.app(fn(i,j)=>TextIO.output(out,Int.toString i^","^Int.toString j^"\t"^bits(Strict.A.sub a(i,j))^"\n"))(Strict.A.positions b)end)(Strict.arrays state)
  in()end

val out=TextIO.openOut"tests/out/benchmarks/nofib-simple-originals/pilot-strict.state"
val _=emitStrict out "strict" Strict.compute
val _=TextIO.closeOut out

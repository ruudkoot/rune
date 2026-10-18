structure FulsomPilot=
struct
 structure N=BenchFulsomFn(BenchNeed)
 structure E=BenchFulsomFn(BenchStrict)
 structure S=BenchStream
 structure L=BenchLazy
 fun collect stream=
   let fun loop values stream=case L.force stream of S.Nil=>Word8Vector.fromList(rev values)
         |S.Cons(x,rest)=>let val value=L.force x
             in if value<0 orelse value>255 then raise Fail"raster byte outside0..255"
                else loop(Word8.fromInt value::values)rest end
   in loop[]stream end
 fun output name bytes=
   let val out=BinIO.openOut("tests/out/benchmarks/nofib-fulsom-originals/"^name^".raster")
   in BinIO.output(out,bytes);BinIO.closeOut out;print(name^" "^Int.toString(Word8Vector.length bytes)^"\n");TextIO.flushOut TextIO.stdOut end
 val _=List.app(fn depth=>
   (output("need-"^Int.toString depth)(collect(N.picture depth));
    output("strict-"^Int.toString depth)(collect(E.picture depth))))[0,1,2,3,4,5]
end

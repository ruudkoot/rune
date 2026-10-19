structure K=BenchHpgRandomFn(BenchNeed)
val input=TextIO.openIn "tests/out/benchmarks/nofib-hpg-originals/random-bits.reference"
fun bits r=if Real.==(r,0.0)then 0w0 else
 let val{man,exp}=Real.toManExp r
     val m=Real.round(man*16777216.0)
 in Word32.orb(Word32.<<(Word32.fromInt(exp+126),0w23),Word32.fromInt(m-8388608))end
fun loop 0 xs=()|loop n xs=case BenchNeed.force xs of K.C.Nil=>raise Fail"random EOF"
 |K.C.Cons(x,rest)=>let val expected=case TextIO.inputLine input of SOME line=>
    Word32.fromLargeInt(valOf(IntInf.fromString line))|NONE=>raise Fail"oracle EOF"
   val actual=bits(BenchNeed.force(BenchLazy.force x))
 in if actual=expected then loop(n-1)rest else raise Fail("random word "^Int.toString(10000-n))end
val _=loop 10000(K.random(9807,65,32975))
val _=TextIO.closeIn input
val _=print"PASS all 10000 source Float random numbers\n"

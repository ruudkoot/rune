(* Finite normal binary32 values for nofib hidden; the source Number wraps
   Float, and its comparison methods deliberately do not obey complement laws.
   The selected domain is checked against GHC/Python binary32 fixtures. *)
functor BenchHiddenNumberFn(D:BENCH_SUSPEND) =
struct
  structure F=BenchMandelSingle
  type number=real D.t
  fun literal value=D.delay(fn()=>F.round value)
  val zero=literal 0.0
  val one=literal 1.0
  val eps=F.round 0.0001
  fun add(a,b)=D.delay(fn()=>F.add(D.force a,D.force b))
  fun sub(a,b)=D.delay(fn()=>F.sub(D.force a,D.force b))
  fun mul(a,b)=D.delay(fn()=>F.mul(D.force a,D.force b))
  fun divide(a,b)=D.delay(fn()=>F.divide(D.force a,D.force b))
  fun negative(a:number)=D.delay(fn()=> ~(D.force a))
  fun sqrt a=D.delay(fn()=>F.round(Math.sqrt(D.force a)))
  fun eq(a,b)=Real.abs(F.sub(D.force a,D.force b))<eps
  fun ne(a,b)=Real.abs(F.sub(D.force a,D.force b))>eps
  fun lt(a,b)=D.force a<F.sub(D.force b,eps)
  fun le(a,b)=F.sub(D.force a,eps)<D.force b
  fun compare(a,b)=if eq(a,b)then EQUAL else if le(a,b)then LESS else GREATER
  fun gt pair=compare pair=GREATER
  fun ge pair=compare pair<>LESS
  fun maximum(a,b)=if le(a,b)then b else a
  fun minimum(a,b)=if le(a,b)then a else b
  val value=D.force
  fun bits value=
    let val sign:Word32.word=if Real.signBit value then 0wx80000000 else 0w0
    in if Real.==(value,0.0)then sign else
      let val _=if Real.isFinite value then()else raise Fail "incorrect result: nonfinite hidden coordinate"
          val{man,exp}=Real.toManExp(Real.abs value)
          val _=if exp>= ~125 andalso exp<=128 then()else raise Fail "incorrect result: hidden leaves normal binary32 domain"
          val significand=Real.toInt IEEEReal.TO_ZERO(man*16777216.0)
          val _=if Real.==(Real.fromInt significand,man*16777216.0)then()
            else raise Fail "incorrect result: hidden value is not binary32"
      in Word32.orb(sign,Word32.orb(Word32.<<(Word32.fromInt(exp+126),0w23),Word32.fromInt(significand-8388608)))end
    end
end

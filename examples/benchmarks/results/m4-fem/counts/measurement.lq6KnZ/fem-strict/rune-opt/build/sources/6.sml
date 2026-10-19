(* Original Haskell Float operations rounded after every operation. *)
structure BenchFemFloat=
struct
 val round=BenchLinearFloat.round
 fun add(a,b)=round(a+b)
 fun sub(a,b)=round(a-b)
 fun mul(a,b)=round(a*b)
 fun divide(a,b)=round(a/b)
 fun negative(a:real)= ~a
 fun sqrt x=
   if not(Real.==(x,x))then x
   else if x<0.0 then 0.0/0.0
   else round(Math.sqrt x)
 fun bits x=
   let val sign=if Real.signBit x then 0wx80000000:Word32.word else 0w0
       val magnitude=Real.abs x
       val payload=
         if Real.==(magnitude,0.0)then 0w0
         else if not(Real.isFinite magnitude)then
           if Real.==(x,x)then 0wx7F800000 else 0wx7FC00000
         else let val{man,exp}=Real.toManExp magnitude
              in if exp< ~125 then
                   Word32.fromInt(Real.toInt IEEEReal.TO_NEAREST(Real.fromManExp{man=magnitude,exp=149}))
                 else Word32.orb(Word32.<<(Word32.fromInt(exp+126),0w23),
                   Word32.fromInt(Real.toInt IEEEReal.TO_NEAREST(man*16777216.0)-8388608))end
   in Word32.orb(sign,payload)end
end

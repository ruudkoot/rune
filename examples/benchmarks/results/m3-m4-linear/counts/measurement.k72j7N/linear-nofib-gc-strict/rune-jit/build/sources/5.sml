(* Binary32 arithmetic for the source Float computations, represented in real.
   Both normal and subnormal results are rounded to nearest, ties to even. *)
structure BenchLinearFloat =
struct
  fun round r=
    if Real.==(r,0.0)orelse not(Real.isFinite r)then r else
    let val negative=Real.signBit r val magnitude=Real.abs r
        val{man,exp}=Real.toManExp magnitude
        val result=if exp>128 then Real.posInf
          else if exp< ~125 then
            let val scaled=Real.fromManExp{man=magnitude,exp=149}
                val significand=Real.toInt IEEEReal.TO_NEAREST scaled
            in Real.fromManExp{man=Real.fromInt significand,exp= ~149}end
          else let val significand=Real.toInt IEEEReal.TO_NEAREST(man*16777216.0)
               in if exp=128 andalso significand=16777216 then Real.posInf else
                 Real.fromManExp{man=Real.fromInt significand,exp=exp-24}end
    in if negative then ~result else result end
end

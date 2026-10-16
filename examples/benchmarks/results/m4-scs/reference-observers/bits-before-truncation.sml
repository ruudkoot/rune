structure BenchScsDoubleBits =
struct
  structure Q=BenchScsRational
  structure I=IntInf
  fun bitPattern value=
    let val sign=if Real.signBit value then Q.pow2 63 else I.fromInt 0
    in if Real.isNan value then raise Fail "unexpected NaN"
       else if not(Real.isFinite value)then I.+(sign,I.*(2047,Q.pow2 52))
       else if Real.==(value,0.0)then sign
       else let val {man,exp}=Real.toManExp(Real.abs value)
                val significand=Real.toLargeInt IEEEReal.TO_NEAREST (man*9007199254740992.0)
                val stored=exp+1022
                val magnitude=if stored<=0 then I.quot(significand,Q.pow2(1-stored))
                  else I.+(I.*(I.fromInt stored,Q.pow2 52),I.-(significand,Q.pow2 52))
            in I.+(sign,magnitude)end
    end
end

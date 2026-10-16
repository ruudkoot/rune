structure Probe =
struct
  structure Q=BenchScsRational
  fun large text=valOf(IntInf.fromString(String.translate(fn #"-"=>"~"|c=>String.str c)text))
  val input=TextIO.openIn "rational-bits.data"
  fun loop i=case TextIO.inputLine input of NONE=>()|SOME row=>
    let val(n,d,expected)=case String.tokens Char.isSpace row of[a,b,c]=>(a,b,c)|_=>raise Fail "row"
        val value=Q.real(large n,large d)
        val _=print("CASE "^Int.toString i^" expected="^expected^" real="^Real.fmt(StringCvt.GEN(SOME 17))value^"\n")
        val _=if Real.isFinite value andalso not(Real.==(value,0.0))then
          let val{man,exp}=Real.toManExp(Real.abs value)val scaled=man*9007199254740992.0
          in print("  man="^Real.toString man^" exp="^Int.toString exp^" scaled="^Real.fmt(StringCvt.GEN(SOME 17))scaled^
             " near="^IntInf.toString(Real.toLargeInt IEEEReal.TO_NEAREST scaled)^
             " zero="^IntInf.toString(Real.toLargeInt IEEEReal.TO_ZERO scaled)^"\n")end else()
    in loop(i+1)end
  val _=T.check("probe/binary64-format",fn()=>Real.radix=2 andalso Real.precision=53)
  val _=loop 0
  val _=TextIO.closeIn input
  val _=print("DIRECT minsub="^Real.fmt(StringCvt.GEN(SOME 17))(Real.fromManExp{man=1.0,exp= ~1074})^"\n")
end

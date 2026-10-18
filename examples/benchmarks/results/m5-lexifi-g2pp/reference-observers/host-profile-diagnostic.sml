structure G2HostProfileDiagnostic=
struct
 fun real label value=print(label^" "^Real.fmt(StringCvt.GEN(SOME 17))value^"\n")
 fun run()=
   let val expected=BenchG2Driver.read"smoke.reference"
       val result=BenchG2Driver.calculate 40
       val{g_a,g_b,g_sigma,g_nu,g_rho}= #parameters result
       val _=List.app(fn(label,value)=>real label value)
         [("g_a",g_a),("g_b",g_b),("g_sigma",g_sigma),("g_nu",g_nu),("g_rho",g_rho),("rms",#rms result)]
       val priceError=ref 0.0 val quoteError=ref 0.0
       val _=Array.appi(fn(i,value)=>priceError:=Real.max(!priceError,Real.abs(value-Vector.sub(#prices expected,i))))(#calibrated result)
       val _=Array.appi(fn(i,value)=>quoteError:=Real.max(!quoteError,Real.abs(value-Vector.sub(#quoted expected,i))))(#quoted result)
       val _=real"max-price-absolute-error"(!priceError)
       val _=real"max-market-absolute-error"(!quoteError)
   in T.check("G2/host-profile-valid",fn()=>BenchG2Check.valid result expected)end
 val _=(run()handle ex=>
   (print("calibration-exception "^General.exnName ex^" "^General.exnMessage ex^"\n");
    T.check("G2/host-profile-execution",fn()=>false)))
end

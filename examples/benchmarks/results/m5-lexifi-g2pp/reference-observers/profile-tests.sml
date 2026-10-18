structure G2ProfilePilot=
struct
 fun real value=Real.fmt(StringCvt.GEN(SOME 17))value
 fun test limit path=
   let val expected=BenchG2Driver.read path
       val result=BenchG2Driver.calculate limit
       val{g_a,g_b,g_sigma,g_nu,g_rho}= #parameters result
       val _=print("limit "^Int.toString limit^"\nparameters "^BenchG2Input.join" "(List.map real[g_a,g_b,g_sigma,g_nu,g_rho])^"\nrms "^real(#rms result)^"\n")
       val _=Array.appi(fn(i,value)=>print("price "^Int.toString i^" "^real value^" "^real(Array.sub(#quoted result,i))^"\n"))(#calibrated result)
       val _=BenchG2Check.verify result expected
   in print("PASS full calibration "^Int.toString limit^"\n")end
 val _=test 40"tests/out/benchmarks/lexifi-g2pp-originals/smoke.reference"
 val _=test 2000"tests/out/benchmarks/lexifi-g2pp-originals/normal.reference"
end

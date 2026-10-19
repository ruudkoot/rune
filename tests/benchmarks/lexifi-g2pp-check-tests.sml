structure G2CalibrationCheckTests=
struct
 structure B=BenchG2Check
 val expected=BenchG2Driver.read"smoke.reference"
 val _=T.check("G2/full-original-smoke-calibration",fn()=>B.valid(BenchG2Driver.calculate 40)expected)
 val parameters= #parameters expected
 val result:B.result={
   parameters={g_a=Vector.sub(parameters,0),g_b=Vector.sub(parameters,1),
     g_sigma=Vector.sub(parameters,2),g_nu=Vector.sub(parameters,3),g_rho=Vector.sub(parameters,4)},
   rms= #rms expected,
   calibrated=Array.tabulate(Vector.length(#prices expected),fn i=>Vector.sub(#prices expected,i)),
   quoted=Array.tabulate(Vector.length(#quoted expected),fn i=>Vector.sub(#quoted expected,i))}
 fun changedPrice value=
   let val copy=Array.tabulate(Array.length(#calibrated result),fn i=>Array.sub(#calibrated result,i))
       val _=Array.update(copy,0,value)
   in {parameters= #parameters result,rms= #rms result,quoted= #quoted result,calibrated=copy}end
 val first=Array.sub(#calibrated result,0)
 val bound=1.0E~9+1.0E~8*Real.abs(Vector.sub(#prices expected,0))
 val _=T.check("G2/price-positive-perturbation-rejected",fn()=>not(B.valid(changedPrice(first+2.0*bound))expected))
 val _=T.check("G2/price-negative-perturbation-rejected",fn()=>not(B.valid(changedPrice(first-2.0*bound))expected))
 val _=T.check("G2/price-small-roundoff-accepted",fn()=>B.valid(changedPrice(first+0.1*bound))expected)
 val _=T.check("G2/NaN-price-rejected",fn()=>not(B.valid(changedPrice(Real.posInf-Real.posInf))expected))
 val _=T.check("G2/infinite-price-rejected",fn()=>not(B.valid(changedPrice Real.posInf)expected))
 val _=T.check("G2/corrupt-rms-rejected",fn()=>
   not(B.valid{parameters= #parameters result,rms= #rms result+0.001,
       quoted= #quoted result,calibrated= #calibrated result}expected))
 val _=T.check("G2/corrupt-model-parameter-rejected",fn()=>
   let val{g_a,g_b,g_sigma,g_nu,g_rho}= #parameters result
   in not(B.valid{parameters={g_a=g_a,g_b=g_b,g_sigma=g_sigma,g_nu=g_nu,g_rho=g_rho+0.001},
       rms= #rms result,quoted= #quoted result,calibrated= #calibrated result}expected)end)
 val _=T.check("G2/corrupt-market-price-rejected",fn()=>
   let val copy=Array.tabulate(Array.length(#quoted result),fn i=>Array.sub(#quoted result,i))
       val _=Array.update(copy,0,Array.sub(copy,0)+2.0*(1.0E~9+1.0E~8*Real.abs(Vector.sub(#quoted expected,0))))
   in not(B.valid{parameters= #parameters result,rms= #rms result,quoted=copy,
       calibrated= #calibrated result}expected)end)
end

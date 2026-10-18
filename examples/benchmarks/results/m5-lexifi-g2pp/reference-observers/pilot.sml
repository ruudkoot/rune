val result=BenchG2Calibration.calibrate NONE 40 BenchG2Input.today BenchG2Input.quotes BenchG2Input.variables BenchG2Input.zc
val {g_a,g_b,g_sigma,g_nu,g_rho}= #parameters result
val _=print(BenchG2Input.join" "(List.map(Real.fmt(StringCvt.GEN(SOME 17)))[g_a,g_b,g_sigma,g_nu,g_rho,#rms result])^"\n")

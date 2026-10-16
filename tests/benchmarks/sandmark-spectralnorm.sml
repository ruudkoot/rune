structure SpectralPilot =
struct
 structure K=BenchSpectralNorm
 val close=Benchmark.close
 val _=T.check("spectralnorm/one",fn()=>Real.==(K.run 1,1.0))
 val _=T.check("spectralnorm/coefficient",fn()=>Real.==(K.eval_A 0 0,1.0)andalso Real.==(K.eval_A 1 0,1.0/3.0))
 val _=T.check("spectralnorm/analytic-two",fn()=>
   let val a=10.0/9.0
       val b=17.0/30.0
       val d=29.0/100.0
       val eigen=(a+d+Math.sqrt((a-d)*(a-d)+4.0*b*b))/2.0
   in close(K.run 2)(Math.sqrt eigen)end)
 val _=T.check("spectralnorm/original-eight",fn()=>close(K.run 8)1.2700463058540765)
 val _=T.check("spectralnorm/check-perturbed",fn()=>not(close 1.2742242 1.2742241527925133))
 val _=T.check("spectralnorm/check-nan",fn()=>not(close(Real.posInf-Real.posInf)1.0))
 val _=T.check("spectralnorm/check-infinity",fn()=>not(close Real.posInf 1.0))
end

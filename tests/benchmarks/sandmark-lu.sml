structure BenchLUTests =
struct
 structure K=BenchSandmarkLU
 fun reals [] []=true
   | reals(x::xs)(y::ys)=Real.==(x,y)andalso reals xs ys
   | reals _ _=false
 fun values array=Array.foldr op:: [] array
 val original=Array.fromList[4.0,3.0,6.0,3.0]
 val packed=K.lup 2 original
 val(lower,upper)=K.split 2 packed
 val _=T.check("lu/packed-two-by-two",fn()=>reals(values packed)[4.0,3.0,1.5,~1.5])
 val _=T.check("lu/lower",fn()=>reals(values lower)[1.0,0.0,1.5,1.0])
 val _=T.check("lu/upper",fn()=>reals(values upper)[4.0,3.0,0.0,~1.5])
 val _=T.check("lu/preserves-input-copy",fn()=>reals(values original)[4.0,3.0,6.0,3.0])
 val _=T.check("lu/singleton",fn()=>reals(values(K.lup 1(Array.fromList[7.0])))[7.0])
 val _=T.check("lu/identity",fn()=>let val a=K.create 3(fn i=>fn j=>if i=j then 1.0 else 0.0)
   in reals(values(K.lup 3 a))(values a)end)
 val _=T.check("lu/check-exact",fn()=>Benchmark.close 4.0 4.0)
 val _=T.check("lu/check-small-accepted-rounding",fn()=>Benchmark.close(1.0+5.0E~10)1.0)
 val _=T.check("lu/check-absolute-perturbation",fn()=>not(Benchmark.close(1.0+2.0E~9)1.0))
 val _=T.check("lu/check-relative-accepted-rounding",fn()=>Benchmark.close(1000000.0+0.00005)1000000.0)
 val _=T.check("lu/check-relative-perturbation",fn()=>not(Benchmark.close(1000000.0+0.001)1000000.0))
 val _=T.check("lu/check-infinity",fn()=>not(Benchmark.close Real.posInf 1.0))
 val _=T.check("lu/check-nan",fn()=>not(Benchmark.close(Real.posInf-Real.posInf)1.0))
 val _=T.check("lu/check-nonfinite-reference",fn()=>not(Benchmark.close 1.0 Real.posInf))
end

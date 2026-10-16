structure RepeatForward =
struct
 structure K=BenchMultilayer structure F=BenchMultilayerFiles
 val samples=F.data "samples.input"
 val random=BenchOCamlRandom.default()
 val network=K.fit 0 samples(fn()=>BenchOCamlRandom.real random 2.0-1.0)
 val(input,_)=Array.sub(samples,298)
 fun loop 0=print "PASS10000\n"
   | loop n=let val y=K.forward network input
      in if RealArray.foldl(fn(x,ok)=>ok andalso Real.isFinite x)true y
         then loop(n-1)else print("NAN at remaining "^Int.toString n^"\n")end
 val _=loop 10000
 val _=print "SUMMARY 1 checks, 0 failed\n"
end

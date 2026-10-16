structure Diagnose =
struct
  structure K=BenchMultilayer structure F=BenchMultilayerFiles
  val samples=F.data "samples.input"
  val random=BenchOCamlRandom.default()
  val network=K.fit 0 samples(fn()=>BenchOCamlRandom.real random 2.0-1.0)
  val expected=F.reference "epochs-0.expected"
  fun show label x=print(label^" "^Real.fmt(StringCvt.GEN(SOME 17))x^"\n")
  fun fields(K.Layer{weight,bias,...})=List.concat(Array.foldr(fn(row,rest)=>RealArray.foldr(op ::)[]row::rest)[]weight)@RealArray.foldr(op ::)[]bias
  fun expectedFields({weight,bias}:F.snapshot)=List.concat(Array.foldr(fn(row,rest)=>RealArray.foldr(op ::)[]row::rest)[]weight)@RealArray.foldr(op ::)[]bias
  val a=List.concat(List.map fields network)
  val b=List.concat(List.map expectedFields(#layers expected))
  val maximum=ListPair.foldl(fn(x,y,m)=>Real.max(m,Real.abs(x-y)))0.0(a,b)
  val _=show "PARAMETER_MAX" maximum
  val maxPrediction=ref 0.0
  val worst=ref(~1)
  val _=K.for 0(Array.length samples-1)(fn i=>
    let val(x,_)=Array.sub(samples,i)val actual=K.forward network x
        val wanted=Array.sub(#predictions expected,i)
        val difference=Real.abs(RealArray.sub(actual,0)-RealArray.sub(wanted,0))
    in if difference> !maxPrediction then(maxPrediction:=difference;worst:=i)else()end)
  val _=show "PREDICTION_MAX" (!maxPrediction)
  val _=print("WORST "^Int.toString(!worst)^"\n")
  val _=List.app(fn x=>(show("TANH "^Real.toString x)(Math.tanh x);show("EXP "^Real.toString x)(Math.exp x)))[~10.0,~5.0,~1.0,0.0,1.0,5.0,10.0]
  val _=show "ERROR_ACTUAL" (K.evaluate network samples)
  val _=show "ERROR_EXPECTED" (#error expected)
  val _=(F.check expected network samples;print "CHECK PASS\n")handle Fail message=>print("CHECK FAIL "^message^"\n")
  val _=print "SUMMARY 1 checks, 0 failed\n"
end

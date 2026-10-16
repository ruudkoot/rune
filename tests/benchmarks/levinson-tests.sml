structure LevinsonTests =
struct
  structure K=BenchLevinson
  structure F=BenchLevinsonFiles
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~13,1.0E~13)
  fun array expected actual =
    RealArray.length actual=List.length expected andalso
    List.all(fn i=>close(RealArray.sub(actual,i),List.nth(expected,i)))
      (List.tabulate(List.length expected,fn i=>i))
  fun rejects f=(f();false)handle Fail _=>true
  val _=T.check("levinson/exact-autocorrelation-and-zero-lags",fn()=>
    array[14.0,8.0,3.0,0.0,0.0](K.autocorr(RealArray.fromList[1.0,2.0,3.0])4))
  val _=T.check("levinson/empty-correlation-rejected",fn()=>
    rejects(fn()=>ignore(K.levinson(RealArray.fromList[]))))
  val _=T.check("levinson/zero-order-core",fn()=>
    let val(ar,sigma)=K.levinson(RealArray.fromList[3.0])
    in RealArray.length ar=0 andalso close(sigma,3.0)end)
  val _=T.check("levinson/white-correlation",fn()=>
    let val(ar,sigma)=K.levinson(RealArray.fromList[3.0,0.0,0.0,0.0])
    in array[0.0,0.0,0.0]ar andalso close(sigma,3.0)end)
  val _=T.check("levinson/first-order-process",fn()=>
    let val(ar,sigma)=K.levinson(RealArray.fromList[4.0,2.0,1.0])
    in array[0.5,0.0]ar andalso close(sigma,3.0)end)
  val _=T.check("levinson/fresh-array-reflection",fn()=>
    let val(ar,sigma)=K.levinson(RealArray.fromList[30.0,20.0,11.0,4.0])
    in array[610.0/817.0,~551.0/8170.0,~78.0/817.0]ar
      andalso close(sigma,132281.0/8170.0)end)
  val _=T.check("levinson/wrapper-preserves-order-plus-one",fn()=>
    let val(ar,sigma)=K.coefficients(RealArray.fromList[1.0,2.0,3.0])0
    in array[4.0/7.0]ar andalso close(sigma,66.0/7.0)end)
  val _=T.check("levinson/input-correlation-unmodified",fn()=>
    let val r=RealArray.fromList[30.0,20.0,11.0,4.0]val _=K.levinson r
    in array[30.0,20.0,11.0,4.0]r end)
  val reference={label="test",ar=RealArray.fromList[0.5],sigma=0.75}
  val _=T.check("levinson/reject-perturbed-coefficient",fn()=>
    rejects(fn()=>F.check reference(RealArray.fromList[0.50001],0.75)))
  val _=T.check("levinson/reject-perturbed-variance",fn()=>
    rejects(fn()=>F.check reference(RealArray.fromList[0.5],0.7501)))
  val _=T.check("levinson/reject-wrong-length",fn()=>
    rejects(fn()=>F.check reference(RealArray.fromList[],0.75)))
  val _=T.check("levinson/reject-nonfinite",fn()=>
    rejects(fn()=>F.check reference(RealArray.fromList[Real.posInf],0.75)))
  val _=T.check("levinson/coefficient-boundary",fn()=>
    BenchInput.closeReal(2.0E~9,0.0,2.0E~9,2.0E~8)andalso
    not(BenchInput.closeReal(4.0E~9,0.0,2.0E~9,2.0E~8)))
end

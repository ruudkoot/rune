structure MultilayerTests =
struct
  structure K=BenchMultilayer
  structure F=BenchMultilayerFiles
  fun vector values=RealArray.fromList values
  fun matrix rows=Array.fromList(List.map vector rows)
  fun near(a,b)=BenchInput.closeReal(a,b,1.0E~12,1.0E~12)
  fun rejects f=(f();false)handle Fail _=>true
  fun tiny()=[
    K.Layer{activate=K.tanh,derivative=K.tanhPrime,weight=matrix[[0.1,~0.2],[0.3,0.4]],bias=vector[0.01,~0.02]},
    K.Layer{activate=K.softmax,derivative=K.softmaxPrime,weight=matrix[[0.2,~0.1],[~0.3,0.25]],bias=vector[0.03,~0.04]}]
  val input=vector[0.5,~0.7]val target=vector[1.0,0.0]
  fun parameterRows(K.Layer{weight,bias,...})=Array.foldr(op ::)[bias]weight
  fun finiteDifferences network=
    let val analytic=K.backprop network input target
        fun layer [] []=true
          | layer((x,delta)::rest)((current as K.Layer{weight,bias,...})::tail)=
            let val dw=K.ger delta x
                val pairs=ListPair.zip(parameterRows current,Array.foldr(op ::)[delta]dw)
                fun row(values,derivatives)=
                  List.all(fn i=>
                    let val old=RealArray.sub(values,i)val epsilon=1.0E~5
                        val _=RealArray.update(values,i,old+epsilon)
                        val plus=K.error(K.forward network input)target
                        val _=RealArray.update(values,i,old-epsilon)
                        val minus=K.error(K.forward network input)target
                        val _=RealArray.update(values,i,old)
                        val numerical=(plus-minus)/(2.0*epsilon)
                    in BenchInput.closeReal(RealArray.sub(derivatives,i),numerical,1.0E~7,1.0E~5)end)
                    (List.tabulate(RealArray.length values,fn i=>i))
            in List.all row pairs andalso layer rest tail end
          | layer _ _=false
    in layer analytic network end
  val _=T.check("multilayer/all-parameter-gradient-differences",fn()=>finiteDifferences(tiny()))
  val _=T.check("multilayer/softmax-normalization",fn()=>
    let val y=K.softmax(vector[1.0,2.0,~1.0])
    in near(K.mapSum(fn x=>x)y,1.0)andalso List.all(fn i=>RealArray.sub(y,i)>0.0)[0,1,2]end)
  val _=T.check("multilayer/softmax-jacobian-rows",fn()=>
    let val y=K.softmax(vector[0.4,~0.2])val d=K.softmaxPrime y
    in near(K.mapSum(fn x=>x)(Array.sub(d,0)),0.0)andalso
       near(K.mapSum(fn x=>x)(Array.sub(d,1)),0.0)end)
  val _=T.check("multilayer/tanh-jacobian",fn()=>
    let val z=vector[0.5,~0.25]val d=K.tanhPrime z
    in near(RealArray.sub(Array.sub(d,0),0),0.75)andalso
       near(RealArray.sub(Array.sub(d,1),1),0.9375)andalso
       near(RealArray.sub(Array.sub(d,0),1),0.0)end)
  val _=T.check("multilayer/one-step-lowers-loss",fn()=>
    let val network=tiny()val lossBefore=K.error(K.forward network input)target
        val _=K.train 0.01 network input target
        val after=K.error(K.forward network input)target
    in Real.isFinite after andalso after<lossBefore end)
  val _=T.check("multilayer/empty-network-rejected",fn()=>
    rejects(fn()=>ignore(K.backprop[]input target)))
  val _=T.check("multilayer/initial-all-parameters-source-order",fn()=>
    let val random=BenchOCamlRandom.default()
        val network=K.initialize(fn()=>BenchOCamlRandom.real random 2.0-1.0)34 2
        val actual=List.concat(List.map(fn layer=>List.concat(List.map(fn row=>RealArray.foldr(op ::)[]row)(parameterRows layer)))network)
        val expected=List.map F.real(F.tokens "initial-parameters.txt")
    in List.length actual=417 andalso ListPair.allEq Real.==(actual,expected)end)
  val wanted=[{weight=matrix[[0.1,0.2]],bias=vector[0.0]}]
  fun actual weight bias=[K.Layer{activate=K.tanh,derivative=K.tanhPrime,weight=weight,bias=bias}]
  val _=T.check("multilayer/perturbed-weight-rejected",fn()=>
    rejects(fn()=>F.checkParameters wanted(actual(matrix[[0.101,0.2]])(vector[0.0]))))
  val _=T.check("multilayer/perturbed-bias-rejected",fn()=>
    rejects(fn()=>F.checkParameters wanted(actual(matrix[[0.1,0.2]])(vector[0.001]))))
  val _=T.check("multilayer/missing-parameter-rejected",fn()=>
    rejects(fn()=>F.checkParameters wanted(actual(matrix[[0.1]])(vector[0.0]))))
  val _=T.check("multilayer/nonfinite-parameter-rejected",fn()=>
    rejects(fn()=>F.checkParameters wanted(actual(matrix[[Real.posInf,0.2]])(vector[0.0]))))
  val _=T.check("multilayer/value-tolerance-boundary",fn()=>
    BenchInput.closeReal(2.0E~8,0.0,2.0E~8,2.0E~7)andalso
    not(BenchInput.closeReal(4.0E~8,0.0,2.0E~8,2.0E~7)))
end

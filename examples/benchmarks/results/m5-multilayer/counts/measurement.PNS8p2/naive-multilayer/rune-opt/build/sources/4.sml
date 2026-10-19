(* Sequential full-Jacobian backpropagation and gradient-matrix SGD. *)
structure BenchMultilayer =
struct
  type vector=RealArray.array
  type matrix=vector array
  type sample=vector*vector
  datatype layer=Layer of {activate:vector->vector,derivative:vector->matrix,
    weight:matrix,bias:vector}
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun initMatrix m n f=Array.tabulate(m,fn i=>RealArray.tabulate(n,fn j=>f i j))
  fun map f x=RealArray.tabulate(RealArray.length x,fn i=>f(RealArray.sub(x,i)))
  fun map2 f x y=RealArray.tabulate(RealArray.length x,fn i=>f(RealArray.sub(x,i))(RealArray.sub(y,i)))
  fun mapSum f x=RealArray.foldl(fn(xi,acc)=>acc+f xi)0.0 x
  fun map2Sum f x y=
    let val acc=ref 0.0
        val _=for 0 (RealArray.length x-1)(fn i=>acc:= !acc+f(RealArray.sub(x,i))(RealArray.sub(y,i)))
    in !acc end
  fun dot x y=map2Sum(fn xi=>fn yi=>xi*yi)x y
  fun axpy alpha x y=for 0 (RealArray.length x-1)(fn i=>
    RealArray.update(y,i,alpha*RealArray.sub(x,i)+RealArray.sub(y,i)))
  fun gemv a x y=RealArray.tabulate(Array.length a,fn i=>dot(Array.sub(a,i))x+RealArray.sub(y,i))
  fun gemvT a x=
    let val n=if Array.length a=0 then 0 else RealArray.length(Array.sub(a,0))
        val y=RealArray.array(n,0.0)
        val _=for 0 (Array.length a-1)(fn i=>axpy(RealArray.sub(x,i))(Array.sub(a,i))y)
    in y end
  fun ger x y=Array.tabulate(RealArray.length x,fn i=>
    let val xi=RealArray.sub(x,i)in map(fn yi=>xi*yi)y end)
  fun forward layers input=List.foldl(fn(Layer{activate,weight,bias,...},x)=>activate(gemv weight x bias))input layers
  fun error y target= ~(map2Sum(fn ti=>fn yi=>ti*Math.ln yi)target y)
  fun errorPrime y target=map2(fn yi=>fn ti=> ~ti/yi)y target
  fun backprop layers input target=
    let fun delta _ []=raise Fail "empty neural network"
          | delta x [Layer{activate,derivative,weight,bias}]=
            let val y=activate(gemv weight x bias)
                val gradient=errorPrime y target
                val jacobian=derivative y
            in(gemvT jacobian gradient,[])end
          | delta x (Layer{activate,derivative,weight,bias}::
              (rest as Layer{weight=upperWeight,...}::_))=
            let val y=activate(gemv weight x bias)
                val(upperDelta,tail)=delta y rest
                val propagated=gemvT upperWeight upperDelta
                val jacobian=derivative y
                val current=gemvT jacobian propagated
            in(current,(y,upperDelta)::tail)end
        val(first,rest)=delta input layers
    in(input,first)::rest end
  fun train eta layers input target=
    let val alpha= ~eta val gradients=backprop layers input target
        fun update [] []=()
          | update((x,delta)::rest)(Layer{weight,bias,...}::tail)=
            let val dw=ger delta x
                val _=for 0 (Array.length dw-1)(fn i=>axpy alpha(Array.sub(dw,i))(Array.sub(weight,i)))
                val _=axpy alpha delta bias
            in update rest tail end
          | update _ _=raise Fail "neural gradient dimensions differ"
    in update gradients layers end
  fun tanh x=map Math.tanh x
  fun tanhPrime z=
    let val n=RealArray.length z in initMatrix n n(fn i=>fn j=>
      if i=j then 1.0-RealArray.sub(z,i)*RealArray.sub(z,i)else 0.0)end
  fun softmax x=
    let val y=map Math.exp x val c=1.0/mapSum(fn yi=>yi)y
    in map(fn yi=>c*yi)y end
  fun softmaxPrime z=
    let val n=RealArray.length z in initMatrix n n(fn i=>fn j=>
      if i=j then(1.0-RealArray.sub(z,i))*RealArray.sub(z,i)
      else ~(RealArray.sub(z,i)*RealArray.sub(z,j)))end
  fun makeLayer draw activate derivative dim1 dim2=
    let val bias=RealArray.tabulate(dim2,fn _=>draw())
        val weight=initMatrix dim2 dim1(fn _=>fn _=>draw())
    in Layer{activate=activate,derivative=derivative,weight=weight,bias=bias}end
  fun initialize draw inputDim outputDim=
    let val output=makeLayer draw softmax softmaxPrime 5 outputDim
        val hidden2=makeLayer draw tanh tanhPrime 10 5
        val hidden1=makeLayer draw tanh tanhPrime inputDim 10
    in[hidden1,hidden2,output]end
  fun fit epochs samples draw=
    let val(input,target)=Array.sub(samples,0)
        val layers=initialize draw(RealArray.length input)(RealArray.length target)
        val _=for 1 epochs(fn _=>Array.app(fn(x,t)=>train 0.01 layers x t)samples)
    in layers end
  fun evaluate layers samples=Array.foldl(fn((x,target),acc)=>acc+error(forward layers x)target)0.0 samples
end

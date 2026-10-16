structure SmallptTests =
struct
  structure K=BenchSmallpt structure C=SmallptCheck
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~12,1.0E~12)
  fun vector(a,b,c)(x,y,z)=close(a,x)andalso close(b,y)andalso close(c,z)
  fun rejects f=(f();false)handle Fail _=>true
  val sphere=K.Sphere(1.0,K.zero,K.zero,(0.5,0.5,0.5),K.Diffuse)
  val _=T.check("smallpt/vector-operations",fn()=>
    vector(K.add((1.0,2.0,3.0),(4.0,5.0,6.0)))(5.0,7.0,9.0)andalso
    vector(K.cross((1.0,0.0,0.0),(0.0,1.0,0.0)))(0.0,0.0,1.0)andalso
    close(K.dot((1.0,2.0,3.0),(4.0,5.0,6.0)),32.0))
  val _=T.check("smallpt/normalization",fn()=>close(K.length(K.normalize(1.0,2.0,3.0)),1.0))
  val _=T.check("smallpt/sphere-near-hit",fn()=>close(K.intersect((0.0,0.0,~3.0),(0.0,0.0,1.0))sphere,2.0))
  val _=T.check("smallpt/sphere-inside-far-hit",fn()=>close(K.intersect(K.zero,(0.0,0.0,1.0))sphere,1.0))
  val _=T.check("smallpt/sphere-miss",fn()=>Real.==(K.intersect((0.0,2.0,~3.0),(0.0,0.0,1.0))sphere,Real.posInf))
  val _=T.check("smallpt/intersection-epsilon",fn()=>close(K.intersect((0.0,0.0,~1.00001),(0.0,0.0,1.0))sphere,2.00001))
  val _=T.check("smallpt/full-rng-states-and-values",fn()=>
    let val input=TextIO.openIn "random.expected"val text=TextIO.inputAll input val _=TextIO.closeIn input
        val fields=String.tokens Char.isSpace text
        fun loop []=true
          | loop(y::index::word::value::rest)=
            let val row=BenchInput.integer y val step=BenchInput.integer index
                val state=ref(K.seed row)
                fun draws 0 value=value|draws n _=draws(n-1)(K.random state)
                val actual=draws(step+1)0.0
                val reference=C.real value
            in Word64.toString(!state)=String.map Char.toUpper word andalso
              Real.==(actual,reference)andalso loop rest end
          | loop _=false
    in loop fields end)
  val _=T.check("smallpt/complete-smoke-rgb",fn()=>(C.run 16 12 1 "16-12-1.rgb";true))
  val _=T.check("smallpt/zero-samples-stay-black",fn()=>
    let val pixels=ref[]val _=K.render 1 1 0(fn _=>fn row=>pixels:=row)
    in case !pixels of[value]=>vector value K.zero|_=>false end)
  val _=T.check("smallpt/perturbed-pixel-rejected",fn()=>rejects(fn()=>C.run 16 12 1 "wrong-pixel.rgb"))
  val _=T.check("smallpt/perturbed-channel-sum-rejected",fn()=>rejects(fn()=>C.run 16 12 1 "wrong-sum.rgb"))
  val _=T.check("smallpt/truncated-reference-rejected",fn()=>rejects(fn()=>C.run 16 12 1 "truncated.rgb"))
  val _=T.check("smallpt/extra-reference-rejected",fn()=>rejects(fn()=>C.run 16 12 1 "extra.rgb"))
end

structure RootTests =
struct
  structure C=BenchDurandKerner
  structure F=BenchDurandKernerFiles
  fun near a b=C.norm2(C.sub(a,b))<1.0E~20
  fun rejects f=(f();false)handle Fail _=>true
  val reference={count=2,tolerance=1.0E~5,roots=Array.fromList[(1.0,0.0),(~1.0,0.0)]}
  val _=T.check("durand-kerner/complex-polynomial",fn()=>
    near(C.polynomial(Array.fromList[(1.0,0.0),(2.0,0.0),(3.0,0.0)])(0.0,1.0))(2.0,2.0))
  val _=T.check("durand-kerner/scaled-complex-division",fn()=>
    near(C.divide((1.0E300,1.0E300),(1.0E300,1.0E300)))(1.0,0.0))
  val _=T.check("durand-kerner/initial-circle-and-center",fn()=>
    let val zs=C.initial 1000.0(Array.fromList[(2.0,0.0),(5.0,0.0),(0.0,0.0)])
        val a=Array.sub(zs,0)val b=Array.sub(zs,1)
    in C.norm2(C.sub(C.add(a,b),(~2.5,0.0)))<1.0E~16 andalso
      Real.abs(C.norm2(C.sub(a,(~1.25,0.0)))-1000000.0)<1.0E~6 end)
  val _=T.check("durand-kerner/short-coefficients-rejected",fn()=>
    rejects(fn()=>ignore(C.initial 1000.0(Array.fromList[(1.0,0.0)]))))
  val _=T.check("durand-kerner/squared-strict-stopping-boundary",fn()=>
    let val a=Array.fromList[(0.0,0.0)]val b=Array.fromList[(0.5,0.0)]
    in not(C.allClose 0.25 a b)andalso C.allClose 0.250001 a b end)
  val _=T.check("durand-kerner/mismatched-vectors-rejected",fn()=>
    rejects(fn()=>ignore(C.allClose 1.0(Array.fromList[(0.0,0.0)])(Array.fromList[]))))
  val _=T.check("durand-kerner/linear-complex-root",fn()=>
    let val roots=C.roots(Array.fromList[(1.0,0.0),(~2.0,~3.0)])
    in Array.length roots=1 andalso near(Array.sub(roots,0))(2.0,3.0)end)
  val _=T.check("durand-kerner/quadratic-roots",fn()=>
    (F.check reference(C.roots(Array.fromList[(1.0,0.0),(0.0,0.0),(~1.0,0.0)]));true))
  val _=T.check("durand-kerner/root-permutation-accepted",fn()=>
    (F.check reference(Array.fromList[(~1.0,0.0),(1.0,0.0)]);true))
  val _=T.check("durand-kerner/duplicate-root-rejected",fn()=>
    rejects(fn()=>F.check reference(Array.fromList[(1.0,0.0),(1.0,0.0)])))
  val _=T.check("durand-kerner/missing-root-rejected",fn()=>
    rejects(fn()=>F.check reference(Array.fromList[(1.0,0.0)])))
  val _=T.check("durand-kerner/perturbed-root-rejected",fn()=>
    rejects(fn()=>F.check reference(Array.fromList[(1.001,0.0),(~1.0,0.0)])))
  val _=T.check("durand-kerner/nonfinite-root-rejected",fn()=>
    rejects(fn()=>F.check reference(Array.fromList[(Real.posInf,0.0),(~1.0,0.0)])))
end

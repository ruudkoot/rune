structure MatrixTests =
struct
  structure Q=BenchHouseholderQR
  structure C=BenchCrout
  structure M=BenchMatrixFiles
  fun matrix rows=Array.fromList(List.map RealArray.fromList rows)
  fun rejects f=(f();false)handle Fail _=>true
  fun same expected actual=(M.check 1.0E~12 1.0E~12 expected actual;true)
  val a=matrix[[1.0,2.0],[3.0,4.0],[5.0,7.0]]
  val _=T.check("numerical-matrix/QR-rectangular",fn()=>(BenchQRCheck.run a;true))
  val _=T.check("numerical-matrix/QR-wide",fn()=>
    (BenchQRCheck.run(matrix[[1.0,2.0,3.0],[3.0,4.0,7.0]]);true))
  val _=T.check("numerical-matrix/QR-input-unmodified",fn()=>
    let val _=Q.qr a in same(matrix[[1.0,2.0],[3.0,4.0],[5.0,7.0]])a end)
  val _=T.check("numerical-matrix/QR-negative-zero-sign",fn()=>
    let val(q,r)=Q.qr(matrix[[0.0],[1.0]])
    in same(matrix[[0.0,~1.0],[~1.0,0.0]])q andalso same(matrix[[~1.0],[0.0]])r end)
  val _=T.check("numerical-matrix/Householder-reflection",fn()=>
    same(matrix[[~1.0,0.0],[0.0,1.0]])
      (Q.householder(RealArray.fromList[1.0,0.0])(RealArray.fromList[~1.0,0.0])))
  val _=T.check("numerical-matrix/reject-nonorthogonal-Q",fn()=>
    let val(q,r)=Q.qr a val _=RealArray.update(Array.sub(q,0),0,2.0)
    in rejects(fn()=>BenchQRCheck.factors a q r)end)
  val _=T.check("numerical-matrix/reject-nontriangular-R",fn()=>
    let val(q,r)=Q.qr a val _=RealArray.update(Array.sub(r,1),0,0.01)
    in rejects(fn()=>BenchQRCheck.factors a q r)end)
  val _=T.check("numerical-matrix/Crout-pivot-and-input",fn()=>
    let val x=matrix[[0.0,2.0],[1.0,3.0]]val(p,lu)=C.lup x
    in Array.foldr(op ::)[]p=[1,0] andalso same(matrix[[1.0,3.0],[0.0,2.0]])lu
      andalso same(matrix[[0.0,2.0],[1.0,3.0]])x andalso same x(C.main x)end)
  val _=T.check("numerical-matrix/Crout-wide",fn()=>
    let val x=matrix[[2.0,1.0,3.0],[1.0,4.0,7.0]]
    in same x(C.main x)end)
  val _=T.check("numerical-matrix/Crout-raw-pivot-counterexample",fn()=>
    let val x=matrix[[2.0,2.0,0.0],[1.0,1.0,1.0],[1.0,0.0,1.0]]
    in same(matrix[[2.0,2.0,0.0],[1.0,1.0,1.0],[1.0,1.0,1.0]])(C.main x)end)
  val _=T.check("numerical-matrix/reject-perturbed-result",fn()=>
    rejects(fn()=>M.check 1.0E~9 1.0E~10 (matrix[[1.0]])(matrix[[1.00001]])))
  val _=T.check("numerical-matrix/reject-infinite-result",fn()=>
    rejects(fn()=>M.check 1.0E~9 1.0E~10 (matrix[[1.0]])(matrix[[Real.posInf]])))
  val _=T.check("numerical-matrix/reject-result-dimensions",fn()=>
    rejects(fn()=>M.check 1.0E~9 1.0E~10 (matrix[[1.0,2.0]])(matrix[[1.0]])))
  val _=T.check("numerical-matrix/absolute-boundary",fn()=>
    BenchInput.closeReal(1.0E~9,0.0,1.0E~9,1.0E~10)andalso
    not(BenchInput.closeReal(2.0E~9,0.0,1.0E~9,1.0E~10)))
end

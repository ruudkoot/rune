structure BenchQRCheck =
struct
  structure Q=BenchHouseholderQR
  fun factors a q r=
    let val(rows,columns)=Q.size a
        val _=if Q.size q=(rows,rows)andalso Q.size r=(rows,columns)
          then()else raise Fail "QR factor dimensions differ"
        val _=Q.for 0 (rows-1)(fn i=>Q.for 0 (rows-1)(fn j=>
          if Real.isFinite(Q.sub q i j)then()else raise Fail "nonfinite Q"))
        val _=Q.for 0 (rows-1)(fn i=>Q.for 0 (columns-1)(fn j=>
          if Real.isFinite(Q.sub r i j)andalso(i<=j orelse Real.==(Q.sub r i j,0.0))
          then()else raise Fail "QR triangular factor differs"))
        val _=Q.for 0 (rows-1)(fn i=>Q.for i (rows-1)(fn j=>
          if BenchInput.closeReal(Q.dot(Q.row q i)(Q.row q j),
            if i=j then 1.0 else 0.0,1.0E~9,0.0)
          then()else raise Fail "Q is not orthogonal"))
    in()end
  fun run a=
    let val(q,r)=Q.qr a val _=factors a q r
        val result=Q.gemm q r
        val _=BenchMatrixFiles.check 1.0E~9 1.0E~10 a result
    in()end
end

(* Sandmark Householder QR: keep matrix aliases, slices and scalar operation order. *)
structure BenchHouseholderQR =
struct
  type matrix=RealArray.array array
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun initMatrix m n f=Array.tabulate(m,fn i=>RealArray.tabulate(n,fn j=>f i j))
  fun size(a:matrix)=
    let val m=Array.length a in(m,if m=0 then 0 else RealArray.length(Array.sub(a,0)))end
  fun row(a:matrix)i=Array.sub(a,i)
  fun sub a i j=RealArray.sub(row a i,j)
  fun rowSlice x start count=RealArray.tabulate(count,fn i=>RealArray.sub(x,start+i))
  fun matrixSlice a start count=Array.tabulate(count,fn i=>Array.sub(a,start+i))
  fun dot x y=
    let val acc=ref 0.0
        val _=for 0 (RealArray.length x-1)(fn i=>
          acc:= !acc+RealArray.sub(x,i)*RealArray.sub(y,i))
    in !acc end
  fun axpy alpha x y=for 0 (RealArray.length x-1)(fn i=>
    RealArray.update(y,i,alpha*RealArray.sub(x,i)+RealArray.sub(y,i)))
  fun gemvT a x=
    let val(_,n)=size a val y=RealArray.array(n,0.0)
        val _=for 0 (Array.length a-1)(fn i=>axpy(RealArray.sub(x,i))(row a i)y)
    in y end
  fun gemm x y=
    let val(_,k)=size x val(k',_)=size y
        val _=if k=k' then()else raise Fail "QR matrix dimensions differ"
    in Array.tabulate(Array.length x,fn i=>gemvT y(row x i))end
  fun transpose a=let val(m,n)=size a in initMatrix n m(fn i=>fn j=>sub a j i)end
  fun householder x y=
    let val z=RealArray.tabulate(RealArray.length x,fn i=>RealArray.sub(x,i)-RealArray.sub(y,i))
        val c=2.0/dot z z
    in initMatrix(RealArray.length z)(RealArray.length z)(fn i=>fn j=>
      (if i=j then 1.0 else 0.0)-c*RealArray.sub(z,i)*RealArray.sub(z,j))end
  fun gemmHouseholder k x h=
    let val count=Array.length h
    in for 0 (Array.length x-1)(fn i=>
      let val xi=row x i val saved=rowSlice xi k count
      in for 0 (count-1)(fn j=>RealArray.update(xi,j+k,dot saved(row h j)))end)end
  fun qr a=
    let val w=transpose a val(m,n)=size w
        val q=Array.array(n,RealArray.fromList[])
        val _=for 0 (Int.min(m,n)-1)(fn k=>
          let val x=rowSlice(row w k)k(n-k)
              val y=RealArray.array(RealArray.length x,0.0)
              val _=RealArray.update(y,0,Real.copySign(Math.sqrt(dot x x),~(RealArray.sub(x,0))))
              val h=householder x y
              val _=if k=0 then for 0 (n-1)(fn i=>Array.update(q,i,row h i))
                    else gemmHouseholder k q h
              val _=RealArray.update(row w k,k,RealArray.sub(y,0))
          in gemmHouseholder k (matrixSlice w (k+1)(m-k-1))h end)
        val r=initMatrix n m(fn i=>fn j=>if i<=j then sub w j i else 0.0)
    in(q,r)end
end

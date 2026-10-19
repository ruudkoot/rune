(* Sandmark Crout LUP, including raw-column pivot selection and dense permutation. *)
structure BenchCrout =
struct
  type matrix=RealArray.array array
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun initMatrix m n f=Array.tabulate(m,fn i=>RealArray.tabulate(n,fn j=>f i j))
  fun size(a:matrix)=let val m=Array.length a
    in(m,if m=0 then 0 else RealArray.length(Array.sub(a,0)))end
  fun sub(a:matrix)i j=RealArray.sub(Array.sub(a,i),j)
  fun update(a:matrix)i j value=RealArray.update(Array.sub(a,i),j,value)
  fun swap array i j=let val temp=Array.sub(array,i)
    in Array.update(array,i,Array.sub(array,j));Array.update(array,j,temp)end
  fun foldi f initial first last=
    let val acc=ref initial val _=for first last(fn k=>acc:=f(!acc)k)
    in !acc end
  fun sumi f first last=foldi(fn acc=>fn k=>acc+f k)0.0 first last
  fun maxi f first last= #1(foldi(fn(k0,v0)=>fn k=>
    let val v=f k in if v0<v then(k,v)else(k0,v0)end)(~1,~Real.maxFinite)first last)
  fun lup a0=
    let val a=Array.tabulate(Array.length a0,fn i=>Array.sub(a0,i))
        val(m,n)=size a val r=Int.min(m,n)
        val p=Array.tabulate(m,fn i=>i)
        val lu=initMatrix m n(fn _=>fn _=>0.0)
        fun aux i j q=sub a i j-sumi(fn k=>sub lu i k*sub lu k j)0 q
        fun pivot j=maxi(fn i=>Real.abs(sub a i j))j(m-1)
        val _=for 0 (r-1)(fn j=>
          let val selected=pivot j
              val _=if j=selected then()else(swap p j selected;swap a j selected;swap lu j selected)
              val _=for 0 j(fn i=>update lu i j(aux i j(i-1)))
          in if Real.abs(sub lu j j)>1.0E~6 then
            for(j+1)(m-1)(fn i=>update lu i j(aux i j(j-1)/sub lu j j))else()end)
        val _=for r (n-1)(fn j=>for 0 (r-1)(fn i=>update lu i j(aux i j(i-1))))
    in(p,lu)end
  fun gemm x y=
    let val(m,k)=size x val(k',n)=size y
        val _=if k=k' then()else raise Fail "Crout matrix dimensions differ"
    in initMatrix m n(fn i=>fn j=>sumi(fn l=>sub x i l*sub y l j)0(k-1))end
  fun main a=
    let val(p,lu)=lup a val(m,n)=size lu val r=Int.min(m,n)
        val l=initMatrix m r(fn i=>fn j=>if i>j then sub lu i j else if i=j then 1.0 else 0.0)
        val u=initMatrix r n(fn i=>fn j=>if i<=j then sub lu i j else 0.0)
        val permutation=initMatrix m m(fn i=>fn j=>if i=Array.sub(p,j)then 1.0 else 0.0)
    in gemm permutation(gemm l u)end
end

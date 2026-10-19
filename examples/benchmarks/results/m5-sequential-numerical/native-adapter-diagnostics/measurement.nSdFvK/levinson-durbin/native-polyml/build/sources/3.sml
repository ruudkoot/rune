(* Sandmark Levinson-Durbin: keep sequential sums and fresh coefficient arrays. *)
structure BenchLevinson =
struct
  fun for first last f = if first>last then () else
    (f first;for(first+1)last f)
  fun mapiSum f x =
    let val acc=ref 0.0
        val _=for 0 (RealArray.length x-1)(fn i=>acc:= !acc+f i(RealArray.sub(x,i)))
    in !acc end
  fun autocorr x tau =
    let val n=RealArray.length x
        val r=RealArray.array(tau+1,0.0)
        val _=for 0 tau(fn i=>for 0 (n-i-1)(fn t=>
          RealArray.update(r,i,RealArray.sub(r,i)+RealArray.sub(x,t)*RealArray.sub(x,t+i))))
    in r end
  fun levinson r =
    let val n=RealArray.length r
        val _=if n=0 then raise Fail "empty autocorrelation" else ()
        fun aux m ar sigma2 =
          if m+1=n then (ar,sigma2)
          else let val next=RealArray.array(m+1,0.0)
              val coefficient=(RealArray.sub(r,m+1)-
                mapiSum(fn i=>fn ai=>ai*RealArray.sub(r,m-i))ar)/sigma2
              val _=RealArray.update(next,m,coefficient)
              val _=for 0 (m-1)(fn i=>RealArray.update(next,i,
                RealArray.sub(ar,i)-RealArray.sub(next,m)*RealArray.sub(ar,m-1-i)))
              val variance=sigma2*(1.0-RealArray.sub(next,m)*RealArray.sub(next,m))
            in aux(m+1)next variance end
    in aux 0 (RealArray.fromList[]) (RealArray.sub(r,0)) end
  fun coefficients data order = levinson(autocorr data(order+1))
end

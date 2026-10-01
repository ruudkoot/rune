structure Benchmark =
struct
  val name="msort"
       fun cp [] =[]
         | cp (x::xs)= x :: cp xs

       (* exormorphic merge *)
       fun merge(xs, []):int list = cp xs
         | merge([], ys) = cp ys
         | merge(l1 as x::xs, l2 as y::ys) =
               if x<y then x :: merge(xs, l2)
               else y :: merge(l1, ys)

       (* splitting a list *)
       fun split(x::y::zs, l, r) = split(zs, x::l, y::r)
         | split([x], l, r) = (x::l, r)
         | split([], l, r) = (l, r)

       (* exomorphic merge sort *)
       fun msort []  = []
         | msort [x] = [x]
         | msort xs = let val (l, r) = split(xs, [], [])
                      in merge(msort l, msort r)
                      end;

fun upto n =
  let fun loop(p as (0,acc)) = p
        | loop(n, acc) =
            loop(n-1, n::acc)
  in
      #2(loop(n,[]))
  end


  fun summarize values =
    let fun loop([],i,sum,hash)=Int.toString(i-1)^" "^IntInf.toString sum^" "^Word32.toString hash
          | loop(x::xs,i,sum,hash)=if x=i then loop(xs,i+1,IntInf.+(sum,IntInf.fromInt x),
              Word32.+(Word32.*(hash,0w16777619),Word32.fromInt x)) else raise Fail "sorted sequence"
    in loop(values,1,0,0w0) end
  fun run [size] = summarize(msort(upto(BenchInput.between(1,100000)(BenchInput.integer size))))
  | run _=raise Fail "msort expects sequence length"
end

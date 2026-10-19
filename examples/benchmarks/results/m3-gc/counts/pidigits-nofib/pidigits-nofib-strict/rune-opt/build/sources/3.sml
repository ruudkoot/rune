structure Benchmark =
struct
  val name="pidigits-nofib-strict"
  fun digits limit=
    let fun loop(left,j,state,acc)=
          let val k=j+1 val t as(n,a,d)=BenchNofibPi.next(k,#1 state,#2 state,#3 state)
          in if n>a then loop(left,k,t,acc)else
            let val(q,r)=BenchNofibPi.candidate t
            in if IntInf.+(r,n)>=d then loop(left,k,t,acc)else
              let val digit=Char.chr(Char.ord #"0"+IntInf.toInt q)
              in if left=1 then List.rev(digit::acc)else
                loop(left-1,k,(IntInf.*(n,10),IntInf.*(IntInf.-(a,IntInf.*(q,d)),10),d),digit::acc)end end end
    in loop(limit,0,(1,0,1),[])end
  fun run args=BenchNofibPi.run digits args
end

structure Benchmark =
struct
  val name="lcss-strict"
  fun algb xs ys =
    let fun rows([],row)=List.map #2 row
          |rows(x::xs,row)=
            let fun update(_,_,[])=[]
                  |update(diagonal,current,(y,above)::rest)=
                    let val value=if x=y then diagonal+1 else Int.max(current,above)
                    in(y,value)::update(above,value,rest)end
            in rows(xs,update(0,0,row))end
    in 0::rows(xs,List.map(fn y=>(y,0))ys)end
  fun algc _ _ _ [] tail=tail
    |algc _ _ [x] ys tail=if List.exists(fn y=>x=y)ys then x::tail else tail
    |algc m n xs ys tail=
      let val middle=m div 2 val left=List.take(xs,middle)val right=List.drop(xs,middle)
          val first=algb left ys val second=List.rev(algb(List.rev right)(List.rev ys))
          val k=BenchLCSS.findSplit(ListPair.zip(first,second))
      in algc middle k left(List.take(ys,k))(algc(m-middle)(n-k)right(List.drop(ys,k))tail)end
  fun calculate xs ys=algc(List.length xs)(List.length ys)xs ys[]
  fun run args=BenchLCSS.run calculate args
end

structure Benchmark =
struct
  val name="lcss-lazy"
  type cell=int BenchLazy.delay
  fun fromCells []=BenchStream.empty()
    |fromCells(x::xs)=BenchStream.cons(x,fromCells xs)
  fun reverseCells xs=
    let fun collect(xs,acc)=case BenchLazy.force xs of BenchStream.Nil=>fromCells acc
          |BenchStream.Cons(x,rest)=>collect(rest,x::acc)
    in collect(xs,[])end
  fun algb xs ys =
    let fun rows([],row)=BenchStream.map(fn(_,value)=>BenchLazy.force value)row
          |rows(x::xs,row)=
            let fun update(diagonal:cell,current:cell,row)=BenchLazy.delay(fn()=>case BenchLazy.force row of
                  BenchStream.Nil=>BenchStream.Nil
                |BenchStream.Cons(pair,rest)=>
                  let val(y,above)=BenchLazy.force pair
                      val value=BenchLazy.delay(fn()=>if x=y then BenchLazy.force diagonal+1
                        else Int.max(BenchLazy.force current,BenchLazy.force above))
                  in BenchStream.Cons(BenchLazy.delay(fn()=>(y,value)),update(above,value,rest))end)
            in rows(xs,update(BenchLazy.delay(fn()=>0),BenchLazy.delay(fn()=>0),row))end
        val start=BenchStream.fromList(List.map(fn y=>(y,BenchLazy.delay(fn()=>0)))ys)
    in BenchStream.cons(BenchLazy.delay(fn()=>0),BenchLazy.delay(fn()=>BenchLazy.force(rows(xs,start))))end
  fun algc m n xs ys tail=BenchLazy.delay(fn()=>case(xs,ys)of
      (_,[])=>BenchLazy.force tail
    |([x],_)=>if List.exists(fn y=>x=y)ys then BenchStream.Cons(BenchLazy.delay(fn()=>x),tail)else BenchLazy.force tail
    |_=>let val middle=m div 2 val left=List.take(xs,middle)val right=List.drop(xs,middle)
            val first=algb left ys val second=reverseCells(algb(List.rev right)(List.rev ys))
            fun choose((x,y),(index,best,largest))=let val sum=x+y
              in if sum>=largest then(index+1,index,sum)else(index+1,best,largest)end
            val(_,k,_)=BenchStream.foldl choose(0,0,~1)
              (BenchStream.zipWith(fn pair=>pair)first second)
        in BenchLazy.force(algc middle k left(List.take(ys,k))
          (algc(m-middle)(n-k)right(List.drop(ys,k))tail))end)
  fun calculate xs ys=List.rev(BenchStream.foldl(fn(value,acc)=>value::acc)[]
    (algc(List.length xs)(List.length ys)xs ys(BenchStream.empty())))
  fun run args=BenchLCSS.run calculate args
end

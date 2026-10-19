structure BenchScsPrepare =
struct
  structure Q=BenchScsRational
  structure L=BenchLazy
  structure T=BenchScsTypes
  structure M=BenchScsMatrixFn(Q)
  val plus=L.delay(fn()=>Q.one)
  val minus=L.delay(fn()=>Q.negative Q.one)
  fun negate value=L.delay(fn()=>Q.negative(L.force value))
  fun build circuit dt=
    let val size=List.foldl(fn((i,p,m,_),old)=>Int.max(old,Int.max(i,Int.max(p,m))))0 circuit
        val _=if List.null circuit then raise Fail "empty circuit"else()
        fun element(i,p,m,value)=
          let val common=[((p,i),minus),((m,i),plus)]
          in common @ (case value of
              T.Conductor g=>[((i,m),negate g),((i,p),g),((i,i),minus)]
            | T.Resistor r=>[((i,m),minus),((i,p),plus),((i,i),negate r)]
            | T.Capacitor(c,_)=>[((i,m),negate c),((i,p),c)]
            | T.Inductor(l,_)=>[((i,i),l)]
            | T.Vsource _=>[((i,m),minus),((i,p),plus)]
            | T.Isource _=>[((i,i),plus)]
            | T.Junction(c,_,_)=>[((i,m),negate c),((i,p),c)])
          end
        fun derivative(i,p,m,value)=case value of
            T.Capacitor _=>[((i,i),plus)]
          | T.Inductor _=>[((i,p),plus),((i,m),minus)]
          | T.Junction _=>[((i,i),plus)]|_=>[]
        fun initial(i,_,_,value)=case value of T.Capacitor(_,q)=>[(i,q)]
          | T.Inductor(_,flux)=>[(i,flux)]|T.Junction(_,_,q)=>[(i,q)]|_=>[]
        fun matrix f=M.accumMatrix(size,size)(fn add=>
          List.app(fn component=>List.app(fn (entry as ((r,c),_))=>
            if r=0 orelse c=0 then()else add entry)(f component))circuit)
        val elements=matrix element
        val derivatives=matrix derivative
        val initial=M.accumVector size(fn add=>List.app(fn component=>List.app add(initial component))circuit)
        val first=L.delay(fn()=>M.gaussJordan elements)
        val second=L.delay(fn()=>M.gaussJordan(M.transpose elements))
        val constraint=L.delay(fn()=>let val(free,_,inverse)=L.force first in M.select free inverse end)
        val freedom=L.delay(fn()=>let val(free,_,inverse)=L.force second in M.transpose(M.select free inverse)end)
        val third=L.delay(fn()=>M.gaussJordan(M.multiply(L.force constraint)(M.multiply derivatives(L.force freedom))))
        fun inverseThird()=let val(free,_,inverse)=L.force third
          in if List.null free then inverse else raise Fail "illegal circuit"end
        val correction=L.delay(fn()=>if List.null(#1(L.force first))then M.zero size else
          M.multiply(L.force freedom)(M.multiply(inverseThird())(L.force constraint)))
        val correctState=L.delay(fn()=>M.subtract(M.unit size)(M.multiply derivatives(L.force correction)))
        val correctOutput=L.delay(fn()=>M.subtract(M.unit size)(M.multiply(L.force correction)derivatives))
        val solve=L.delay(fn()=>M.multiply(L.force correctOutput)(M.multiply(#3(L.force first))(L.force correctState)))
        val scaled=L.delay(fn()=>M.map(fn value=>Q.mul(value,Q.divide(dt,Q.fromInt 2)))
          (M.multiply derivatives(L.force solve)))
        val fourth=L.delay(fn()=>M.gaussJordan(M.subtract(M.unit size)(L.force scaled)))
        val integrate=L.delay(fn()=>let val(free,_,inverse)=L.force fourth
          in if List.null free then M.multiply inverse(M.add(M.unit size)(L.force scaled))
             else raise Fail "unlucky choice of dt"end)
        val backdate=L.delay(fn()=>M.map(fn value=>Q.divide(value,dt))(L.force correction))
    in {initial=initial,solve=solve,integrate=integrate,correct=correctState,backdate=backdate}end
end

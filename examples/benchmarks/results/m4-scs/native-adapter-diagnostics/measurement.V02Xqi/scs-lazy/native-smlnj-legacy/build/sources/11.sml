structure BenchScsSimulate =
struct
  structure Q=BenchScsRational
  structure L=BenchLazy
  structure S=BenchStream
  structure T=BenchScsTypes
  structure E=BenchScsPrepare.M
  structure Number =
  struct
    type t=real
    val zero=0.0
    val one=1.0
    fun add(a:real,b)=a+b
    fun sub(a:real,b)=a-b
    fun mul(a:real,b)=a*b
    fun divide(a:real,b)=a/b
    val absolute=Real.abs
    val compare=Real.compare
    fun equal(a,b)=Real.==(a,b)
  end
  structure M=BenchScsMatrixFn(Number)
  type frame={time:Q.t L.delay,state:M.vector L.delay,output:M.vector L.delay,random:real S.stream}
  fun drop 0 source=source
    | drop n source=L.delay(fn()=>case L.force source of S.Nil=>S.Nil|S.Cons(_,rest)=>L.force(drop(n-1)rest))
  fun source wave timeCell=
    case L.force wave of S.Nil=>raise Fail "empty waveform"
    | S.Cons(pair,rest)=>
      let val(t0,v0)=L.force pair
      in case L.force rest of S.Nil=>L.force v0
       |S.Cons(next,after)=>
         if L.force timeCell<L.force t0 then L.force v0 else
         let val(t1,v1)=L.force next
             val first=L.force t0 val last=L.force t1 val time=L.force timeCell
         in if first>=last then raise Fail "sources must have increasing times"
            else if time<last then L.force v0+(L.force v1-L.force v0)*(time-first)/(last-first)
            else source(S.cons(next,after))timeCell
         end
      end
  fun simulateWith strict circuit seed dt endTime temperature rbc=L.delay(fn()=>
    let val prepared=BenchScsPrepare.build circuit dt
        fun numericVector value=(if strict then M.forceVector value else();value)
        fun numericMatrix value=(if strict then M.forceMatrix value else();value)
        fun matrix original=numericMatrix(M.matrix(E.rows original,E.columns original)(fn index=>Q.real(E.at original index)))
        val initial=L.delay(fn()=>let val value= #initial prepared
          in numericVector(M.vector(E.size value)(fn i=>Q.real(E.sub value i)))end)
        val solveMatrix=L.delay(fn()=>matrix(L.force(#solve prepared)))
        val integrateMatrix=L.delay(fn()=>matrix(L.force(#integrate prepared)))
        val correctMatrix=L.delay(fn()=>matrix(L.force(#correct prepared)))
        val backdateMatrix=L.delay(fn()=>matrix(L.force(#backdate prepared)))
        val e=1.6021773E~19
        val k=1.38066E~23
        val e2=e*e
        val kT=k*temperature
        val dtReal=Q.real dt
        fun solve(f:frame):frame={time= #time f,state= #state f,random= #random f,
          output=L.delay(fn()=>numericVector(M.apply(L.force solveMatrix)(L.force(#state f))))}
        fun integrate(f:frame):frame={time=L.delay(fn()=>Q.add(L.force(#time f),dt)),
          state=L.delay(fn()=>numericVector(M.apply(L.force integrateMatrix)(L.force(#state f)))),
          output= #output f,random= #random f}
        fun correct(f:frame):frame={time= #time f,random= #random f,
          state=L.delay(fn()=>numericVector(M.apply(L.force correctMatrix)(L.force(#state f)))),
          output=L.delay(fn()=>numericVector(M.subtractVector(L.force(#output f))
            (M.apply(L.force backdateMatrix)(L.force(#state f)))))}
        fun sources(f:frame):frame=
          let val state=L.delay(fn()=>
                let val old=L.force(#state f) val n=M.size old
                    val time=L.delay(fn()=>Q.real(L.force(#time f)))
                    val offsets=numericVector(M.Vec(Vector.fromList(List.map(fn value=>L.delay(fn()=>
                      (((L.force value+(~0.5))*2.0)*rbc)*e/dtReal))
                      (let fun cells 0 _=[]|cells left xs=case L.force xs of S.Nil=>raise Fail "short random stream"
                        |S.Cons(x,rest)=>x::cells(left-1)rest in cells n(#random f)end))))
                    fun element(i,_,_,value)=
                      (i,case value of T.Capacitor _=>L.delay(fn()=>M.sub old i)
                        |T.Inductor _=>L.delay(fn()=>M.sub old i)
                        |T.Junction _=>L.delay(fn()=>M.sub old i)
                        |T.Vsource values=>L.delay(fn()=>source values time)
                        |T.Isource values=>L.delay(fn()=>source values time)
                        |_=>L.delay(fn()=>0.0))
                in numericVector(M.updateVector offsets(List.map element circuit))end)
              val after=L.delay(fn()=>L.force(drop(M.size(L.force(#state f)))(#random f)))
          in {time= #time f,state=state,output= #output f,random=after}end
        fun sum values=List.foldl(fn(value,total)=>total+value)0.0 values
        fun energyState state=sum(List.map(fn(i,_,_,value)=>
          case value of T.Capacitor(c,_)=>energy state i c
            |T.Junction(c,_,_)=>energy state i c|_=>0.0)circuit)
        and energy state i capacitance=
          if Q.equal(L.force capacitance,Q.zero)then raise Fail "capacitance must be nonzero"
          else let val value=M.sub state i in (0.5*(value*value))/Q.real(L.force capacitance)end
        fun energySource state output=sum(List.map(fn(i,_,_,value)=>
          case value of T.Vsource _=>(M.sub state i*M.sub output i)*dtReal|_=>0.0)circuit)
        fun tunnel(f:frame)=
          let val draw=L.delay(fn()=>case L.force(#random f)of S.Nil=>raise Fail "short random stream"
                    |S.Cons(value,rest)=>(value,rest))
              val after=L.delay(fn()=>let val(_,rest)=L.force draw in L.force rest end)
              val probabilityDraw=L.delay(fn()=>let val(value,_)=L.force draw in L.force value end)
              val oldEnergy=L.delay(fn()=>energyState(L.force(#state f)))
              fun events(i,_,_,value)=case value of T.Junction(_,resistance,_)=>
                    let fun change operation=(resistance,L.delay(fn()=>
                          let val state=L.force(#state f)
                          in numericVector(M.updateVector state[(i,L.delay(fn()=>operation(M.sub state i,e)))])end))
                    in [change(fn(a,b)=>a+b),change(fn(a,b)=>a-b)]end
                  |_=>[]
              val events=List.concat(List.map events circuit)
              fun probability(resistance,state)=
                let val resistance=L.force resistance
                    val corrected=correct{time=L.delay(fn()=>resistance),state=state,
                      output=L.delay(fn()=>numericVector(M.vector(M.size(L.force(#output f)))(fn _=>0.0))),random=S.empty()}
                    val energy=(energyState(L.force(#state corrected))-L.force oldEnergy)+
                      energySource(L.force(#state corrected))(L.force(#output corrected))
                    val value=if Q.equal(resistance,Q.zero)then raise Fail "tunnel resistance must be nonzero"
                      else if Real.==(temperature,0.0)then dtReal*(~energy)/(e2*Q.real resistance)
                      else if Real.==(energy,0.0)then dtReal*kT/(e2*Q.real resistance)
                      else dtReal*(~energy)/((e2*Q.real resistance)*(1.0-Math.exp(energy/kT)))
                in if value<0.0 then 0.0 else value end
              val probabilities=List.map probability events
              val total=sum probabilities
              val probabilities=if total>1.0 then
                    if strict then S.fromList(List.map(fn value=>value/total)probabilities)
                    else S.map(fn value=>value/total)(S.fromList probabilities)
                  else S.fromList probabilities
              val base:frame={time= #time f,state= #state f,output= #output f,random=after}
              fun choose cumulative probabilities states=case(L.force probabilities,states)of
                  (S.Nil,[])=>[base]
                | (S.Cons(p,ps),(_,state)::states)=>
                    let val next=cumulative+L.force p
                    in if L.force probabilityDraw<next then
                         [base,correct(solve{time= #time f,state=state,output= #output f,random=after})]
                       else choose next ps states end
                | _=>raise Fail "event/probability length mismatch"
          in choose 0.0 probabilities events end
        fun advance frame=correct(solve(sources(integrate frame)))
        fun trace frame=L.delay(fn()=>
          let val frames=tunnel frame
              val last=List.last frames
              fun emit []=L.delay(fn()=>L.force(trace(advance last)))
                | emit((frame:frame)::rest)=L.delay(fn()=>S.Cons
                    (L.delay(fn()=>(L.force(#time frame),#output frame)),emit rest))
          in L.force(emit frames)end)
        fun select frames=L.delay(fn()=>case L.force frames of S.Nil=>S.Nil
          |S.Cons(row,rest)=>let val(time,_)=L.force row
             in if Q.compare(time,endTime)<>GREATER then S.Cons(row,select rest)else S.Nil end)
        val randoms=S.map(fn value=>Real.fromLargeInt value/1073741824.0)
          (BenchScsRandom.random(0,1073741823)seed)
        val first=correct(solve(sources{time=L.delay(fn()=>Q.zero),state=initial,output=initial,random=randoms}))
    in L.force(select(trace first))end)
  fun simulate circuit seed dt endTime temperature rbc=simulateWith false circuit seed dt endTime temperature rbc
end

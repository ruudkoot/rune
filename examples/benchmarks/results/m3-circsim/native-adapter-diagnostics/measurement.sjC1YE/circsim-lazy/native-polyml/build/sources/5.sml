functor BenchCircsimFn (D : BENCH_SUSPEND) =
struct
  datatype boolean=F|T
  datatype component=CNone|Inp|Outp|Dff|Inv|And2|Or2|Xor
  datatype 'a node=Nil|Cons of 'a D.t * 'a node D.t
  type 'a seq='a node D.t
  type signal=boolean D.t
  type label=string D.t * int
  type inport=int * int * signal
  type outport=int * signal * bool * int * bool * int
  datatype state=PS of {pid:int,kind:component,depth:int,ins:inport seq,outs:outport seq}
  type circuit={size:int,inputs:label seq,outputs:label seq,states:state seq}
  type packet=int * int * signal * bool * int * bool * int * int
  type packetPair=packet D.t * packet D.t
  datatype ('a,'b) treeNode=Cell of 'a D.t
    |Node of 'b D.t * ('a,'b) treeNode D.t * ('a,'b) treeNode D.t
  fun empty()=D.delay(fn()=>Nil)
  fun cons(x,xs)=D.delay(fn()=>Cons(x,xs))
  fun cells []=empty()|cells(x::xs)=D.delay(fn()=>Cons(x,cells xs))
  fun map f xs=D.delay(fn()=>case D.force xs of Nil=>Nil|Cons(x,xs)=>Cons(f x,map f xs))
  fun zipWith f xs ys=D.delay(fn()=>case D.force xs of Nil=>Nil
    |Cons(x,xs)=>(case D.force ys of Nil=>Nil|Cons(y,ys)=>Cons(f(x,y),zipWith f xs ys)))
  fun append xs ys=D.delay(fn()=>case D.force xs of Nil=>D.force ys
    |Cons(x,xs)=>Cons(x,append xs ys))
  fun head xs=(case D.force xs of Nil=>raise Empty|Cons(x,_)=>x)
  fun tail xs=(case D.force xs of Nil=>raise Empty|Cons(_,xs)=>xs)
  fun lengthFrom(n,xs)=(case D.force xs of Nil=>n|Cons(_,xs)=>lengthFrom(n+1,xs))
  fun length xs=lengthFrom(0,xs)
  fun take 0 xs=empty()|take n xs=D.delay(fn()=>case D.force xs of Nil=>Nil
    |Cons(x,xs)=>Cons(x,take(n-1)xs))
  fun drop 0 xs=xs|drop n xs=D.delay(fn()=>case D.force xs of Nil=>Nil
    |Cons(_,xs)=>D.force(drop(n-1)xs))
  fun replicate 0 x=empty()|replicate n x=D.delay(fn()=>Cons(x,replicate(n-1)x))
  fun foldr f base xs=D.delay(fn()=>case D.force xs of Nil=>D.force base
    |Cons(x,xs)=>D.force(f(x,foldr f base xs)))
  fun any p xs=(case D.force xs of Nil=>false|Cons(x,xs)=>p x orelse any p xs)
  fun maximum f xs=
    let fun loop(value,xs)=case D.force xs of Nil=>value
          |Cons(x,xs)=>loop(Int.max(value,f x),xs)
    in case D.force xs of Nil=>raise Empty|Cons(x,xs)=>loop(f x,xs)end
  fun first pair=D.delay(fn()=>let val(x,_)=D.force pair in D.force x end)
  fun second pair=D.delay(fn()=>let val(_,y)=D.force pair in D.force y end)
  fun transpose rows=D.delay(fn()=>case D.force rows of Nil=>Nil
    |Cons(row,rest)=>(case D.force row of Nil=>D.force(transpose rest)
      |Cons(x,xs)=>
        let fun heads rows=D.delay(fn()=>case D.force rows of Nil=>Nil
              |Cons(row,rest)=>(case D.force row of Nil=>D.force(heads rest)
                 |Cons(x,_)=>Cons(x,heads rest)))
            fun tails rows=D.delay(fn()=>case D.force rows of Nil=>Nil
              |Cons(row,rest)=>(case D.force row of Nil=>D.force(tails rest)
                 |Cons(_,xs)=>Cons(xs,tails rest)))
        in Cons(cons(x,heads rest),transpose(cons(xs,tails rest)))end))
  fun put xs=D.delay(fn()=>case D.force xs of Nil=>raise Empty
    |Cons(x,rest)=>(case D.force rest of Nil=>Cell x
      |_=>let val half=length xs div 2
          in Node(D.delay(fn()=>()),put(take half xs),put(drop half xs))end))
  fun get tree=D.delay(fn()=>case D.force tree of Cell x=>Cons(x,empty())
    |Node(_,left,right)=>D.force(append(get left)(get right)))
  fun upsweep f tree=D.delay(fn()=>case D.force tree of
      Cell x=>(x,D.delay(fn()=>Cell x))
    |Node(_,left,right)=>
       let val l=upsweep f left val r=upsweep f right
       in (f(first l,first r),D.delay(fn()=>Node(D.delay(fn()=>(first l,first r)),second l,second r)))end)
  fun downsweep g seed tree=D.delay(fn()=>case D.force tree of Cell _=>Cell seed
    |Node(annotation,left,right)=>
       let val(l,r)=D.force annotation val split=g(l,r,seed)
       in Node(D.delay(fn()=>()),downsweep g(first split)left,downsweep g(second split)right)end)
  fun sweep up down seed tree=D.delay(fn()=>
    let val result=upsweep up tree
    in (first result,downsweep down seed(second result))end)
  val zero=D.delay(fn()=>F)
  val one=D.delay(fn()=>T)
  val emptyPacket:packet D.t=D.delay(fn()=>(~1,~1,zero,false,0,false,0,1))
  fun sendRight(a:packet D.t,b:packet D.t)=D.delay(fn()=>
    let val(ia,sa,ma,qla,dla,qra,dra,ea)=D.force a
        val(ib,sb,mb,qlb,dlb,qrb,drb,eb)=D.force b
    in if qra andalso dra>eb then(ia,sa,ma,qla,dla,qra,dra-eb,ea+eb)
       else(ib,sb,mb,qlb,dlb,qrb,drb,ea+eb)end)
  fun sendLeft(a:packet D.t,b:packet D.t)=D.delay(fn()=>
    let val(ia,sa,ma,qla,dla,qra,dra,ea)=D.force a
        val(ib,sb,mb,qlb,dlb,qrb,drb,eb)=D.force b
    in if qlb andalso dlb>ea then(ib,sb,mb,qlb,dlb-ea,qrb,drb,ea+eb)
       else(ia,sa,ma,qla,dla,qra,dra,ea+eb)end)
  fun send packets=
    let val paired=map(fn x=>D.delay(fn()=>(x,x)))packets
        fun up(l,r)=D.delay(fn()=>
          let val(lx,ly)=D.force l val(rx,ry)=D.force r
          in(sendRight(lx,rx),sendLeft(ly,ry))end)
        fun down(l,r,seed)=D.delay(fn()=>
          let val(lx,ly)=D.force l val(rx,ry)=D.force r val(a,b)=D.force seed
          in(D.delay(fn()=>(a,sendLeft(ry,b))),D.delay(fn()=>(sendRight(a,lx),b)))end)
        val result=sweep up down(D.delay(fn()=>(emptyPacket,emptyPacket)))(put paired)
        val answer=D.delay(fn()=>
          let val(l,r)=D.force(first result)
          in(sendLeft(r,emptyPacket),sendRight(emptyPacket,l))end)
    in D.delay(fn()=>(answer,get(second result)))end
  fun info value=(case D.force value of PS fields=>fields)
  fun setIns value ins=D.delay(fn()=>
    let val{pid,kind,depth,outs,...}=info value
    in PS{pid=pid,kind=kind,depth=depth,ins=ins,outs=outs}end)
  fun setOuts value outs=D.delay(fn()=>
    let val{pid,kind,depth,ins,...}=info value
    in PS{pid=pid,kind=kind,depth=depth,ins=ins,outs=outs}end)
  fun updateRequests b value=
    let val outs=map(fn port=>D.delay(fn()=>
          let val(p,m,ql,dl,qr,dr)=D.force port in(p,m,b,dl,b,dr)end))(#outs(info value))
    in setOuts value outs end
  fun checkDepth depth value=D.delay(fn()=>
    if #depth(info value)=depth then D.force value else D.force(updateRequests false value))
  fun makePackets value=
    let val pid= #pid(info value)
    in map(fn port=>D.delay(fn()=>let val(p,m,ql,dl,qr,dr)=D.force port
         in(pid,p,m,ql,dl,qr,dr,1)end))(#outs(info value))end
  fun padPackets packets=
    let val size=maximum length packets
    in map(fn row=>take size(append row(replicate size emptyPacket)))packets end
  fun upIn packet ins=D.delay(fn()=>
    let val(i,p,m,_,_,_,_,_)=D.force(packet:packet D.t)
    in D.force(map(fn port=>D.delay(fn()=>
         let val(pid,number,old)=D.force port
         in(pid,number,if(i,p)=(pid,number)then m else old)end))ins)end)
  fun updateIn(pair,ins)=
    let val(l,r)=D.force pair in upIn l(upIn r ins)end
  fun updateOut(pair,port)=D.delay(fn()=>
    let val(l,r)=D.force pair
        val(_,_,_,_,_,lqr,ldr,_)=D.force l
        val(_,_,_,rql,rdl,_,_,_)=D.force r
        val(p,m,ql,dl,qr,dr)=D.force port
    in(p,m,if rql andalso rdl>0 then ql else false,dl,
        if lqr andalso ldr>0 then qr else false,dr)end)
  fun updateIO depth(pairList,value)=D.delay(fn()=>
    let val{pid,kind,depth=oldDepth,ins,outs}=info value
        val newIns=foldr updateIn ins pairList
        val newOuts=if oldDepth=depth then zipWith updateOut pairList outs else outs
    in PS{pid=pid,kind=kind,depth=oldDepth,ins=newIns,outs=newOuts}end)
  fun acknowledge depth states=
    not(any(fn value=>any(fn port=>let val(_,_,l,_,r,_)=D.force port in l orelse r end)
      (#outs(info value)))(map(checkDepth depth)states))
  fun doSend depth states=
    let val active=map(checkDepth depth)states
        val columns=transpose(padPackets(map(fn value=>D.delay(fn()=>D.force(makePackets value)))active))
        val sent=map(fn column=>D.delay(fn()=>D.force(second(send column))))columns
        val sitePackets=transpose sent
    in zipWith(updateIO depth)sitePackets states end
  fun doSends depth states=D.delay(fn()=>if acknowledge depth states then D.force states
    else D.force(doSends depth(doSend depth states)))
  fun signalNot x=if D.force x=T then F else T
  fun signalAnd(x,y)=if D.force x=T andalso D.force y=T then T else F
  fun signalOr(x,y)=if D.force x=T orelse D.force y=T then T else F
  fun signalXor(x,y)=if D.force x=D.force y then T else F
  fun signals ports=map(fn port=>D.delay(fn()=>let val(_,_,v)=D.force port in D.force v end))ports
  fun apply Inp values=NONE
    |apply kind values=
      let fun unary f=(case D.force values of Cons(x,rest)=>(case D.force rest of
                Nil=>SOME(f x)|_=>raise Fail "apply_component arity")
              |_=>raise Fail "apply_component arity")
          fun binary f=(case D.force values of Cons(x,rest)=>(case D.force rest of
                Cons(y,more)=>(case D.force more of Nil=>SOME(D.delay(fn()=>f(x,y)))
                  |_=>raise Fail "apply_component arity")|_=>raise Fail "apply_component arity")
              |_=>raise Fail "apply_component arity")
      in case kind of Outp=>unary(fn x=>x)|Dff=>unary(fn x=>x)|Inv=>unary(fn x=>D.delay(fn()=>signalNot x))
        |And2=>binary signalAnd|Or2=>binary signalOr|Xor=>binary signalXor
        |_=>raise Fail "Error: apply_component"end
  fun updateOutputs value output=
    setOuts value(map(fn port=>D.delay(fn()=>let val(p,_,ql,dl,qr,dr)=D.force port
      in(p,output,ql,dl,qr,dr)end))(#outs(info value)))
  fun simulateComponent depth value=D.delay(fn()=>
    if #depth(info value)<>depth then D.force value
    else case apply(#kind(info value))(signals(#ins(info value)))of
      NONE=>D.force value|SOME output=>D.force(updateOutputs value output))
  fun restore(old,value)=D.delay(fn()=>
    let val{pid,kind,depth,ins,outs}=info value
        val restored=zipWith(fn(a,b)=>D.delay(fn()=>
          let val(p,_,ql,dl,qr,dr)=D.force a val(_,m,_,_,_,_)=D.force b
          in(p,m,ql,dl,qr,dr)end))(#outs(info old))outs
    in PS{pid=pid,kind=kind,depth=depth,ins=ins,outs=restored}end)
  fun storeInputs labels value=D.delay(fn()=>
    if #kind(info value)<>Inp then D.force value
    else let val pid= #pid(info value)
             fun find xs=case D.force xs of Nil=>raise Empty|Cons(pair,rest)=>
               let val(label,input)=D.force pair val(_,inputPid)=D.force label
               in if inputPid=pid then D.force(updateOutputs value input)else find rest end
         in find labels end)
  fun initDff value=D.delay(fn()=>if #kind(info value)=Dff
    then D.force(updateOutputs value zero)else D.force value)
  fun doCycle cpd old inputs=D.delay(fn()=>
    let val{size,inputs=labels,outputs,states}=D.force(old:circuit D.t)
        val pairs=zipWith(fn(a,b)=>D.delay(fn()=>(a,b)))labels inputs
        val states1=map(storeInputs pairs)states
        val states2=doSends 0 states1
        val states3=D.delay(fn()=>
          let fun loop(depth,result)=if depth>D.force cpd then result
                else loop(depth+1,doSends depth(map(simulateComponent depth)result))
          in D.force(loop(1,states2))end)
    in {size=size,inputs=labels,outputs=outputs,states=zipWith restore states states3}end)
  fun scanl f initial values=D.delay(fn()=>Cons(initial,D.delay(fn()=>
    case D.force values of Nil=>Nil|Cons(x,xs)=>D.force(scanl f(f(initial,x))xs))))
  fun simulate inputs circuit=
    let val initial=D.delay(fn()=>let val{size,inputs,outputs,states}=D.force(circuit:circuit D.t)
          in{size=size,inputs=inputs,outputs=outputs,states=map initDff states}end)
        val depth=D.delay(fn()=>maximum(fn value=> #depth(info value))(#states(D.force circuit)))
    in tail(scanl(fn(c,row)=>doCycle depth c row)initial inputs)end
  fun collectOutputs circuit=
    let val{outputs,states,...}=D.force(circuit:circuit D.t)
    in map(fn label=>D.delay(fn()=>
         let val(_,pid)=D.force label
             fun find xs=case D.force xs of Nil=>raise Empty|Cons(value,rest)=>
               if #pid(info value)=pid then
                 let val(_,_,signal)=D.force(head(#ins(info value)))in D.force signal end
               else find rest
         in find states end))outputs end
  fun circuitSimulate inputs circuit=map(fn c=>D.delay(fn()=>D.force(collectOutputs c)))(simulate inputs circuit)
  fun range(first,last)=D.delay(fn()=>if first>last then Nil
    else Cons(D.delay(fn()=>first),range(first+1,last)))
  fun concat values=D.delay(fn()=>case D.force values of Nil=>Nil
    |Cons(value,rest)=>D.force(append value(concat rest)))
  fun newState pid kind depth ins outs=D.delay(fn()=>PS{pid=pid,kind=kind,depth=depth,
    ins=D.delay(fn()=>D.force(cells(List.map(fn value=>D.delay(fn()=>value))(ins())))),
    outs=D.delay(fn()=>D.force(cells(List.map(fn value=>D.delay(fn()=>value))(outs()))))})
  fun register sto n=cells[
    newState n Inp 0(fn()=>[])(fn()=>[(0,zero,false,0,true,4)]),
    newState(n+1)Dff 1(fn()=>[(n+5,0,zero)])(fn()=>[(0,zero,false,0,true,5)]),
    newState(n+2)Inv 1(fn()=>[(sto,0,zero)])(fn()=>[(0,zero,false,0,true,1)]),
    newState(n+3)And2 2(fn()=>[(n+1,0,zero),(n+2,0,zero)])(fn()=>[(0,zero,false,0,true,2)]),
    newState(n+4)And2 1(fn()=>[(sto,0,zero),(n,0,zero)])(fn()=>[(0,zero,false,0,true,1)]),
    newState(n+5)Or2 3(fn()=>[(n+3,0,zero),(n+4,0,zero)])(fn()=>[(0,zero,true,4,false,0)]),
    newState(n+6)Outp 4(fn()=>[(n+1,0,zero)])(fn()=>[])]
  fun regs bits=D.delay(fn()=>
    let val indices=range(0,bits-1)
        val inputLabels=map(fn index=>D.delay(fn()=>
          (D.delay(fn()=>"x"^Int.toString(D.force index)),7*D.force index+1)))indices
        val outputLabels=map(fn index=>D.delay(fn()=>
          (D.delay(fn()=>"y"^Int.toString(D.force index)),7*D.force index+7)))indices
        val sto=newState 0 Inp 0(fn()=>[])(fn()=>[(0,zero,false,0,true,8*(bits-1)+5)])
        val groups=map(fn index=>D.delay(fn()=>D.force(register 0(7*D.force index+1))))indices
    in {size=1+7*bits,inputs=cons(D.delay(fn()=>(D.delay(fn()=>"sto"),0)),inputLabels),
        outputs=outputLabels,states=cons(sto,concat groups)}end)
  val emptyState=newState (~1) CNone (~1)(fn()=>[])(fn()=>[])
  fun nearestPower size=let fun loop n=if n>=size then n else loop(2*n)in loop 1 end
  fun pad circuit=D.delay(fn()=>
    let val{size,inputs,outputs,states}=D.force(circuit:circuit D.t)
        val p2=nearestPower size
    in{size=p2,inputs=inputs,outputs=outputs,states=take p2(append states(replicate p2 emptyState))}end)
  fun run bits cycles=
    let val inputs=replicate(bits+1)one
    in circuitSimulate(replicate cycles inputs)(pad(regs bits))end
  structure L=BenchLazy
  structure S=BenchStream
  val charF=L.delay(fn()=> #"F") val charT=L.delay(fn()=> #"T")
  val charOpen=L.delay(fn()=> #"[") val charClose=L.delay(fn()=> #"]")
  val charComma=L.delay(fn()=> #",")
  fun charCell c=case c of #"F"=>charF| #"T"=>charT| #"["=>charOpen| #"]"=>charClose
    | #","=>charComma|_=>raise Fail "invalid circuit show character"
  fun renderChecked expected values=
    let val position=ref 0 val size=String.size expected
        fun emit c after=L.delay(fn()=>
          let val _=if !position<size andalso c=String.sub(expected,!position)then()
                else raise Fail "incorrect result: circuit trace differs"
              val _=position:= !position+1
          in S.Cons(charCell c,after())end)
        fun bit value after=L.delay(fn()=>case D.force value of
          F=>L.force(emit #"F" after)|T=>L.force(emit #"T" after))
        fun list show values after=L.delay(fn()=>case D.force values of
            Nil=>L.force(emit #"["(fn()=>emit #"]" after))
          |Cons(value,rest)=>L.force(emit #"["(fn()=>show value(fn()=>listTail show rest after))))
        and listTail show values after=L.delay(fn()=>case D.force values of
            Nil=>L.force(emit #"]" after)
          |Cons(value,rest)=>L.force(emit #","(fn()=>show value(fn()=>listTail show rest after))))
        fun finish()=L.delay(fn()=>if !position=size then S.Nil
          else raise Fail "incorrect result: circuit trace is short")
    in list(fn row=>list bit row)values finish end
  fun consume heads source=
    let fun loop(sum,count,xs)=case L.force xs of S.Nil=>(count,if heads then sum+count else 0)
          |S.Cons(value,rest)=>loop(if heads then sum+Char.ord(L.force value)else sum,count+1,rest)
    in loop(0,0,source)end
  fun runChecked heads bits cycles expected=
    let val shown=renderChecked expected(run bits cycles)
        val output=if heads then S.append shown(S.singleton #"\n")else shown
    in consume heads output end
end

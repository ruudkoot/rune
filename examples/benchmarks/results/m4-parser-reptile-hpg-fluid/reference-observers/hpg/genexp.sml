 fun pickExp fs dp x k=choosew fs(fn selected=>
   let val(f,p)=selected in if p x then f dp x k else pickExp fs dp x k end)
 fun genExpressions dp k=allValues(fn values=>
   cmap(map(fn pair=>let val(name,value)=force pair
     in scalar(fn xc=>genExp dp value(fn e=>xc(scalar(name,e))))end)values)k)
 and genExp dp value k=if dp<=1 then k(valExp value)else
   pickExp(list[(1,(genExpPrime,fn _=>true)),(1,(genLambda,fn _=>true))])dp value k
 and genExpPrime dp value k=case force value of
     NumVal(kind,_)=>let val choices=case kind of FloatType=>floatFns()|DoubleType=>floatFns()|_=>intFns()
       in pickExp choices dp value k end
    |BoolVal b=>pickExp(list[(1,(genNot,fn _=>true)),(1,(genAnd,fn _=>true)),
         (1,(genOr,fn _=>true)),(1,(genLess,fn _=>true))])dp b k
    |CharVal c=>pickExp(list[(1,(genDecode,fn _=>true))])dp c k
    |ListVal values=>pickExp(list[(8,(genList,fn _=>true)),
         (1,(genDrop,fn _=>true)),(1,(genTake,fn _=>true))])dp values k
    |TupleVal values=>pickExp(list[(1,(genTuple,fn _=>true))])dp values k
    |TaggedVal(name,values)=>pickExp(list[(1,(genTagged,fn _=>true))])dp(name,values)k
    |ArrayVal(bounds,pairs)=>pickExp(list[(1,(genArray,fn _=>true))])dp(bounds,pairs)k
 and genDecode dp c k=unary chrName(dp-1)(intVal(Char.ord(force c)))k
 and genTuple dp values k=cmap(map(fn v=>scalar(genExp dp v))values)(fn es=>k(scalar(TupleExp es)))
 and genTagged dp(name,values)k=cmap(map(fn v=>scalar(genExp dp v))values)(fn es=>k(scalar(TaggedExp(name,es))))
 and genArray dp((a,b),pairs)k=genExp(dp-1)(tuple(F.cons(a,F.cons(b,F.empty()))))(fn e=>
       cmap(map(fn p=>let val(x,y)=force p in scalar(binary associateName(dp-1)x y)end)pairs)
       (fn es=>k(scalar(ArrayExp(e,scalar(ListExp es))))))
 and genPlus dp value k=case force value of NumVal(kind,n)=>
      binary plusName(dp-1)(numeric kind 1)(numeric kind(force n-1))k|_=>raise Match
 and genMinus dp value k=case force value of NumVal(kind,n)=>
      binary minusName(dp-1)(numeric kind(force n+1))(numeric kind 1)k|_=>raise Match
 and genMult dp value k=case force value of NumVal(kind,n)=>
      binary multiplyName(dp-1)value(numeric kind 1)k|_=>raise Match
 and genDiv dp value k=case force value of NumVal(kind,n)=>
      binary divideName(dp-1)value(numeric kind 1)k|_=>raise Match
 and genNegative dp value k=case force value of NumVal(kind,n)=>
      unary negateName(dp-1)(numeric kind(~(force n)))k|_=>raise Match
 and genIntId dp value k=case force value of NumVal(kind,n)=>allLambdas(fn values=>
     if null values then genPlus dp value k else choose values(fn pair=>
       let val(name,other)=force pair
           val m=case force other of NumVal(IntType,m)=>m|_=>raise Match
       in genExp(dp-1)(intVal(force n-force m))(fn e=>k(apply(apply(idExp plusName)(scalar(IdExp name)))e))end))
   |_=>raise Match
 and intFns()=list[(1,(genPlus,fn _=>true)),(1,(genMinus,fn _=>true)),
       (1,(genMult,fn _=>true)),(1,(genDiv,fn v=>case force v of NumVal(_,n)=>force n<>0|_=>raise Match)),
       (1,(genNegative,fn _=>true)),(1,(genIntId,fn _=>true))]
 and floatFns()=list[(1,(genPlus,fn _=>true)),(1,(genMinus,fn _=>true)),
       (1,(genMult,fn _=>true)),(1,(genNegative,fn _=>true)),(1,(genIntId,fn _=>true))]
 and genNot dp b k=unary notName(dp-1)(scalar(BoolVal(scalar(not(force b)))))k
 and genAnd dp b k=binary andName(dp-1)(scalar(BoolVal(scalar true)))(scalar(BoolVal b))k
 and genOr dp b k=binary orName(dp-1)(scalar(BoolVal(scalar false)))(scalar(BoolVal b))k
 and genLess dp b k=binary lessName(dp-1)(intVal(if force b then 0 else 1))(intVal 1)k
 and genList dp values k=cmap(map(fn v=>scalar(genExp(dp-1)v))values)(fn es=>k(scalar(ListExp es)))
 and genDrop dp values k=binary dropName(dp-1)(intVal(length values))(scalar(ListVal(F.append values values)))k
 and genTake dp values k=binary takeName(dp-1)(intVal(length values))(scalar(ListVal(F.append values values)))k
 and genLambda dp value k=getValNames 1(fn names=>
   let val name=head names
   in genIdValue(dp-1)(base(NumType IntType))(fn argument=>
      pushLambda(name,argument)(
       genExp(dp-1)value(fn e=>
       popLambda(fn _=>chooseCont[
          fn()=>extendValues(singleton(scalar(name,argument)))
             (k(apply(scalar(LambdaExp(name,e)))(scalar(IdExp name)))),
          fn()=>genExp(dp-1)argument(fn arg=>k(apply(scalar(LambdaExp(name,e)))arg))]))))end)
 and unary name dp value k=genExp dp value(fn e=>k(apply(idExp name)e))
 and binary name dp a b k=unary name dp a(fn e=>genExp dp b(fn e'=>k(apply e e')))

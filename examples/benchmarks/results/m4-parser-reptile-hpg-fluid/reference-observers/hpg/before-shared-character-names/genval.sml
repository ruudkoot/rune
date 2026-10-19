 fun genValues n dp k=allTypeNames(fn names=>
   cmap(rep n(fn vc=>upto(length names-1)(fn r=>genValue(nth names(force r))dp vc)))
   (fn values=>getValNames n(fn names=>extendValues(pairs names values)k)))
 and genValue name dp k=if dp<=1 then getType name(fn ty=>k(tagged(#1(force(head ty)))(F.empty())))
   else getType name(fn ty=>upto(length ty-1)(fn r=>
     let val(c,args)=force(nth ty(force r))
     in cmap(map(fn a=>scalar(genIdValue(dp-1)a))args)(fn vs=>k(tagged c vs))end))
 and genIdValue dp arg k=case force arg of NameType name=>genValue name dp k
   |BasicType bt=>genBasicValue(force bt)k
   |ListType id=>upto 5(fn r=>cmap(rep(force r)(genIdValue(dp-1)id))(fn vs=>k(scalar(ListVal vs))))
   |TupleType ids=>cmap(map(fn id=>scalar(genIdValue(dp-1)id))ids)(fn vs=>k(tuple vs))
   |ArrayType(id,element)=>cmap(rep 2(genIdValue(dp-1)id))(fn bounds=>
      let val a=head bounds val b=head(tail bounds)
      in upto 4(fn r=>let val vrng=finiteFromControl(C.take(force r+1)(vrange(a,b)))
           val bound=D.delay(fn()=>force(if null vrng then b else last vrng))
         in cmap(rep(length vrng)(genIdValue(dp-1)element))
           (fn vs=>k(scalar(ArrayVal((a,bound),pairs vrng vs))))end)end)
 and genBasicValue(NumType kind)k=upto 256(fn n=>k(scalar(NumVal(kind,n))))
   |genBasicValue BoolType k=choose(list[true,false])(fn b=>k(scalar(BoolVal b)))
   |genBasicValue CharType k=upto 127(fn n=>k(scalar(CharVal(D.delay(fn()=>Char.chr(force n))))))

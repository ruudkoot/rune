 fun chars s=C.fromList(String.explode s)
 structure B=struct
   type builder=chars->chars
   fun id rest=rest
   fun str s rest=C.append(chars s)rest
   fun cat a b rest=a(C.defer(fn()=>b rest))
   fun pieces []=id|pieces(x::xs)=cat x(pieces xs)
   fun delayed f rest=C.defer(fn()=>f()rest)
   fun output b=b(C.empty())
 end
 fun signed n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun showReal value=B.delayed(fn()=>B.str(BenchFluidFloatShow.show(force value)))
 fun showList printer values=B.delayed(fn()=>
   let fun loop values=B.delayed(fn()=>case force values of F.Nil=>B.id
       |F.Cons(x,rest)=>B.cat(printer x)(B.delayed(fn()=>if null rest then B.id
            else B.cat(B.str",")(loop rest))))
   in B.pieces[B.str"[",loop values,B.str"]"]end)
 fun showRealArray a=B.delayed(fn()=>let val(lo,hi)=A.bounds a
       fun entry p=B.delayed(fn()=>let val(i,v)=force p
         in B.pieces[B.str"(",B.str(signed i),B.str",",showReal v,B.str")"]end)
   in B.pieces[B.str"array (",B.str(signed lo),B.str",",B.str(signed hi),B.str") ",
      showList entry(A.associations a)]end)
 fun showVelocities(a,b)=B.pieces[B.str"(",showRealArray a,B.str",",showRealArray b,B.str")"]
 fun hash chars=let fun loop h chars=case L.force chars of C.Nil=>h
     |C.Cons(c,rest)=>loop(Word64.+(Word64.*(h,0w31),Word64.fromInt(Char.ord(L.force c))))rest
   in loop 0w0 chars end
 fun outputString chars=String.implode(C.toList chars)

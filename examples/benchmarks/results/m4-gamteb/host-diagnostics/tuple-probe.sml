signature Delay =
sig
 type 'a t
 val delay:(unit->'a)->'a t
 val force:'a t->'a
end
structure Strict:Delay=struct type 'a t='a fun delay f=f()fun force x=x end
structure Need:Delay=struct type 'a t=unit->'a fun delay f=f fun force f=f()end
functor Quad(D:Delay)=struct
 fun tuple()=(D.delay(fn()=>1.25),D.delay(fn()=>2.5),D.delay(fn()=>3.75),D.delay(fn()=>5.0))
 fun inside()=let val(a,b,c,d)=tuple()in[D.force a,D.force b,D.force c,D.force d]end
end
structure LazyQuad=Quad(Need)
structure StrictQuad=Quad(Strict)
structure Probe=struct
 val wanted=[1.25,2.5,3.75,5.0]
 fun check label observed=
  (print(label^" "^String.concatWith " "(List.map Real.toString observed)^"\n");
   T.check(label,fn()=>ListPair.allEq Real.==(observed,wanted)))
 val _=check "tuple/Need/internal"(LazyQuad.inside())
 val(a,b,c,d)=LazyQuad.tuple()
 val _=check "tuple/Need/external"[Need.force a,Need.force b,Need.force c,Need.force d]
 val _=check "tuple/Strict/internal"(StrictQuad.inside())
 val(a,b,c,d)=StrictQuad.tuple()
 val _=check "tuple/Strict/external"[Strict.force a,Strict.force b,Strict.force c,Strict.force d]
end

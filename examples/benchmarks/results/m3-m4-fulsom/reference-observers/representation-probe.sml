signature FULSOM_CELL=sig type 'a t val delay:(unit->'a)->'a t val force:'a t->'a end
structure FulsomDirect:FULSOM_CELL=struct type 'a t='a fun delay f=f()fun force x=x end
functor FulsomRepresentationFn(D:FULSOM_CELL)=
struct
 datatype value=Pair of real D.t*real D.t
 fun make()=Pair(D.delay(fn()=>1.0),D.delay(fn()=>2.0))
 fun sum(Pair(a,b))=D.force a+D.force b
end
structure FulsomRepresentation=FulsomRepresentationFn(FulsomDirect)
structure FulsomRepresentationProbe=
struct
 val value=FulsomRepresentation.make()
 val inside=FulsomRepresentation.sum value
 val outside=case value of FulsomRepresentation.Pair(a,b)=>FulsomDirect.force a+FulsomDirect.force b
 fun number r=Real.fmt(StringCvt.GEN(SOME 17))r
 val _=print("inside "^number inside^"\noutside "^number outside^"\n")
 val _=T.check("functor-real-payload/inside",fn()=>Real.==(inside,3.0))
 val _=T.check("functor-real-payload/outside",fn()=>Real.==(outside,3.0))
end

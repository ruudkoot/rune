signature DELAY =
sig
 type 'a t
 val delay:(unit->'a)->'a t
 val force:'a t->'a
end
structure Identity:DELAY =
struct
 type 'a t='a
 fun delay f=f()
 fun force x=x
end
functor PairFn(D:DELAY) =
struct
 datatype point=Point of real D.t*real D.t
 fun point()=Point(D.delay(fn()=>1.25),D.delay(fn()=>2.5))
 fun read(Point(x,y))=(D.force x,D.force y)
end
structure K=PairFn(Identity)
structure Bug =
struct
 val point=K.point()
 val(insideX,insideY)=K.read point
 val K.Point(x,y)=point
 val outsideX=Identity.force x
 val outsideY=Identity.force y
 val inside=Real.==(insideX,1.25)andalso Real.==(insideY,2.5)
 val outside=Real.==(outsideX,1.25)andalso Real.==(outsideY,2.5)
 val _=print((if inside then "PASS"else"FAIL")^" inside\n")
 val _=print((if outside then "PASS"else"FAIL")^" outside\n")
 val _=print("DETAIL "^Real.toString outsideX^" "^Real.toString outsideY^"\n")
 val failures=(if inside then 0 else 1)+(if outside then 0 else 1)
 val _=print("SUMMARY 2 checks, "^Int.toString failures^" failed\n")
 val _=OS.Process.exit(if failures=0 then OS.Process.success else OS.Process.failure)
end

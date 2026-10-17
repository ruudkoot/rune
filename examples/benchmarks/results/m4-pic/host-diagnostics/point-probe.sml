functor PicPointFn(D:BENCH_SUSPEND) =
struct
 datatype point=Point of real D.t * real D.t
 fun point()=Point(D.delay(fn()=>1.25),D.delay(fn()=>2.5))
 fun read(Point(x,y))=(D.force x,D.force y)
end
structure K=PicPointFn(BenchStrict)
structure PicPointProbe =
struct
 val point=K.point()
 val _=T.check("pic-point/internal",fn()=>
   let val(x,y)=K.read point in Real.==(x,1.25)andalso Real.==(y,2.5)end)
 val K.Point(x,y)=point
 val _=print("DETAIL external "^Real.toString(BenchStrict.force x)^" "^Real.toString(BenchStrict.force y)^"\n")
 val _=T.check("pic-point/external",fn()=>Real.==(BenchStrict.force x,1.25)andalso Real.==(BenchStrict.force y,2.5))
end

functor PicRepresentationFn(D:BENCH_SUSPEND) =
struct
 datatype item=Item of real D.t * int
 datatype matrix=Matrix of real D.t array
 fun item()=Item(D.delay(fn()=>1.25),17)
 fun matrix()=Matrix(Array.array(2,D.delay(fn()=>2.5)))
 fun readItem(Item(x,n))=(D.force x,n)
 fun readMatrix(Matrix a)=D.force(Array.sub(a,0))
end
structure K=PicRepresentationFn(BenchStrict)
structure PicRepresentationProbe =
struct
 val item=K.item()
 val matrix=K.matrix()
 val _=T.check("pic-representation/internal-item",fn()=>
   let val(x,n)=K.readItem item in Real.==(x,1.25)andalso n=17 end)
 val _=T.check("pic-representation/internal-array",fn()=>Real.==(K.readMatrix matrix,2.5))
 val K.Item(x,n)=item
 val K.Matrix a=matrix
 val _=print("DETAIL external item "^Real.toString(BenchStrict.force x)^" "^Int.toString n^"\n")
 val _=print("DETAIL external array "^Real.toString(BenchStrict.force(Array.sub(a,0)))^"\n")
 val _=T.check("pic-representation/external-item",fn()=>Real.==(BenchStrict.force x,1.25)andalso n=17)
 val _=T.check("pic-representation/external-array",fn()=>Real.==(BenchStrict.force(Array.sub(a,0)),2.5))
end

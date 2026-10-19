functor BenchScsMatrixFn (N : sig
  type t
  val zero : t
  val one : t
  val add : t * t -> t
  val sub : t * t -> t
  val mul : t * t -> t
  val divide : t * t -> t
  val absolute : t -> t
  val compare : t * t -> order
  val equal : t * t -> bool
end) =
struct
  structure L=BenchLazy
  type scalar=N.t
  datatype matrix=Mat of int * int * scalar L.delay Vector.vector
  datatype vector=Vec of scalar L.delay Vector.vector
  fun rows(Mat(r,_,_))=r
  fun columns(Mat(_,c,_))=c
  fun size(Vec values)=Vector.length values
  fun at(Mat(_,c,values))(r,col)=L.force(Vector.sub(values,(r-1)*c+col-1))
  fun sub(Vec values)i=L.force(Vector.sub(values,i-1))
  fun matrix(r,c)f=Mat(r,c,Vector.tabulate(r*c,fn i=>L.delay(fn()=>f(i div c+1,i mod c+1))))
  fun vector n f=Vec(Vector.tabulate(n,fn i=>L.delay(fn()=>f(i+1))))
  fun forceMatrix(Mat(_,_,values))=Vector.app(fn value=>ignore(L.force value))values
  fun forceVector(Vec values)=Vector.app(fn value=>ignore(L.force value))values
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun update(Mat(r,c,values))changes=
    let val next=Array.tabulate(Vector.length values,fn i=>Vector.sub(values,i))
        val _=List.app(fn((row,col),value)=>Array.update(next,(row-1)*c+col-1,value))changes
    in Mat(r,c,Vector.tabulate(Vector.length values,fn i=>Array.sub(next,i)))end
  fun updateVector(Vec values)changes=
    let val next=Array.tabulate(Vector.length values,fn i=>Vector.sub(values,i))
        val _=List.app(fn(i,value)=>Array.update(next,i-1,value))changes
    in Vec(Vector.tabulate(Vector.length values,fn i=>Array.sub(next,i)))end
  fun accumMatrix(r,c)build=
    let val values=Array.tabulate(r*c,fn _=>L.delay(fn()=>N.zero))
        fun add((row,col),value)=
          let val index=(row-1)*c+col-1 val old=Array.sub(values,index)
          in Array.update(values,index,L.delay(fn()=>N.add(L.force old,L.force value)))end
        val _=build add
    in Mat(r,c,Vector.tabulate(r*c,fn i=>Array.sub(values,i)))end
  fun accumVector n build=
    let val values=Array.tabulate(n,fn _=>L.delay(fn()=>N.zero))
        fun add(i,value)=let val old=Array.sub(values,i-1)
          in Array.update(values,i-1,L.delay(fn()=>N.add(L.force old,L.force value)))end
        val _=build add
    in Vec(Vector.tabulate(n,fn i=>Array.sub(values,i)))end
  fun map f m=matrix(rows m,columns m)(fn index=>f(at m index))
  fun mapVector f v=vector(size v)(fn i=>f(sub v i))
  fun zip f a b=if rows a<>rows b orelse columns a<>columns b then raise Fail "matrix bounds differ"
    else matrix(rows a,columns a)(fn index=>f(at a index,at b index))
  fun zipVector f a b=if size a<>size b then raise Fail "vector bounds differ"
    else vector(size a)(fn i=>f(sub a i,sub b i))
  fun add a b=zip N.add a b
  fun subtract a b=zip N.sub a b
  fun subtractVector a b=zipVector N.sub a b
  fun zero n=matrix(n,n)(fn _=>N.zero)
  fun unit n=matrix(n,n)(fn(r,c)=>if r=c then N.one else N.zero)
  fun transpose m=matrix(columns m,rows m)(fn(r,c)=>at m(c,r))
  fun select selected m=Mat(List.length selected,columns m,
    Vector.fromList(List.concat(List.map(fn r=>List.tabulate(columns m,fn c=>L.delay(fn()=>at m(r,c+1))))selected)))
  fun multiply a b=if columns a<>rows b then raise Fail "matrix dimensions differ" else
    accumMatrix(rows a,columns b)(fn add=>
      for 1(rows a)(fn r=>for 1(columns a)(fn t=>for 1(columns b)(fn c=>
        add((r,c),L.delay(fn()=>N.mul(at a(r,t),at b(t,c))))))))
  fun apply m v=if columns m<>size v then raise Fail "matrix/vector dimensions differ" else
    accumVector(rows m)(fn add=>for 1(rows m)(fn r=>for 1(columns m)(fn c=>
      add(r,L.delay(fn()=>N.mul(sub v c,at m(r,c)))))))
  fun gaussJordan original=
    let val n=rows original
        val _=if n=columns original then()else raise Fail "not a square matrix"
        val _=if n>0 then()else raise Fail "empty gauss-jordan composition"
        fun swap first second m=update m(List.concat(List.tabulate(n,fn col=>
          [((first,col+1),L.delay(fn()=>at m(second,col+1))),((second,col+1),L.delay(fn()=>at m(first,col+1)))])))
        fun scale row factor m=update m(List.tabulate(n,fn col=>
          ((row,col+1),L.delay(fn()=>N.mul(factor,at m(row,col+1))))))
        fun eliminate pivot m1 m=update m(List.concat(List.map(fn r=>
          List.tabulate(n,fn col=>((r,col+1),L.delay(fn()=>N.sub(at m(r,col+1),N.mul(at m1(r,pivot),at m(pivot,col+1)))))))
          (List.filter(fn r=>r<>pivot)(List.tabulate(n,fn i=>i+1)))))
        fun pivot c [] _=raise Fail "empty pivot candidates"
          |pivot c (first::rest) m=List.foldl(fn(r,(chosen,value))=>
             let val next=at m(r,c)
             in if N.compare(N.absolute value,N.absolute next)<>LESS then(chosen,value)else(r,next)end)
             (first,at m(first,c))rest
        fun loop c free m inverse=if c>n then(free,m,inverse)else
          let val(row,value)=pivot c free m
          in if N.equal(value,N.zero)then loop(c+1)free m inverse else
             let val factor=N.divide(N.one,value)
                 fun normal old=scale c factor(if row=c then old else swap row c old)
                 val m1=normal m val i1=normal inverse
                 val m2=eliminate c m1 m1 val i2=eliminate c m1 i1
             in loop(c+1)(List.filter(fn r=>r<>c)free)m2 i2 end
          end
    in loop 1(List.tabulate(n,fn i=>i+1))original(unit n)end
end

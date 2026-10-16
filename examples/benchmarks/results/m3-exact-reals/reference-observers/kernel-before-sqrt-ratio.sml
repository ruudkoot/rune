functor BenchExactRealsFn (D : BENCH_SUSPEND) =
struct
  structure I=IntInf
  structure R=BenchScsRational
  structure L=BenchLazy
  structure S=BenchStream
  datatype cr=CR of int -> I.int
  datatype 'a node=Nil|Cons of 'a D.t * 'a node D.t
  fun pow2 n=I.pow(2,n)
  fun rounded value=let val(n,d)=R.add(value,R.make(1,2))in I.div(n,d)end
  fun sizeInBase n=
    let fun loop value=if value<=1 then 1 else 1+loop(I.div(value,2))
    in loop(I.abs n)end
  fun bits p(CR f)=f p
  fun integer n=CR(fn p=>I.*(n,pow2 p))
  fun binary safety f(CR x,CR y)=CR(fn p=>
    if safety=0 then f(x p,y p)
    else rounded(R.make(f(x(p+safety),y(p+safety)),pow2 safety)))
  fun add pair=binary 2 I.+ pair
  fun negative(CR x)=CR(fn p=>I.~(x p))
  fun subtract(x,y)=add(x,negative y)
  fun multiply(CR x,CR y)=
    let val bounds=L.delay(fn()=>(sizeInBase(I.+(I.abs(x 0),2))+3,
                                  sizeInBase(I.+(I.abs(y 0),2))+3))
    in CR(fn p=>let val(sx,sy)=L.force bounds
       in rounded(R.make(I.*(x(p+sy),y(p+sx)),pow2(p+sx+sy)))end)end
  fun reciprocal(CR x)=CR(fn p=>
    let fun find n=if I.abs(x n)>=3 then n else find(n+1)
        val s=find 0
    in rounded(R.make(pow2(2*p+2*s+2),x(p+2*s+2)))end)
  fun divide(x,y)=multiply(x,reciprocal y)
  fun div2n(CR x)n=CR(fn p=>if p>=n then x(p-n)else rounded(R.make(x p,pow2 n)))
  fun mul2n(CR x)n=CR(fn p=>x(p+n))
  fun floorSqrt x=
    let fun loop y=
          let val square=I.*(y,y)val next=I.+(y,1)
          in if square<=x andalso x<=I.*(next,next)then y
             else loop(I.div(I.+(square,x),I.*(2,y)))end
    in loop x end
  fun squareRoot(CR x)=CR(fn p=>floorSqrt(x(2*p)))
  fun take 0 stream=D.delay(fn()=>Nil)
    |take n stream=D.delay(fn()=>case L.force stream of S.Nil=>Nil
      |S.Cons(x,xs)=>Cons(D.delay(fn()=>L.force x),take(n-1)xs))
  fun coefficientScan update=
    S.map(fn(_,value)=>value)(S.iterate(fn(n,value)=>(I.+(n,1),update(value,n)))
      (L.delay(fn()=>((1:I.int),R.one))))
  val sinCoefficients=coefficientScan(fn(a,n)=>
    R.mul(R.negative a,R.make(1,I.*(I.*(2,n),I.+(I.*(2,n),1)))))
  val cosCoefficients=coefficientScan(fn(a,n)=>
    R.mul(R.negative a,R.make(1,I.*(I.*(2,n),I.-(I.*(2,n),1)))))
  val atanCoefficients=S.map(fn n=>R.make(if I.mod(n,2)=0 then 1 else ~1,I.+(I.*(2,n),1)))
    (S.iterate(fn n=>I.+(n,1))(L.delay(fn()=>(0:I.int))))
  fun powerSeries coefficients terms(CR x)=CR(fn p=>
    let val t=terms p val l2t=2*sizeInBase(I.fromInt(t+1))+6 val precision=p+l2t
        val xr=L.delay(fn()=>x precision)
        fun next value=rounded(R.make(I.*(value,L.force xr),pow2 precision))
        val powers=take t(S.iterate next(L.delay(fn()=>pow2 precision)))
        val selected=take t coefficients
        fun sum powers selected=case D.force selected of Nil=>0
          |Cons(coefficient,cs)=>(case D.force powers of Nil=>raise Empty
            |Cons(value,xs)=>
               let val term=rounded(R.mul(D.force coefficient,R.make(D.force value,1)))
               in if term=0 then 0 else I.+(term,sum xs cs)end)
    in rounded(R.make(sum powers selected,pow2 l2t))end)
  fun sinDr x=multiply(x,powerSeries sinCoefficients(fn p=>p+2)(multiply(x,x)))
  fun cosDr x=powerSeries cosCoefficients(fn p=>p+2)(multiply(x,x))
  fun atanDr x=multiply(x,powerSeries atanCoefficients(fn p=>p+2)(multiply(x,x)))
  val constants:cr L.delay option Array.array=Array.array(4,NONE)
  fun constant n=L.force(valOf(Array.sub(constants,n)))
  fun atan x=
    let val t=bits 3 x val xp1=add(x,integer 1)val xm1=subtract(x,integer 1)
    in if t<= ~20 then subtract(atanDr(negative(reciprocal x)),constant 1)
       else if t<= ~4 then subtract(negative(constant 2),atanDr(divide(xp1,xm1)))
       else if t<=3 then atanDr x
       else if t<=19 then add(constant 2,atanDr(divide(xm1,xp1)))
       else subtract(constant 1,atanDr(reciprocal x))end
  fun rangeReduce x=
    let val s=rounded(R.make(bits 2(divide(x,constant 2)),pow2 2))
    in (I.mod(s,8),subtract(x,multiply(constant 2,integer s)))end
  fun sinReduced(n,y)=
    if n=0 then sinDr y
    else if n=1 then multiply(constant 3,add(cosDr y,sinDr y))
    else if n=2 then cosDr y
    else if n=3 then multiply(constant 3,subtract(cosDr y,sinDr y))
    else negative(sinReduced(I.-(n,4),y))
  fun sine x=sinReduced(rangeReduce x)
  fun cosine x=let val(n,y)=rangeReduce x in sinReduced(I.mod(I.+(n,2),8),y)end
  val _=Array.update(constants,0,SOME(L.delay(fn()=>
    subtract(multiply(integer 16,atan(divide(integer 1,integer 5))),
             multiply(integer 4,atan(divide(integer 1,integer 239)))))))
  val _=Array.update(constants,1,SOME(L.delay(fn()=>div2n(constant 0)1)))
  val _=Array.update(constants,2,SOME(L.delay(fn()=>div2n(constant 0)2)))
  val _=Array.update(constants,3,SOME(L.delay(fn()=>squareRoot(reciprocal(integer 2)))))
  val digits=40
  fun digitsToBits d=Real.ceil(Real.fromInt d*(Math.ln 10.0/Math.ln 2.0))+4
  fun fromEnum x=I.toInt(rounded(R.make(bits(digitsToBits digits)x,pow2(digitsToBits digits))))
  fun toEnum n=integer(I.fromInt n)
  fun sumSin count=
    let val first=fromEnum(integer 1)val last=fromEnum(integer(I.fromInt count))
        fun loop(i,total)=if i>last then total
          else loop(i+1,add(total,sine(multiply(toEnum i,constant 0))))
    in loop(first,integer 0)end
  fun text d x=
    let val b=digitsToBits d val n=rounded(R.make(I.*(bits b x,I.pow(10,d)),pow2 b))
        val negative=n<0 val raw=I.toString(I.abs n)
        val padded=String.implode(List.tabulate(Int.max(d+1-String.size raw,0),fn _=> #"0"))^raw
        val split=String.size padded-d
    in(if negative then "-"else"")^String.substring(padded,0,split)^
      (if d>0 then "."^String.extract(padded,split,NONE)else"")end
  fun run count=text digits(sumSin count)
end

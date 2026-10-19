functor BenchPrimeTestFn(D:BENCH_SUSPEND) =
struct
  structure I=IntInf
  structure L=BenchLazy
  structure S=BenchStream
  datatype 'a node=Nil|Cons of 'a D.t * 'a node D.t
  fun empty()=D.delay(fn()=>Nil)
  fun map f xs=D.delay(fn()=>case D.force xs of Nil=>Nil
    |Cons(x,rest)=>Cons(D.delay(fn()=>f(D.force x)),map f rest))
  fun length xs=case D.force xs of Nil=>0|Cons(_,rest)=>1+length rest
  fun chop base n =
    let fun loop acc value=if value=0 then acc
          else let val parts=L.delay(fn()=>I.divMod(value,base))
                   val digit=D.delay(fn()=> #2(L.force parts))
                   val next=D.delay(fn()=>Cons(digit,acc))
               in loop next(#1(L.force parts))end
    in loop(empty())n end
  fun makeNumber base digits =
    let fun loop acc xs=case D.force xs of Nil=>D.force acc
          |Cons(x,rest)=>loop(D.delay(fn()=>I.+(I.*(D.force acc,base),D.force x)))rest
    in loop(D.delay(fn()=>(0:I.int)))digits end
  fun powerMod(a:I.int)(b:I.int)(m:I.int)=
    if b=0 then 1 else
      let val reduced=I.mod(a,m)
          fun f a b c=if b=0 then c else
            let fun g a b=if I.mod(b,2)=0 then g(I.mod(I.*(a,a),m))(I.div(b,2))
                  else f a(I.-(b,1))(I.mod(I.*(a,c),m))
            in g a b end
      in f reduced(I.-(b,1))reduced end
  fun splitAt 0 source=(empty(),source)
    |splitAt n source=
      let val parts=L.delay(fn()=>case L.force source of S.Nil=>(empty(),S.empty())
            |S.Cons(x,rest)=>
              let val(prefix,after)=splitAt(n-1)rest
              in(D.delay(fn()=>Cons(D.delay(fn()=>L.force x),prefix)),after)end)
      in(D.delay(fn()=>D.force(#1(L.force parts))),
         L.delay(fn()=>L.force(#2(L.force parts))))end
  fun uniform digits draws=D.delay(fn()=>case D.force digits of Nil=>raise Match
    |Cons(n,ns)=>case D.force draws of Nil=>raise Match
      |Cons(r,rs)=>case D.force ns of Nil=>
          Cons(D.delay(fn()=>I.mod(D.force r,D.force n)),empty())
        |Cons _=>
          let val t=D.delay(fn()=>I.mod(D.force r,I.+(D.force n,1)))
              val tail=D.delay(fn()=>D.force(if D.force t=D.force n then uniform ns rs
                else map(fn value=>I.mod(value,65536))rs))
          in Cons(t,tail)end)
  fun random n source =
    let val digits=chop 65536 n
        val(prefix,after)=splitAt(length digits)source
        val value=L.delay(fn()=>makeNumber 65536(uniform digits prefix))
    in(value,after)end
  fun findKQ n =
    let fun loop k q=
          let val(d,r)=I.divMod(q,2)
          in if r=0 then loop(I.+(k,1))d else(k,q)end
    in loop 0(I.-(n,1))end
  fun take 0 stream=empty()
    |take n stream=D.delay(fn()=>case L.force stream of S.Nil=>Nil
      |S.Cons(x,rest)=>Cons(D.delay(fn()=>L.force x),take(n-1)rest))
  fun testPowers n powers =
    let fun witness values=case D.force values of Nil=>false
          |Cons(x,rest)=>if D.force x=I.-(n,1)then true
            else if D.force x=1 then false else witness rest
    in case D.force powers of Nil=>raise Match
      |Cons(t,rest)=>D.force t=1 orelse D.force t=I.-(n,1)orelse witness rest end
  fun singleTestX n(k,q)x =
    let val powers=take(I.toInt k)(S.iterate(fn value=>I.mod(I.*(value,value),n))
          (L.delay(fn()=>powerMod x q n)))
    in testPowers n powers end
  fun singleTest n source =
    let val kq=findKQ n
        val(value,after)=random(I.-(n,2))source
    in(singleTestX n kq(I.+(2,L.force value)),after)end
  fun multiTest trials source n =
    if n<=1 orelse I.mod(n,2)=0 then(n=2,source)
    else let fun loop 0 rs=(true,rs)
               |loop k rs=let val(passed,rest)=singleTest n rs
                 in if passed then loop(k-1)rest else(false,rest)end
         in loop trials source end
  fun initial()=BenchScsRandom.raw(L.delay(fn()=>(0w111,0w47)))
  fun readInteger line =
    case String.tokens Char.isSpace line of [text] =>
      let val chars=String.explode text
          val digits=case chars of #"-"::rest=>rest|_=>chars
      in if null digits orelse not(List.all Char.isDigit digits)then raise Fail "invalid primetest integer"
         else case I.fromString text of SOME n=>n|NONE=>raise Fail "invalid primetest integer"end
    |_=>raise Fail "invalid primetest integer"
  fun process trials lines =
    let fun loop [] _=[]
          |loop(line::rest)source=
             let val n=readInteger line
                 val(passed,after)=multiTest trials source n
             in(if passed then "Probably prime"else"Composite")::loop rest after end
    in String.concat(loop lines(initial()))end
end

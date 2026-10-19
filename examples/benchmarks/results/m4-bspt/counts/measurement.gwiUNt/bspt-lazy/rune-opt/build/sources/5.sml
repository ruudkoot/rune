(* nofib BSPT lazy rational arithmetic. The pinned GHC host uses signed
   machine Int64: arithmetic wraps modulo 2^64 rather than grow unbounded. *)
functor BenchBSPTRationalFn(D:BENCH_SUSPEND) =
struct
  structure L=BenchLazy
  val modulus=IntInf.<<(IntInf.fromInt 1,0w64)
  val halfRange=IntInf.<<(IntInf.fromInt 1,0w63)
  fun wrap x=let val x=IntInf.mod(x,modulus)
    in if x>=halfRange then IntInf.-(x,modulus)else x end
  fun iadd(a,b)=wrap(IntInf.+(a,b))
  fun imul(a,b)=wrap(IntInf.*(a,b))
  fun ineg a=wrap(IntInf.~ a)
  fun iabs a=if a<0 then ineg a else a
  fun sign(a:IntInf.int)=if a<0 then IntInf.fromInt ~1 else if a=0 then IntInf.fromInt 0 else IntInf.fromInt 1
  fun idiv(a,b)=if b=0 then raise Div else
    if a=IntInf.~ halfRange andalso b=IntInf.fromInt ~1 then raise Overflow else IntInf.div(a,b)
  fun gcd a b=
    let val a=iabs a val b=iabs b
        val _=if a<0 orelse b<0 then raise Overflow else()
        fun loop a b=if b=0 then a else loop b(IntInf.rem(a,b))
    in loop a b end
  type integer=IntInf.int D.t
  datatype node=Q of integer*integer
  type rational=node L.delay
  fun integer f=D.delay f
  fun value x=D.force x
  fun node(a,b)=L.delay(fn()=>Q(a,b))
  fun number n=node(integer(fn()=>wrap(IntInf.fromInt n)),integer(fn()=>IntInf.fromInt 1))
  val zero=number 0 val one=number 1
  fun numerator r=let val Q(n,_)=L.force r in value n end
  fun denominator r=let val Q(_,d)=L.force r in value d end
  fun simplify x y=
    let val divisor=integer(fn()=>gcd(value x)(value y))
        val top=integer(fn()=>idiv(value x,value divisor))
        val bottom=integer(fn()=>idiv(value y,value divisor))
    in node(integer(fn()=>imul(sign(value bottom),value top)),integer(fn()=>iabs(value bottom)))end
  fun equal a b=let val Q(p,q)=L.force a val Q(r,s)=L.force b
    in value p=value r andalso value q=value s end
  fun lessEqual a b=let val Q(p,q)=L.force a val Q(r,s)=L.force b
    in imul(value p,value s)<=imul(value q,value r)end
  fun compare a b=if equal a b then EQUAL else if lessEqual a b then LESS else GREATER
  fun less a b=compare a b=LESS
  fun greater a b=compare a b=GREATER
  fun add a b=L.delay(fn()=>
    let val Q(p,q)=L.force a val Q(r,s)=L.force b
        val result=if value q=1 then
            if value s=1 then node(integer(fn()=>iadd(value p,value r)),integer(fn()=>IntInf.fromInt 1))
            else simplify(integer(fn()=>iadd(imul(value p,value s),value r)))s
          else if value s=1 then simplify(integer(fn()=>iadd(value p,imul(value q,value r))))q
          else simplify(integer(fn()=>iadd(imul(value p,value s),imul(value q,value r))))
                 (integer(fn()=>imul(value q,value s)))
    in L.force result end)
  fun mul a b=L.delay(fn()=>
    let val Q(p,q)=L.force a val Q(r,s)=L.force b
        val product=integer(fn()=>imul(value p,value r))
        val result=if value q=1 then if value s=1 then node(product,integer(fn()=>IntInf.fromInt 1))
             else simplify product s
          else if value s=1 then simplify product q
          else simplify product(integer(fn()=>imul(value q,value s)))
    in L.force result end)
  fun negate a=L.delay(fn()=>let val Q(p,q)=L.force a in Q(integer(fn()=>ineg(value p)),q)end)
  fun abs a=L.delay(fn()=>let val Q(p,q)=L.force a in Q(integer(fn()=>iabs(value p)),q)end)
  fun signum a=node(integer(fn()=>sign(numerator a)),integer(fn()=>IntInf.fromInt 1))
  fun sub a b=add a(negate b)
  fun divide a b=L.delay(fn()=>
    let val Q(r,s)=L.force b
    in if value r=0 then raise Fail "attempt to divide a BSPT rational by zero"
       else L.force(mul a(node(s,r)))end)
  fun positive a=greater(signum a)zero
  fun negative a=less(signum a)zero
  fun isZero a=equal a zero
  fun ratio a b=
    if equal a zero then(zero,if positive b then one else number ~1)
    else if equal b zero then(if positive a then one else number ~1,zero)
    else let val quotient=L.delay(fn()=>L.force(divide(abs a)(abs b)))
             val n=node(integer(fn()=>let val Q(n,_)=L.force quotient in value n end),integer(fn()=>IntInf.fromInt 1))
             val d=node(integer(fn()=>let val Q(_,d)=L.force quotient in value d end),integer(fn()=>IntInf.fromInt 1))
         in(mul(signum a)n,mul(signum b)d)end
  val half=divide one(number 2)
  fun round a=
    let val Q(n,d)=L.force a
    in if value d=1 then value n else
       let val total=add half a in idiv(numerator total,denominator total)end end
  fun grid a=L.delay(fn()=>
    let val Q(n,d)=L.force a
    in if value d<>1 then raise Match else
      Q(integer(fn()=>imul(idiv(iadd(value n,IntInf.fromInt 5),IntInf.fromInt 10),IntInf.fromInt 10)),
        integer(fn()=>IntInf.fromInt 1))end)
end

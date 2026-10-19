(* BasicNumber and BasicNumberApprox translations. Exact rational reduction
 * and the source precision-dependent comparisons are retained. *)
functor BenchSymalgNumberFn(D:BENCH_SUSPEND)=
struct
 structure R=BenchSymalgRealFn(D)
 structure Z=IntInf
 datatype number=Integer of Z.int|Rational of Z.int*Z.int|Real of R.realT
 fun gcd(a:Z.int,b:Z.int)=if b=0 then Z.abs a else gcd(b,Z.mod(a,b))
 fun rational(a,b)=if b=0 then raise Div
   else let val g=gcd(a,b)val sign=if b<0 then ~1 else 1
        in Rational(Z.quot(a,g)*sign,Z.quot(b,g)*sign)end
 fun toRational(Rational pair)=pair|toRational(Integer x)=(x,1)
   |toRational(Real _)=raise Fail"toRational : Real cannot be coerced to rational"
 fun toReal(Real x)=x
   |toReal(Integer x)=R.fromInteger x
   |toReal(Rational(a,b))=if a=0 then R.fromInteger 0 else R.divide(R.fromInteger a)(R.fromInteger b)
 fun add(Real x)y=Real(R.add x(toReal y))
   |add x(Real y)=Real(R.add(toReal x)y)
   |add(Integer x)(Integer y)=Integer(x+y)
   |add x y=let val(a,b)=toRational x val(c,d)=toRational y in rational(a*d+c*b,b*d)end
 fun subtract(Real x)y=Real(R.subtract x(toReal y))
   |subtract x(Real y)=Real(R.subtract(toReal x)y)
   |subtract(Integer x)(Integer y)=Integer(x-y)
   |subtract x y=let val(a,b)=toRational x val(c,d)=toRational y in rational(a*d-c*b,b*d)end
 fun multiply(Real x)y=Real(R.multiply x(toReal y))
   |multiply x(Real y)=Real(R.multiply(toReal x)y)
   |multiply(Integer x)(Integer y)=Integer(x*y)
   |multiply x y=let val(a,b)=toRational x val(c,d)=toRational y in rational(a*c,b*d)end
 fun divide(Real x)y=Real(R.divide x(toReal y))
   |divide x(Real y)=Real(R.divide(toReal x)y)
   |divide x y=let val(a,b)=toRational x val(c,d)=toRational y in rational(a*d,b*c)end
 fun rationalCompare x y=let val(a,b)=toRational x val(c,d)=toRational y in Z.compare(a*d,c*b)end
 fun realDifference x y n=R.eval(toReal x)n-R.eval(toReal y)n
 fun equal(Real x)y n=Z.abs(realDifference(Real x)y n)<=2
   |equal x(y as Real _)n=equal y x n
   |equal x y _=rationalCompare x y=EQUAL
 fun less(x as Real _)y n=realDifference x y n< ~2
   |less x(y as Real _)n=greater y x n
   |less x y _=rationalCompare x y=LESS
 and greater(x as Real _)y n=realDifference x y n>2
   |greater x(y as Real _)n=less y x n
   |greater x y _=rationalCompare y x=LESS
 fun lessEqual x y n=not(greater x y n)
 fun greaterEqual x y n=not(less x y n)
 fun notEqual x y n=not(equal x y n)
 fun squareRoot x=Real(R.sqrt(toReal x))
 fun makeReal x=Real(toReal x)
 fun makeRational(x as Rational _)=x
   |makeRational(Integer x)=Rational(x,1)
   |makeRational(Real _)=raise Fail"makeRational : real requires precision"
 fun rationalAt(Real x)n=if n<=0 then rational(R.eval x n,R.power(~n))
                        else rational(R.eval x n*R.power n,1)
   |rationalAt x _=makeRational x
 fun decimal text=
   let val parts=String.fields(fn c=>c= #".")text
       fun integer t=case Z.fromString t of SOME x=>x|NONE=>raise Fail"invalid BasicNumber literal"
   in case parts of [a]=>Integer(integer a)
      |[a,b]=>if List.all(fn c=>c= #"0")(String.explode b)then Integer(integer a)
               else let val value=case Real.fromString text of SOME x=>x|NONE=>raise Fail"invalid rational literal"
                        val {man,exp}=Real.toManExp value
                        val mantissa=Real.toLargeInt IEEEReal.TO_NEAREST(man*9007199254740992.0)
                    in if exp>=53 then rational(mantissa*Z.pow(2,exp-53),1)
                       else rational(mantissa,Z.pow(2,53-exp))end
      |_=>raise Fail"invalid BasicNumber literal"end
 fun decimalInteger n=
   let val text=Z.toString n
   in if String.isPrefix"~"text then "-"^String.extract(text,1,NONE)else text end
 fun format(Real x)(prec:Z.int)=
   let val text=decimalInteger(R.eval x prec)
       val prefixLength=String.size text+Z.toInt prec
       val whole=if prefixLength<=0 then"0"else String.substring(text,0,Int.min(prefixLength,String.size text))
       val fraction=if prefixLength<0 then String.implode(List.tabulate(~prefixLength,fn _=> #"0"))^text
                    else String.extract(text,Int.min(prefixLength,String.size text),NONE)
   in whole^"."^fraction end
   |format(Rational(a,b))_=(if a<0 then"("^decimalInteger a^")"else decimalInteger a)^" % "^decimalInteger b
   |format(Integer x)_=decimalInteger x
end

(* Ratio operations follow GHC.Real at the pinned GHC9.4.7 revision.
   Copyright University of Glasgow1994-2002; retain ghc-base/LICENSE. *)
structure BenchScsRational =
struct
  structure I = IntInf
  type t = I.int * I.int
  val zero : t = (0,1)
  val one : t = (1,1)
  fun gcd (a,b) = if b=0 then I.abs a else gcd (b,I.rem(a,b))
  fun make (n,d) = if d=0 then raise Div else
    let val n=if d<0 then I.~ n else n val d=I.abs d val divisor=gcd(n,d)
    in (I.quot(n,divisor),I.quot(d,divisor)) end
  fun fromInt n : t = (I.fromInt n,1)
  fun add ((a,b):t,(c,d):t) = make(I.+(I.*(a,d),I.*(c,b)),I.*(b,d))
  fun sub ((a,b):t,(c,d):t) = make(I.-(I.*(a,d),I.*(c,b)),I.*(b,d))
  fun mul ((a,b):t,(c,d):t) = make(I.*(a,c),I.*(b,d))
  fun divide ((a,b):t,(c,d):t) = make(I.*(a,d),I.*(b,c))
  fun negative ((n,d):t) : t = (I.~ n,d)
  fun absolute ((n,d):t) : t = (I.abs n,d)
  fun compare ((a,b):t,(c,d):t) = I.compare(I.*(a,d),I.*(c,b))
  fun equal (a:t,b:t) = a=b
  fun pow2 n = I.pow(2,n)
  fun bits n =
    let fun loop value count = if value=0 then count else loop (I.quot(value,2)) (count+1)
    in loop n 0 end
  fun rounded (n,d) =
    let val q=I.quot(n,d) val remainder=I.rem(n,d)
    in case I.compare(I.*(2,remainder),d) of
         GREATER=>I.+(q,1) | EQUAL=>if I.mod(q,2)=1 then I.+(q,1)else q | LESS=>q
    end
  fun real ((numerator,denominator):t) =
    if numerator=0 then 0.0 else
    let val n=I.abs numerator val d=denominator
        val approximate=bits n-bits d
        val atLeast=if approximate>=0 then I.>=(n,I.*(d,pow2 approximate))
                    else I.>=(I.*(n,pow2(~approximate)),d)
        val exponent=if atLeast then approximate else approximate-1
        val magnitude=
          if exponent>1023 then Real.posInf
          else if exponent< ~1075 then 0.0
          else if exponent< ~1022 then
            Real.fromManExp {man=Real.fromLargeInt(rounded(I.*(n,pow2 1074),d)),exp= ~1074}
          else
            let val shift=52-exponent
                val significand=if shift>=0 then rounded(I.*(n,pow2 shift),d)
                                else rounded(n,I.*(d,pow2(~shift)))
            in if exponent=1023 andalso I.>=(significand,pow2 53) then Real.posInf
               else Real.fromManExp {man=Real.fromLargeInt significand,exp=exponent-52}
            end
    in if numerator<0 then Real.~ magnitude else magnitude end
end

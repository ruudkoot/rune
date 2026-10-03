(* Integer Ratio arithmetic used by the pinned GHC 9.4.7 base library. *)
structure BenchRational =
struct
  type rational = IntInf.int * IntInf.int
  fun gcd (a,b) = if b=0 then IntInf.abs a else gcd (b,IntInf.rem(a,b))
  fun ratio (n,d) = if d=0 then raise Div else
    let val numerator=if d<0 then IntInf.~ n else n
        val denominator=IntInf.abs d
        val g=gcd(numerator,denominator)
    in (IntInf.quot(numerator,g),IntInf.quot(denominator,g)) end
  fun add ((a,b):rational,(c,d):rational) =
    ratio (IntInf.+(IntInf.*(a,d),IntInf.*(c,b)),IntInf.*(b,d))
  fun show (n,d) =
    let fun number x =
          let val s=String.translate(fn #"~"=>"-"|c=>String.str c)(IntInf.toString x)
          in if x<0 then "("^s^")" else s end
    in number n ^ " % " ^ number d end
end

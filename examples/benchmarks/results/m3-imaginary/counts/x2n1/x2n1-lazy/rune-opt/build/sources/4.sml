(* Complex arithmetic and positive integral power order from GHC 9.4.7 base. *)
structure BenchX2N1 =
struct
  type complex = real * real
  val epsilon = 2.220446049250313E~16
  fun add ((a,b):complex,(c,d):complex) = (a+c,b+d)
  fun multiply ((a,b):complex,(c,d):complex) = (a*c-b*d,a*d+b*c)
  fun power (x, exponent) =
    let fun f (x,n) = if n mod 2=0 then f (multiply(x,x), n div 2)
          else if n=1 then x else g (multiply(x,x), (n-1) div 2, x)
        and g (x,n,z) = if n mod 2=0 then g (multiply(x,x), n div 2, z)
          else if n=1 then multiply(x,z)
          else g (multiply(x,x), (n-1) div 2, multiply(x,z))
    in if exponent=0 then (1.0,0.0) else f (x,exponent) end
  fun term n =
    let val angle = (2.0*Math.pi) / Real.fromInt n
    in power ((1.0*Math.cos angle,1.0*Math.sin angle),n) end
  fun consume (n, value as (r,i)) =
    let val b = 16.0 * epsilon * Real.fromInt n
    in if Real.isFinite r andalso Real.isFinite i andalso
      Real.abs (r-1.0) <= b andalso Real.abs i <= b then value
      else raise Fail "complex root power differs" end
  fun validate n (r,i) =
    let val bound = 32.0 * epsilon * Real.fromInt n * Real.fromInt n
    in if Real.isFinite r andalso Real.isFinite i andalso
      Real.abs (r-Real.fromInt n) <= bound andalso Real.abs i <= bound
      andalso Real.round r = n then Int.toString (Real.round r)
      else raise Fail "complex sum differs" end
end

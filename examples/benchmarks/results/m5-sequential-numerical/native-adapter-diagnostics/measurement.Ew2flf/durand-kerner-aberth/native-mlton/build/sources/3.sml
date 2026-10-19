(* Durand-Kerner simultaneous updates with the source Aberth circle initialization. *)
structure BenchDurandKerner =
struct
  type complex=real*real
  val zero:complex=(0.0,0.0)
  fun add((a,b):complex,(c,d):complex)=(a+c,b+d)
  fun sub((a,b):complex,(c,d):complex)=(a-c,b-d)
  fun mul((a,b):complex,(c,d):complex)=(a*c-b*d,a*d+b*c)
  fun divide((a,b):complex,(c,d):complex)=
    if Real.abs c>=Real.abs d then
      let val r=d/c val denominator=c+r*d
      in ((a+r*b)/denominator,(b-r*a)/denominator)end
    else let val r=c/d val denominator=d+r*c
      in ((r*a+b)/denominator,(r*b-a)/denominator)end
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun foldLefti f initial array=
    let val acc=ref initial
        val _=for 0 (Array.length array-1)(fn i=>acc:=f i (!acc)(Array.sub(array,i)))
    in !acc end
  fun norm2((a,b):complex)=a*a+b*b
  fun exponential((a,b):complex)=
    let val magnitude=Math.exp a
    in(magnitude*Math.cos b,magnitude*Math.sin b)end
  fun initial radius (coefficients:complex array)=
    let val size=Array.length coefficients
        val _=if size<2 then raise Fail "roots need at least two coefficients"else()
        val degree=size-1
        val s=3.14159265358979/Real.fromInt degree
        val center=divide(Array.sub(coefficients,1),
          mul(Array.sub(coefficients,0),(~(Real.fromInt degree),0.0)))
    in Array.tabulate(degree,fn i=>
      let val angle=s*(2.0*Real.fromInt i+0.5)
      in add(center,mul((radius,0.0),exponential(0.0,angle)))end)end
  fun polynomial coefficients x =
    let fun loop i sum=if i=Array.length coefficients then sum
          else loop(i+1)(add(mul(sum,x),Array.sub(coefficients,i)))
    in loop 0 zero end
  fun allClose epsilon first second=
    let val size=Array.length first
        val _=if size=Array.length second then()else raise Fail "root vector length differs"
        fun loop i=if i<0 then true
          else norm2(sub(Array.sub(first,i),Array.sub(second,i)))<epsilon andalso loop(i-1)
    in loop(size-1)end
  fun rootsWith epsilon coefficients start =
    let val cn=Array.sub(coefficients,0)
        fun update old =
          let fun point i =
                let val zi=Array.sub(old,i)
                    val denominator=foldLefti(fn j=>fn acc=>fn zj=>
                      if i=j then acc else mul(acc,sub(zi,zj)))cn old
                in sub(zi,divide(polynomial coefficients zi,denominator))end
              val next=Array.tabulate(Array.length old,point)
          in if allClose epsilon old next then next else update next end
    in update start end
  fun roots coefficients=rootsWith 1.0E~6 coefficients(initial 1000.0 coefficients)
end

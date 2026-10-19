(* Sandmark numerical-analysis FFT: retain both complex products/butterfly. *)
structure BenchSandmarkFFT =
struct
  type complex = real * real
  fun add ((a,b):complex,(c,d):complex) = (a+c,b+d)
  fun sub ((a,b):complex,(c,d):complex) = (a-c,b-d)
  fun mul ((a,b):complex,(c,d):complex) = (a*c-b*d,a*d+b*c)
  fun for first last f = if first>last then () else
    (f first; for(first+1)last f)
  fun bits size =
    let fun loop count i = if i=1 then count
          else if i>0 andalso i mod 2=0 then loop(count+1)(i div 2)
          else raise Fail "FFT length must be a positive power of two"
    in loop 0 size end
  fun bitrev digits i =
    let fun loop acc 0 _ = acc
          | loop acc n i = loop(2*acc+i mod 2)(n-1)(i div 2)
    in loop 0 digits i end
  fun pow2 0 = 1 | pow2 n = 2*pow2(n-1)
  fun twiddles size =
    let val pi=3.14159265358979
        val c= ~2.0*pi/Real.fromInt size
    in Array.tabulate(size div 2,fn i =>
      let val phase=c*Real.fromInt i val magnitude=Math.exp 0.0
      in (magnitude*Math.cos phase,magnitude*Math.sin phase) end) end
  fun fft (x:complex array) =
    let val size=Array.length x val digits=bits size
        val w=twiddles size
        val y=Array.tabulate(size,fn i=>Array.sub(x,bitrev digits i))
        fun butterfly m n offset = for 0 (n div 2-1)(fn i=>
          let val j=offset+i val k=offset+i+n div 2
              val a=Array.sub(y,j) val b=Array.sub(y,k)
          in Array.update(y,j,add(a,mul(Array.sub(w,i*m),b)));
             Array.update(y,k,sub(a,mul(Array.sub(w,i*m),b))) end)
        val _=for 1 digits(fn nb=>
          let val n=pow2 nb val m=pow2(digits-nb)
          in for 0 (m-1)(fn i=>butterfly m n (n*i)) end)
    in y end
  (* Source convention returns the conjugate of a general inverse transform. *)
  fun ifft (x:complex array) =
    let val c=1.0/Real.fromInt(Array.length x)
    in fft(Array.tabulate(Array.length x,fn i=>
      let val (re,im)=Array.sub(x,i) in (c*re,~c*im) end)) end
  fun ramp size = Array.tabulate(size,fn i=>(Real.fromInt i,0.0))
  fun frequencyBound size =
    let val n=Real.fromInt size
    in 2.0E~14*Real.fromInt(bits size+1)*n*n end
  fun roundtripBound size =
    4.0E~14*Real.fromInt(bits size+1)*Real.fromInt size
  fun near bound (actual,expected) = Real.isFinite actual andalso
    Real.abs(actual-expected)<=bound
  fun frequency size k =
    let val n=Real.fromInt size
    in if k=0 then (n*(n-1.0)/2.0,0.0)
       else let val reflected=Int.min(k,size-k)
                val theta=Math.pi*Real.fromInt reflected/n
                val sign=if k<=size div 2 then 1.0 else ~1.0
            in (~n/2.0,sign*n/2.0*Math.cos theta/Math.sin theta) end end
  fun checkFrequencies size array =
    let val bound=frequencyBound size
        val _=if Array.length array=size then () else raise Fail "FFT frequency length differs"
    in for 0 (size-1)(fn k=>let val (re,im)=Array.sub(array,k)
          val (er,ei)=frequency size k
        in if near bound(re,er) andalso near bound(im,ei) then ()
           else raise Fail "FFT frequency differs" end) end
  fun checkRoundtrip size array =
    let val bound=roundtripBound size
        val _=if Array.length array=size then () else raise Fail "FFT result length differs"
    in for 0 (size-1)(fn k=>let val (re,im)=Array.sub(array,k)
        in if near bound(re,Real.fromInt k) andalso near bound(im,0.0) then ()
           else raise Fail "FFT roundtrip differs" end) end
  fun run size =
    let val x=ramp size val f=fft x
        val _=checkFrequencies size f
        val y=ifft f val _=checkRoundtrip size y
    in () end
end

structure FFTTests =
struct
  structure F=BenchSandmarkFFT
  val input=Array.fromList[(1.0,2.0),(3.0,~4.0),(~2.0,1.0),(0.5,3.0)]
  fun same bound ((a,b),(c,d)) = F.near bound(a,c) andalso F.near bound(b,d)
  fun arrays bound a b = Array.length a=Array.length b andalso
    List.all(fn i=>same bound(Array.sub(a,i),Array.sub(b,i)))
      (List.tabulate(Array.length a,fn i=>i))
  fun direct x =
    let val size=Array.length x
    in Array.tabulate(size,fn k=>
      let fun loop i sum = if i=size then sum else
        let val angle= ~2.0*Math.pi*Real.fromInt(k*i)/Real.fromInt size
        in loop(i+1)(F.add(sum,F.mul(Array.sub(x,i),(Math.cos angle,Math.sin angle)))) end
      in loop 0 (0.0,0.0) end) end
  fun rejects f = (f();false)handle Fail _=>true
  val _=T.check("sandmark-fft/complete-ramp",fn()=>
    (List.app F.run [1,2,16,1024];true))
  val _=T.check("sandmark-fft/complex-direct-dft",fn()=>arrays 1.0E~11 (F.fft input)(direct input))
  val _=T.check("sandmark-fft/source-inverse-convention",fn()=>
    arrays 1.0E~11 (F.ifft(F.fft input))
      (Array.tabulate(4,fn i=>let val(a,b)=Array.sub(input,i)in(a,~b)end)))
  val _=T.check("sandmark-fft/input-remains-unmodified",fn()=>
    let val saved=Array.tabulate(4,fn i=>Array.sub(input,i)) val _=F.fft input
    in arrays 0.0 input saved end)
  val _=T.check("sandmark-fft/bit-reversal",fn()=>
    F.bits 16=4 andalso List.map(F.bitrev 4)(List.tabulate(16,fn i=>i))=
      [0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15])
  val _=T.check("sandmark-fft/reject-nonpower-lengths",fn()=>
    rejects(fn()=>ignore(F.bits 0))andalso rejects(fn()=>ignore(F.bits 3)))
  val _=T.check("sandmark-fft/reject-identity-transform",fn()=>
    rejects(fn()=>F.checkFrequencies 16 (F.ramp 16)))
  val _=T.check("sandmark-fft/reject-forward-perturbation",fn()=>
    let val f=F.fft(F.ramp 16) val(a,b)=Array.sub(f,0)
        val _=Array.update(f,0,(a+2.0*F.frequencyBound 16,b))
    in rejects(fn()=>F.checkFrequencies 16 f)end)
  val _=T.check("sandmark-fft/reject-roundtrip-perturbation",fn()=>
    let val f=F.ramp 16 val _=Array.update(f,0,(2.0*F.roundtripBound 16,0.0))
    in rejects(fn()=>F.checkRoundtrip 16 f)end)
  val _=T.check("sandmark-fft/error-boundary",fn()=>
    let val b=F.frequencyBound 16
    in F.near b(b,0.0)andalso not(F.near b(2.0*b,0.0))end)
  val _=T.check("sandmark-fft/reject-infinite-result",fn()=>not(F.near 1.0(Real.posInf,0.0)))
  val _=T.check("sandmark-fft/reject-incomplete-array",fn()=>
    rejects(fn()=>F.checkRoundtrip 16(F.ramp 8))andalso
    rejects(fn()=>F.checkFrequencies 16(F.ramp 8)))
end

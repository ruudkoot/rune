from pathlib import Path
p=Path(__file__).resolve().parent
body=r'''
structure KernelPOLICY=BenchFFT2Fn(BenchPOLICY)
structure DriverPOLICY=BenchFFT2DriverFn(KernelPOLICY)
structure TestsPOLICY=struct
 structure K=KernelPOLICY
 structure Driver=DriverPOLICY
 structure D=BenchPOLICY
 structure L=BenchLazy
 structure S=BenchStream
 val base="BASE/"
 fun label s="fft2/POLICY/"^s
 fun read path=Driver.read(base^path)
 fun reals row=List.map Driver.real(String.tokens Char.isSpace row)
 fun rows text=List.map reals(String.tokens(fn c=>c= #"\n")text)
 fun components value=[D.force(K.realPart value),D.force(K.imagPart value)]
 fun values stream=List.rev(S.foldl(fn(z,values)=>components z::values)[]stream)
 fun close(a,b)=BenchInput.closeReal(a,b,1.0E~11,1.0E~11)
 fun check n=
   let val signal=S.fromList(List.tabulate(n,fn i=>K.C(K.number(Real.fromInt i),K.zero)))
       val xs=S.fromList(List.tabulate(n,fn i=>K.number(Real.fromInt i)))
       fun vector(name,transform)=T.check(label(name^"-"^Int.toString n),fn()=>
         ListPair.allEq(fn(a,b)=>ListPair.allEq close(a,b))
           (values(transform signal),rows(read(Int.toString n^"."^name))))
       val _=List.app vector[("fft",K.fft),("fftinv",K.fftinv),("dft",K.dft),
         ("dftinv",K.dftinv),("sft",K.sft)]
       val _=T.check(label("sct-"^Int.toString n),fn()=>
         ListPair.allEq close(List.rev(S.foldl(fn(x,ys)=>D.force x::ys)[](K.sct xs)),
           List.map hd(rows(read(Int.toString n^".sct")))))
   in()end
 val _=List.app check[2,3,4,5,8,16]
 val _=List.app(fn(profile,baseValue)=>T.check(label("primary-first-sample-"^profile),fn()=>
   Driver.run["1",baseValue,base^profile^".reference"]="1:1"))
   [("smoke","70"),("normal","245"),("large","490")]
 val _=List.app(fn row=>case reals row of[x,y,wanted]=>
   T.check(label("scaled-magnitude-"^row),fn()=>
     let val result=D.force(K.magnitude(K.C(K.number x,K.number y)))
     in if Real.==(wanted,0.0)then Real.==(result,0.0)
       else BenchInput.closeReal(result,wanted,0.0,1.0E~12)end)
   |_=>raise Fail "bad magnitude reference")
   (String.tokens(fn c=>c= #"\n")(read"magnitude.reference"))
 val _=T.check(label"half-step-enumeration-first-length",fn()=>K.length(K.ramp(70.0+1.0/15.0))=70)
 val _=T.check(label"half-step-enumeration-eighth-length",fn()=>K.length(K.ramp(70.0+8.0/15.0))=71)
 val _=T.check(label"half-step-enumeration-last-length",fn()=>K.length(K.ramp(70.0+100.0/15.0))=77)
 val _=T.check(label"global-prime-prefix",fn()=>S.take 8 K.primes=[2,3,5,7,11,13,17,19])
 val _=T.check(label"repeated-prime-factors",fn()=>S.take 10(K.factors 245)=[5,7,7])
 val _=T.check(label"prime-input-factor",fn()=>S.take 10(K.factors 251)=[251])
 val _=T.check(label"every-zero-retains-first-element",fn()=>S.take 4(K.every 0(S.fromList[3,4,5]))=[3,3,3,3])
 val _=T.check(label"cyclic-list-prefix",fn()=>S.take 7(K.cycle(S.fromList[1,2,3]))=[1,2,3,1,2,3,1])
 val _=T.check(label"finite-repetition",fn()=>S.take 8(K.repeat 2(S.fromList[1,2,3]))=[1,2,3,1,2,3])
 val _=T.check(label"nonbinary-fast-error-is-source-result",fn()=>
   let val[a,_,_]=K.run(70.0+1.0/15.0)in a>200.0 end)
 val _=T.check(label"quoted-string-roundtrip",fn()=>
   let val text="result1 = 1.0\n\"quote\"\\tail"
   in Driver.unquote(Driver.quote text)=text end)
 val wanted=hd(Driver.reference(read"normal.reference"))
 val _=T.check(label"baseline-numerical-triple-accepted",fn()=>Driver.valid 245 wanted wanted)
 fun update index values=ListPair.mapEq(fn(i,x)=>if i=index then x+0.001 else x)
   (List.tabulate(3,fn i=>i),values)
 val _=List.app(fn i=>T.check(label("perturbed-metric-"^Int.toString i),fn()=>
   not(Driver.valid 245(update i wanted)wanted)))[0,1,2]
 val _=T.check(label"near-bound-zero-residual-accepted",fn()=>
   let val[(a,r),(b,_),(c,_)]=Driver.bounds 245
   in Driver.valid 245[0.0,b*0.25,c*0.25][0.0,0.0,0.0]end)
 val _=T.check(label"NaN-is-rejected",fn()=>not(Driver.valid 245[0.0,0.0/0.0,0.0][0.0,0.0,0.0]))
 val _=T.check(label"infinity-is-rejected",fn()=>not(Driver.valid 245[1.0/0.0,0.0,0.0][0.0,0.0,0.0]))
 val _=T.check(label"short-result-triple-is-rejected",fn()=>not(Driver.valid 245[0.0,0.0][0.0,0.0,0.0]))
 val _=T.check(label"zero-samples",fn()=>Driver.run["0","245",base^"normal.reference"]="0:0")
 val _=T.check(label"malformed-reference-is-rejected",fn()=>((Driver.reference"1 2\n";false)handle Fail _=>true))
end
'''
s=''.join(body.replace('POLICY',policy).replace('BASE',str(p))for policy in ['Need','Strict'])
s+=r'''
structure DemandTests=struct
 structure K=KernelNeed
 structure S=BenchStream
 val _=T.check("fft2/demand/real-field-skips-imaginary-payload",fn()=>
   let val imaginary=BenchNeed.delay(fn()=>raise Fail "unused imaginary field")
       val value=K.C(K.number 3.0,imaginary)
   in Real.==(BenchNeed.force(K.realPart value),3.0)end)
 val _=T.check("fft2/demand/norm-consumers-share-component-thunks",fn()=>
   let val calls=ref 0
       val r=BenchNeed.delay(fn()=>(calls:= !calls+1;3.0))
       val value=K.C(r,K.number 4.0)
       val a=BenchNeed.force(K.magnitude value)val b=BenchNeed.force(K.realPart value)
   in Real.==(a,5.0)andalso Real.==(b,3.0)andalso !calls=1 end)
end
'''
(p/'tests.sml').write_text('(* Fourier sources: Rex Page, Amoco Production Research, September 1992. *)\n'+s)

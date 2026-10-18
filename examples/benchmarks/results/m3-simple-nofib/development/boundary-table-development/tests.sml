functor SimpleNofibTestsFn(val strict:bool val label:string)=
struct
 structure C=BenchSimpleCheckFn(val strict=strict val report=true val gridMax=8)
 structure K=C.K
 structure A=K.A
 structure L=BenchLazy
 structure R=BenchSimpleReference
 fun test name f=T.check("simple-nofib/"^label^"/"^name,f)
 fun fails name f=T.raises("simple-nofib/"^label^"/"^name,fn Fail _=>true|_=>false,f)
 fun original steps=
   let val(total,state)=K.compute steps
       val(_,wanted)=C.parseHeader"SIMPLE-TOTALS-V2"13(R.read("totals-8-"^Int.toString steps^".reference"))
   in test("complete-state/"^Int.toString steps)(fn()=>
        C.verifyState steps state(R.read("state-8-"^Int.toString steps^".reference"))=(if steps=0 then 772 else 708));
      test("totals/"^Int.toString steps)(fn()=>(R.totals wanted total;true))
   end
 val _=List.app original[0,1,2,5]
 val touches=ref 0
 val array=A.make((2,3),(3,5))(fn(i,j)=>(touches:= !touches+1;Real.fromInt(i*10+j)))
 val _=test"finite-policy"(fn()=> !touches=(if strict then 6 else 0))
 val _=test"cell-sharing"(fn()=>Real.==(A.sub array(2,4),24.0)andalso
     Real.==(A.sub array(2,4),24.0)andalso !touches=(if strict then 6 else 1))
 val _=test"row-major-inclusive-bounds"(fn()=>A.positions(A.bounds array)=[(2,3),(2,4),(2,5),(3,3),(3,4),(3,5)])
 val _=T.raises("simple-nofib/"^label^"/array-bounds",fn Subscript=>true|_=>false,fn()=>A.sub array(1,4))
 val triangular=A.recursive((1,1),(3,2))(fn self=>fn(i,j)=>if i=1 then Real.fromInt j else A.sub self(i-1,j)+1.0)
 val _=test"recursive-array-knot"(fn()=>Real.==(A.sub triangular(3,2),4.0))
 val aPair=A.recursivePair((1,1),(2,1))(fn(a,b)=>fn(i,j)=>
   if i=1 then(L.delay(fn()=>1.0),L.delay(fn()=>2.0))
   else(L.delay(fn()=>A.sub b(1,j)+1.0),L.delay(fn()=>A.sub a(1,j)+2.0)))
 val _=test"mutual-pair-knot"(fn()=>Real.==(A.sub(#1 aPair)(2,1),3.0)andalso Real.==(A.sub(#2 aPair)(2,1),3.0))
 val _=test"polynomial-pressure"(fn()=>R.close 0.93772(K.zonalPressure 1.4 10.0))
 val _=test"polynomial-energy"(fn()=>R.close 1.0(K.zonalEnergy 1.4 10.0))
 val _=test"source-newton-positive-residual"(fn()=>Real.==(R.decode(hd(R.read"helpers.reference")),K.newton(fn x=>x-2.0)3.0))
 val _=test"source-newton-negative-stops"(fn()=>Real.==(K.newton(fn _=> ~1.0)7.0,7.0))
 val _=test"source-newton-small-denominator-stops"(fn()=>Real.==(K.newton(fn _=>2.0)7.0,7.0))
 val _=test"boundary-classes"(fn()=>List.map K.boundaryCode[(2,2),(2,4),(9,4),(4,9),(4,2),(9,9)]=[4,1,2,1,1,4])
 val _=test"report-driver"(fn()=>C.run["1","state-8-1.reference"]="1:708")
 val _=fails"wrong-totals"(fn()=>let val(t,_)=K.compute 1
    val(_,wanted)=C.parseHeader"SIMPLE-TOTALS-V2"13(R.read"wrong-totals.reference")
    in R.totals wanted t end)
 val _=fails"wrong-state-step"(fn()=>let val(_,s)=K.compute 0
    in C.verifyState 1 s(R.read"state-8-0.reference")end)
 val _=fails"wrong-state-shape"(fn()=>let val(_,s)=K.compute 1
    in C.verifyState 1 s["SIMPLE-STATE","8","1","11","u","1","1","1","1","1"]end)
 val _=fails"too-many-steps"(fn()=>C.run["101","state-8-1.reference"])
 val _=fails"negative-steps"(fn()=>C.run["~1","state-8-1.reference"])
 val _=fails"missing-arguments"(fn()=>C.run[])
 val _=test"absolute-bound-accepts"(fn()=>R.close 0.0 0.0000000000005)
 val _=test"absolute-bound-rejects"(fn()=>not(R.close 0.0 0.000000000002))
 val _=test"relative-bound-accepts"(fn()=>R.close 1000000.0(1000000.0+0.000005))
 val _=test"relative-bound-rejects"(fn()=>not(R.close 1000000.0(1000000.0+0.00002)))
 val _=test"nan-rejected"(fn()=>not(R.close 0.0 (0.0/0.0)))
 val _=test"infinity-rejected"(fn()=>not(R.close 0.0 Real.posInf))
 val _=fails"malformed-bits"(fn()=>R.decode"not-a-real")
 val _=fails"nonhex-bits"(fn()=>R.decode"ZZZZZZZZZZZZZZZZ")
 val _=test"conditioned-sum-accepts"(fn()=>(R.aggregate 0.0 10000 1000000.0 0.000001;true))
 val _=fails"conditioned-sum-rejects"(fn()=>R.aggregate 0.0 10000 1000000.0(2.0*R.aggregateBound 10000 1000000.0))
 val _=fails"conditioned-sum-rejects-nan"(fn()=>R.aggregate 0.0 10000 1000000.0(0.0/0.0))
 val _=fails"conditioned-sum-rejects-infinity"(fn()=>R.aggregate 0.0 10000 1000000.0 Real.posInf)
 val _=fails"invalid-sum-count"(fn()=>R.aggregateBound 0 1.0)
 val _=fails"negative-sum-scale"(fn()=>R.aggregateBound 10000(~1.0))
 val _=fails"nonfinite-sum-scale"(fn()=>R.aggregateBound 10000 Real.posInf)
 val _=fails"cell-bound-remains-strict"(fn()=>R.scalar 0.0 0.000000000002)
 val _=test"binary64-decoder"(fn()=>Real.==(R.decode"3ff0000000000000",1.0))
 val _=if strict then()else
   let val hits=ref 0
       val(a,b)=A.pair((1,1),(1,1))(fn _=>(L.delay(fn()=>3.0),L.delay(fn()=>(hits:= !hits+1;raise Fail"unused"))))
   in test"unused-pair-projection"(fn()=>Real.==(A.sub a(1,1),3.0)andalso !hits=0);
      fails"poison-projection-demanded"(fn()=>A.sub b(1,1));
      fails"poison-exception-memoized"(fn()=>A.sub b(1,1));
      test"poison-evaluated-once"(fn()=> !hits=1)
   end
end
structure SimpleNeedTests=SimpleNofibTestsFn(val strict=false val label="need")
structure SimpleStrictTests=SimpleNofibTestsFn(val strict=true val label="strict")

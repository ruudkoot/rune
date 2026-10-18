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
 fun verifyTable table path=
   let val tokens=R.read path
       val(a,b,c,d,rest)=case tokens of" NBC"::_=>raise Fail"bad table header"
        |"NBC"::a::b::c::d::rest=>(C.integer a,C.integer b,C.integer c,C.integer d,rest)
        |_=>raise Fail"missing boundary table"
       val _=if A.bounds table=((a,b),(c,d))then()else raise Fail"boundary shape"
       fun cells [] rest=rest
         |cells((i,j)::positions)(is::js::value::rest)=
           if i<>C.integer is orelse j<>C.integer js then raise Fail"boundary coordinate"
           else if value="U"then
              if ((ignore(A.sub table(i,j));false)handle Fail _=>true)
              then cells positions rest else raise Fail"source undefined cell became defined"
           else if A.sub table(i,j)=C.integer value then cells positions rest
                else raise Fail"boundary code differs"
         |cells _ _=raise Fail"truncated boundary table"
       val rest=cells(A.positions(A.bounds table))rest
       val tables=[("pbb",K.pbb),("pb",K.pb),("qb",K.qb),("rho",K.rhoTable),("theta",K.thetaTable)]
       fun scalars [] []=true
         |scalars((name,values)::tables)(label::count::rest)=
           let val n=C.integer count
               val _=if name=label andalso Vector.length values=n then()else raise Fail"scalar table shape"
               val fields=List.take(rest,n)
               val _=List.app(fn(i,field)=>R.scalar(R.decode field)(Vector.sub(values,i)))
                    (ListPair.zip(List.tabulate(n,fn i=>i),fields))
           in scalars tables(List.drop(rest,n))end
         |scalars _ _=raise Fail"scalar table tail"
   in case rest of"TABLES"::rest=>scalars tables rest|_=>raise Fail"missing scalar tables"end
 val _=test"complete-source-boundary-table-8"(fn()=>verifyTable K.nbc"boundary-8.reference")
 val _=test"complete-source-boundary-table-100"(fn()=>verifyTable(K.boundaryTable 100)"boundary-100.reference")
 val _=fails"source-undefined-interior"(fn()=>K.boundaryCode(3,3))
 exception TableDemanded
 val A.Store(_,boundaryCells)=L.force K.nbc
 val boundaryCell=Vector.sub(boundaryCells,1)
 val savedBoundary= !boundaryCell
 val _=boundaryCell:=L.Failed TableDemanded
 val _=T.raises("simple-nofib/"^label^"/pressure-reads-boundary-table",
   fn TableDemanded=>true|_=>false,fn()=>
     let val(_,_,_,_,_,pressure,_,_,_,_,_)=K.initial()
     in A.sub pressure(2,3)end)
 val _=boundaryCell:=savedBoundary
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

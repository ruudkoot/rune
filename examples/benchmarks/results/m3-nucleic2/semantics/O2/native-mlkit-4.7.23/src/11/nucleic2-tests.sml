functor Nucleic2TestsFn(structure D:BENCH_SUSPEND val shared:bool val label:string)=struct
 structure K=BenchNucleic2Fn(structure D=D val shared=shared)
 structure O=BenchNucleic2Oracle
 structure Precision=BenchNucleic2PrecisionTestsFn(structure K=K val label=label)
 fun test name f=T.check("nucleic2/"^label^"/"^name,f)
 fun exact(a,b)=Real.==(a,b)andalso Real.signBit a=Real.signBit b
 fun matrix t=let val K.Tfo(a,b,c,d,e,f,g,h,i,j,k,l)=D.force t
   in List.map D.force[a,b,c,d,e,f,g,h,i,j,k,l]end
 fun decompose n=
   let val K.Nuc(t0,t1,t2,t3,p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,x)=D.force n
       val(kind,extra)=case D.force x of K.A(a,b,c,d,e,f,g,h)=>(0,[a,b,c,d,e,f,g,h])
         |K.C(a,b,c,d,e,f)=>(1,[a,b,c,d,e,f])
         |K.G(a,b,c,d,e,f,g,h,i)=>(2,[a,b,c,d,e,f,g,h,i])|K.U(a,b,c,d,e)=>(3,[a,b,c,d,e])
   in(kind,List.concat(List.map matrix[t0,t1,t2,t3]),
      [p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24]@extra)end
 fun matrices stream=case O.words stream of"MATRICES"::values=>List.map(O.decode o O.word)values
   |_=>raise Fail"source oracle matrix row"
 fun exactPoints [] []=true
   |exactPoints(p::ps)((x,y,z)::rest)=
      let val K.Pt(a,b,c)=D.force p
      in exact(D.force a,x)andalso exact(D.force b,y)andalso exact(D.force c,z)andalso exactPoints ps rest end
   |exactPoints _ _=false
 val database=TextIO.openIn"database.reference"
 val dbCount=case O.words database of["DATABASE",n]=>O.integer n|_=>raise Fail"database oracle header"
 fun constant(name,nuc)=
   let val(expectedName,expectedKind,count)=case O.words database of["CONFORMATION",n,k,c]=>(n,O.integer k,O.integer c)
         |_=>raise Fail"database conformation header"
       val expectedMatrices=matrices database
       val expectedPoints=O.points database count
   in test("database-"^name)(fn()=>
       let val(kind,values,points)=decompose nuc
       in name=expectedName andalso kind=expectedKind andalso List.length values=48 andalso
          List.length expectedMatrices=48 andalso ListPair.allEq exact(values,expectedMatrices)andalso
          exactPoints points expectedPoints end)end
 val conformations=[("rA",K.rA),("rA01",K.rA01),("rA02",K.rA02),("rA03",K.rA03),("rA04",K.rA04),("rA05",K.rA05),("rA06",K.rA06),("rA07",K.rA07),("rA08",K.rA08),("rA09",K.rA09),("rA10",K.rA10),("rC",K.rC),("rC01",K.rC01),("rC02",K.rC02),("rC03",K.rC03),("rC04",K.rC04),("rC05",K.rC05),("rC06",K.rC06),("rC07",K.rC07),("rC08",K.rC08),("rC09",K.rC09),("rC10",K.rC10),("rG",K.rG),("rG01",K.rG01),("rG02",K.rG02),("rG03",K.rG03),("rG04",K.rG04),("rG05",K.rG05),("rG06",K.rG06),("rG07",K.rG07),("rG08",K.rG08),("rG09",K.rG09),("rG10",K.rG10),("rG'",K.rGPrime),("rU",K.rU),("rU01",K.rU01),("rU02",K.rU02),("rU03",K.rU03),("rU04",K.rU04),("rU05",K.rU05),("rU06",K.rU06),("rU07",K.rU07),("rU08",K.rU08),("rU09",K.rU09),("rU10",K.rU10),("rU'",K.rUPrime)]
 val _=test"database-count"(fn()=>List.length conformations=dbCount andalso dbCount=46)
 val _=List.app constant conformations
 val _=test"database-eof"(fn()=>TextIO.endOfStream database)
 val _=TextIO.closeIn database
 val stream=TextIO.openIn"full.reference"
 val(numSolutions,expectedMaximum)=case O.words stream of["NUCLEIC2-V1",n,w]=>(O.integer n,O.decode(O.word w))
   |_=>raise Fail"full source oracle header"
 val checkedCoordinates=ref 0 val checkedConformations=ref 0
 fun points variable actual expected=case(D.force actual,expected)of(K.F.Nil,[])=>true
   |(K.F.Cons(p,rest),(x,y,z)::tail)=>
      let val K.Pt(a,b,c)=D.force(K.absolute_pos variable p)
          val correct=O.coordinate(D.force a,x)andalso O.coordinate(D.force b,y)andalso O.coordinate(D.force c,z)
          val _=checkedCoordinates:= !checkedCoordinates+3
          val remaining=points variable rest tail
      in correct andalso remaining end
   |_=>false
 fun variable solutionIndex value=
   let val(id,kind,count)=case O.words stream of["VARIABLE",i,k,n]=>(O.integer i,O.integer k,O.integer n)
         |_=>raise Fail"source oracle variable"
       val expectedMatrices=matrices stream
       val expectedPoints=O.points stream count
   in test("solution-"^Int.toString solutionIndex^"/variable-"^Int.toString id)(fn()=>
       let val K.Var(actualId,_,nuc)=D.force value
           val(actualKind,values,_)=decompose nuc
           val sameConformation=actualId=id andalso actualKind=kind andalso List.length values=48 andalso
              List.length expectedMatrices=48 andalso ListPair.allEq exact(values,expectedMatrices)
           val correct=points value(K.list_of_atoms nuc)expectedPoints
           val _=checkedConformations:= !checkedConformations+1
       in sameConformation andalso correct end)end
 fun solution index values=
   let val count=case O.words stream of["SOLUTION",n]=>O.integer n|_=>raise Fail"source oracle solution"
       fun loop i values=case D.force values of K.F.Nil=>test("solution-"^Int.toString index^"/length")(fn()=>i=count)
         |K.F.Cons(value,rest)=>(variable index value;loop(i+1)rest)
   in loop 0 values end
 val total=Array.array(3,0)val passed=Array.array(3,0)
 fun add array i=Array.update(array,i,Array.sub(array,i)+1)
 fun predicate v partial=
   let val K.Var(i,_,_)=D.force v val pass=K.pseudoknot_constraint v partial
       val group=if i=18 then 1 else if i=6 then 2 else 0
       val _=add total 0 val _=if pass then add passed 0 else()
       val _=if group=0 then()else(add total group;if pass then add passed group else())
   in pass end
 val solutions=K.search(K.F.empty())K.pseudoknot_domains predicate
 fun loop i values=case D.force values of K.F.Nil=>test"solution-count"(fn()=>i=numSolutions andalso i=50)
   |K.F.Cons(value,rest)=>(solution i value;loop(i+1)rest)
 val _=loop 0 solutions
 val _=test"full-oracle-eof"(fn()=>TextIO.endOfStream stream)
 val _=TextIO.closeIn stream
 val _=test"complete-conformation-coverage"(fn()=> !checkedConformations=1150)
 val _=test"complete-coordinate-coverage"(fn()=> !checkedCoordinates=109800)
 val _=test"maximum"(fn()=>let val actual=D.force(K.most_distant_atom solutions)
   in Real.isFinite actual andalso Real.abs(actual-expectedMaximum)<=0.000001*Real.abs expectedMaximum end)
 val _=List.app(fn(i,n,p)=>test("search-work-"^Int.toString i)(fn()=>Array.sub(total,i)=n andalso Array.sub(passed,i)=p))
   [(0,38496,5596),(1,27000,50),(2,6000,50)]
 val _=test"coordinate-fault-controls"(fn()=>
   List.all(fn expected=>let val bound=O.absolute+O.relative*Real.abs expected
     in O.coordinate(expected,expected)andalso
        not(O.coordinate(K.R.round(expected+4.0*bound),expected))andalso
        not(O.coordinate(K.R.round(expected-4.0*bound),expected))end)[0.0,~1.0,1.0,33.7975921630859375])
 val _=test"coordinate-nonfinite-rejection"(fn()=>not(O.coordinate(1.0/0.0,0.0))andalso not(O.coordinate(0.0/0.0,0.0)))
end
structure NeedNucleic2Tests=Nucleic2TestsFn(structure D=BenchNeed val shared=false val label="on-demand-need")
structure StrictNucleic2Tests=Nucleic2TestsFn(structure D=BenchStrict val shared=false val label="on-demand-strict")
structure NeedSharedNucleic2Tests=Nucleic2TestsFn(structure D=BenchNeed val shared=true val label="shared-need")
structure StrictSharedNucleic2Tests=Nucleic2TestsFn(structure D=BenchStrict val shared=true val label="shared-strict")

structure AuditNeed=struct
 type 'a t='a BenchLazy.delay
 val hits=ref 0
 fun delay f=BenchLazy.delay(fn()=>(hits:= !hits+1;f()))
 val force=BenchLazy.force
end
functor SharingProbeFn(val shared:bool)=struct
 structure D=AuditNeed
 structure K=BenchNucleic2Fn(structure D=D val shared=shared)
 val variable=K.mk_var 77 K.wc_tfo K.rA
 fun query()=let val K.Pt(x,_,_)=D.force(K.atom_pos K.nuc_P variable)in D.force x end
 val hitsBefore= !D.hits
 val first=query()
 val firstCost= !D.hits-hitsBefore
 val hitsBefore= !D.hits
 val second=query()
 val secondCost= !D.hits-hitsBefore
 val hitsBefore= !D.hits
 val third=query()
 val thirdCost= !D.hits-hitsBefore
 val _=T.check("nucleic2/sharing-"^(if shared then"placed"else"on-demand"),fn()=>
   Real.==(first,second)andalso Real.==(second,third)andalso secondCost=thirdCost)
end
structure OnDemandSharing=SharingProbeFn(val shared=false)
structure PlacedSharing=SharingProbeFn(val shared=true)
val _=T.check("nucleic2/shared-coordinates-avoid-repeated-transform",
 fn()=>OnDemandSharing.secondCost>PlacedSharing.secondCost)
structure UnusedPointProbe=struct
 structure D=BenchNeed
 structure K=BenchNucleic2Fn(structure D=D val shared=true)
 exception Demanded
 val K.Nuc(t0,t1,t2,t3,p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,x)=D.force K.rA
 val bad=D.delay(fn()=>K.Nuc(t0,t1,t2,t3,p0,D.delay(fn()=>raise Demanded),p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,x))
 val variable=K.mk_var 77 K.tfo_id bad
 val K.Pt(px,_,_)=D.force(K.atom_pos K.nuc_P variable)
 val _=T.check("nucleic2/shared-placement-skips-unused-atom",fn()=>Real.==(D.force px,2.8929998874664307))
 val _=T.raises("nucleic2/poison-atom-demand-control",fn Demanded=>true|_=>false,
   fn()=>D.force(K.atom_pos(fn n=>
      let val K.Nuc(_,_,_,_,_,p1,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in p1 end)variable))
end

structure Nucleic2DriverTests=struct
 val calls=ref 0
 structure Counting=BenchNucleic2CheckFn(struct
  fun compute _=(calls:= !calls+1;33.7975921630859375)
 end)
 val _=T.check("nucleic2/driver-source-normal-count",fn()=>Counting.run["25"]="25"andalso !calls=25)
 structure Poison=BenchNucleic2CheckFn(struct fun compute _=raise Fail"unexpected search"end)
 val _=T.check("nucleic2/nonpositive-repetition-no-op",fn()=>Poison.run["0"]="0"andalso Poison.run["-1"]="0")
 structure Perturbed=BenchNucleic2CheckFn(struct
  fun compute _=33.7975921630859375*(1.0+0.000004)
 end)
 val _=T.raises("nucleic2/perturbed-maximum-rejected",
   fn Fail message=>message="incorrect result: nucleic2 maximum atom distance"|_=>false,
   fn()=>Perturbed.run["1"])
 val _=T.check("nucleic2/nonfinite-maximum-rejected",
   fn()=>not(Counting.valid(0.0/0.0))andalso not(Counting.valid(1.0/0.0)))
end

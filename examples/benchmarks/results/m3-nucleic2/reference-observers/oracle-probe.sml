functor OracleProbeFn(structure D:BENCH_SUSPEND val shared:bool val label:string)=struct
 structure K=BenchNucleic2Fn(structure D=D val shared=shared)
 structure O=BenchNucleic2Oracle
 val stream=TextIO.openIn"tests/out/benchmarks/nucleic2-originals/full.reference"
 val(numSolutions,expectedMaximum)=case O.words stream of["NUCLEIC2-V1",n,w]=>(O.integer n,O.decode(O.word w))
   |_=>raise Fail"oracle header"
 fun matrix t=let val K.Tfo(a,b,c,d,e,f,g,h,i,j,k,l)=D.force t
   in List.map D.force[a,b,c,d,e,f,g,h,i,j,k,l]end
 fun conformation n=
   let val K.Nuc(t0,t1,t2,t3,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,x)=D.force n
       val kind=case D.force x of K.A _=>0|K.C _=>1|K.G _=>2|K.U _=>3
   in(kind,List.concat(List.map matrix[t0,t1,t2,t3]))end
 val checkedCoordinates=ref 0 val checkedConformations=ref 0
 fun points variable actual expected=case(D.force actual,expected)of(K.F.Nil,[])=>true
   |(K.F.Cons(p,rest),(x,y,z)::tail)=>
      let val K.Pt(a,b,c)=D.force(K.absolute_pos variable p)
          val correct=O.coordinate(D.force a,x)andalso O.coordinate(D.force b,y)andalso O.coordinate(D.force c,z)
          val _=checkedCoordinates:= !checkedCoordinates+3
          val remaining=points variable rest tail
      in correct andalso remaining end
   |_=>false
 fun variable value=
   let val(id,kind,n)=case O.words stream of["VARIABLE",i,k,n]=>(O.integer i,O.integer k,O.integer n)
         |_=>raise Fail"oracle variable"
       val expectedMatrices=case O.words stream of"MATRICES"::values=>List.map(O.decode o O.word)values
         |_=>raise Fail"oracle matrices"
       val expectedPoints=O.points stream n
       val K.Var(actualId,_,nuc)=D.force value
       val(actualKind,matrices)=conformation nuc
       val exact=actualId=id andalso actualKind=kind andalso List.length matrices=48 andalso
          List.length expectedMatrices=48 andalso ListPair.allEq Real.==(matrices,expectedMatrices)
       val correct=points value(K.list_of_atoms nuc)expectedPoints
       val _=checkedConformations:= !checkedConformations+1
   in if exact andalso correct then()else raise Fail("incorrect conformation or coordinates "^Int.toString id)end
 fun solution values=
   let val count=case O.words stream of["SOLUTION",n]=>O.integer n|_=>raise Fail"oracle solution"
       fun loop i values=case D.force values of K.F.Nil=>if i=count then()else raise Fail"variable count"
         |K.F.Cons(value,rest)=>(variable value;loop(i+1)rest)
   in loop 0 values end
 val solutions=K.pseudoknot"1"
 fun loop i values=case D.force values of K.F.Nil=>if i=numSolutions then()else raise Fail"solution count"
   |K.F.Cons(value,rest)=>(solution value;loop(i+1)rest)
 val _=loop 0 solutions
 val _=if TextIO.endOfStream stream then()else raise Fail"trailing source oracle"
 val _=TextIO.closeIn stream
 val maximum=D.force(K.most_distant_atom solutions)
 val _=if Real.abs(maximum-expectedMaximum)<=0.000001*Real.abs expectedMaximum then()else raise Fail"maximum"
 val _=print("PASS "^label^" "^Int.toString(!checkedConformations)^" exact conformations "^Int.toString(!checkedCoordinates)^" coordinates\n")
end
structure NeedDefaultOracle=OracleProbeFn(structure D=BenchNeed val shared=false val label="on-demand-need")
structure StrictDefaultOracle=OracleProbeFn(structure D=BenchStrict val shared=false val label="on-demand-strict")
structure NeedSharedOracle=OracleProbeFn(structure D=BenchNeed val shared=true val label="shared-need")
structure StrictSharedOracle=OracleProbeFn(structure D=BenchStrict val shared=true val label="shared-strict")

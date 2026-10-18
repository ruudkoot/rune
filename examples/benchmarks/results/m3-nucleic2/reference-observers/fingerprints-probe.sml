functor SolutionsProbeFn(structure D:BENCH_SUSPEND val shared:bool val label:string)=struct
 structure K=BenchNucleic2Fn(structure D=D val shared=shared)
 structure W=Word32
 fun bits x=
   let val sign=if Real.signBit x then 0wx80000000:W.word else 0w0
       val y=Real.abs x
       val payload=if Real.==(y,0.0)then 0w0
         else let val{man,exp}=Real.toManExp y
              in W.orb(W.<<(W.fromInt(exp+126),0w23),
                  W.fromInt(Real.toInt IEEEReal.TO_NEAREST(man*16777216.0)-8388608))end
   in IntInf.toString(W.toLargeInt(W.orb(sign,payload)))end
 fun array xs="["^String.concatWith","xs^"]"
 fun point p=let val K.Pt(x,y,z)=D.force p in List.map(fn x=>bits(D.force x))[x,y,z]end
 fun matrix t=let val K.Tfo(a,b,c,d,e,f,g,h,i,j,k,l)=D.force t
   in List.map(fn x=>bits(D.force x))[a,b,c,d,e,f,g,h,i,j,k,l]end

 fun sequence emit values=
  let fun loop values=case D.force values of K.F.Nil=>[]
        |K.F.Cons(value,rest)=>emit value::loop rest
  in array(loop values)end
 fun fingerprint n=
  let val K.Nuc(t0,t1,t2,t3,p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,x)=D.force n
      val kind=case D.force x of K.A _=>0|K.C _=>1|K.G _=>2|K.U _=>3
  in array[Int.toString kind,array(List.concat(List.map matrix[t0,t1,t2,t3]))]end
 fun variable value=let val K.Var(i,_,n)=D.force value
   in array[Int.toString i,fingerprint n,sequence(fn p=>array(point(K.absolute_pos value p)))(K.list_of_atoms n)]end
 val solutions=K.pseudoknot"1"
 val count=K.F.length solutions
 val result=D.force(K.most_distant_atom solutions)
 val output=TextIO.openOut("tests/out/benchmarks/nucleic2-originals/fingerprints-"^label^".actual")
 fun loop values=case D.force values of K.F.Nil=>()
   |K.F.Cons(solution,rest)=>(TextIO.output(output,sequence variable solution^"\n");loop rest)
 val _=loop solutions
 val _=TextIO.closeOut output
 val _=print(label^" "^Int.toString count^" "^Real.toString result^" "^bits result^"\n")
end
structure NeedDemand=SolutionsProbeFn(structure D=BenchNeed val shared=false val label="on-demand-need")
structure StrictDemand=SolutionsProbeFn(structure D=BenchStrict val shared=false val label="on-demand-strict")
structure NeedShared=SolutionsProbeFn(structure D=BenchNeed val shared=true val label="shared-need")
structure StrictShared=SolutionsProbeFn(structure D=BenchStrict val shared=true val label="shared-strict")

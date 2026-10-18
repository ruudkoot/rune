functor DatabaseProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNucleic2Fn(structure D=D val shared=false)
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
 fun specific s=case D.force s of
  K.A(a,b,c,d,e,f,g,h)=>(0,[a,b,c,d,e,f,g,h])
 |K.C(a,b,c,d,e,f)=>(1,[a,b,c,d,e,f])
 |K.G(a,b,c,d,e,f,g,h,i)=>(2,[a,b,c,d,e,f,g,h,i])
 |K.U(a,b,c,d,e)=>(3,[a,b,c,d,e])
 fun nucleotide n=
  let val K.Nuc(t0,t1,t2,t3,p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,x)=D.force n
      val(tag,extra)=specific x
  in array[array(List.concat(List.map matrix[t0,t1,t2,t3])),
           array(List.concat(List.map point[p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24])),
           array[Int.toString tag,array(List.concat(List.map point extra))]]end
 val actual=array(List.map nucleotide[K.rA,K.rA01,K.rA02,K.rA03,K.rA04,K.rA05,K.rA06,K.rA07,K.rA08,K.rA09,K.rA10,K.rC,K.rC01,K.rC02,K.rC03,K.rC04,K.rC05,K.rC06,K.rC07,K.rC08,K.rC09,K.rC10,K.rG,K.rG01,K.rG02,K.rG03,K.rG04,K.rG05,K.rG06,K.rG07,K.rG08,K.rG09,K.rG10,K.rGPrime,K.rU,K.rU01,K.rU02,K.rU03,K.rU04,K.rU05,K.rU06,K.rU07,K.rU08,K.rU09,K.rU10,K.rUPrime])^"\n"
 val expected=let val f=TextIO.openIn"tests/out/benchmarks/nucleic2-originals/database-expected.json"
   in TextIO.inputAll f before TextIO.closeIn f end
 val _=if actual=expected then print("PASS "^label^" all database literal bits\n")
  else let val f=TextIO.openOut("tests/out/benchmarks/nucleic2-originals/database-"^label^".actual")
       in TextIO.output(f,actual);TextIO.closeOut f;raise Fail"database bits"end
end
structure NeedDatabase=DatabaseProbeFn(structure D=BenchNeed val label="need")
structure StrictDatabase=DatabaseProbeFn(structure D=BenchStrict val label="strict")

functor NumericTests(D:BENCH_SUSPEND)=struct
 structure K=BenchFluidFn(D)
 structure W=Word32
 fun decode word=let
     val exponent=W.toInt(W.andb(W.>>(word,0w23),0wxFF))
     val fraction=W.toInt(W.andb(word,0wx7FFFFF))
     val value=if exponent=0 then Real.fromManExp{man=Real.fromInt fraction,exp= ~149}
       else Real.fromManExp{man=Real.fromInt(8388608+fraction),exp=exponent-150}
   in if W.andb(word,0wx80000000)=0w0 then value else ~value end
 val input=TextIO.openIn"tests/out/benchmarks/nofib-fluid-originals/numeric.reference"
 val count=ref 0
 fun check name values=let
     val line=case TextIO.inputLine input of SOME line=>line|NONE=>raise Fail"numeric oracle EOF"
     val fields=String.tokens(fn c=>c= #"|"orelse c= #","orelse c= #"\n")line
     val expected=case fields of title::values=>if title=name then
        List.map(fn s=>decode(W.fromLargeInt(valOf(IntInf.fromString s))))values
          else raise Fail"numeric oracle label"|_=>raise Fail"numeric oracle row"
     val actual=K.F.toList values
     val _=ListPair.appEq(fn(a,b)=>if Real.==(a,b)andalso Real.signBit a=Real.signBit b
       then count:= !count+1 else raise Fail("binary32 mismatch "^name^" "^Real.toString a^" "^Real.toString b))(actual,expected)
   in print("PASS source binary32 "^name^"\n")end
 fun list values=K.F.fromList(List.map K.R.round values)
 fun triple(a,b,c)=(K.number a,K.number b,K.number c)
 val cases=[((1.0,2.0,3.0),(4.0,5.0,6.0)),((0.125,~0.25,0.5),(~0.75,1.25,2.5)),
    ((0.0,0.0,0.0),(0.0,0.0,0.0)),((~3.0,2.0,0.33333334),(0.14285715,~5.0,9.0))]
 fun functions funcs f=K.concat(K.map(fn value=>K.cell(f(D.force value)))(K.A.elements funcs))
 val _=check"mass-row-sums"(K.A.elements K.massRowSums)
 val _=check"mass-matrix"(K.concat(K.A.elements K.massMatrix))
 val _=check"subnormal"(K.singleton K.small)
 val _=List.app(fn(i,(a,b))=>let val a=triple a val b=triple b val suffix=Int.toString i
   in check("diffusion-"^suffix)(functions K.diffusionMatrix(fn f=>f(a,b)));
      check("gradient-a-"^suffix)(functions K.gradientMatrix(fn f=>f a));
      check("gradient-b-"^suffix)(functions K.transposedGradient(fn f=>f b));
      check("convection-"^suffix)(functions K.convectionMatrix(fn f=>
        f(a,b)(list[1.0,2.0,3.0,4.0,5.0,6.0],list[6.0,5.0,4.0,3.0,2.0,1.0])))end)
    (ListPair.zip(List.tabulate(4,fn i=>i),cases))
 val _=check"inner"(K.singleton(K.listInnerProd(list[1.0,2.0,3.0,4.0])(list[0.125,~0.25,0.5,~0.75])))
 val _=check"match"(K.singleton(K.listMatchProd(list[1.0,2.0,3.0,4.0])(list[0.125,~0.25,0.5,~0.75])))
 val _=check"tolerances"(K.F.cons(K.tolerance(list[1.0,2.0,3.0])(list[0.1,~0.2,0.3])false,
   K.F.cons(K.tolerance(list[0.1,0.2,0.3])(list[0.01,~0.02,0.03])false,
   K.F.cons(K.tolerance(list[0.1,0.2,0.3])(list[0.01,~0.02,0.03])true,K.F.empty()))))
 val _=TextIO.closeIn input
 val _=print("PASS all "^Int.toString(!count)^" source binary32 observations\n")
end
structure Need=NumericTests(BenchNeed)
structure Strict=NumericTests(BenchStrict)

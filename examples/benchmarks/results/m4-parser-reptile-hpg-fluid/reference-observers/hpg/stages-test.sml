structure K=BenchHpgFn(BenchNeed)
fun save path value=let val f=TextIO.openOut("tests/out/benchmarks/nofib-hpg-originals/"^path)
 in TextIO.output(f,K.string value);TextIO.closeOut f end
fun values xs=K.B.output(K.sep "\n"K.showValDecl xs)
val _=K.genTypes 6 4 8 4(K.genValues 10 6(K.allValues(fn vds=>fn env=>
  (save "initial-values.actual"(values vds);
   K.genExpressions 6(fn vnes=>K.allValues(fn final=>fn _=>
    (save "final-values.actual"(values final);
     save "expressions.actual"(K.B.output(K.sep "\n"(fn pair=>
      let val(name,e)=K.force pair in K.B.pieces[K.B.literal(K.force name),K.B.literal" = ",K.showExpression 0 e]end)vnes)))))env))))
    (K.makeEnv(9807,65,32975)(fn _=>()))

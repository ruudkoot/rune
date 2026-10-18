structure SymalgZeroProduct=struct
 structure N=BenchSymalgRealFn(BenchNeed)
 structure E=BenchSymalgRealFn(BenchStrict)
 val result=case CommandLine.arguments()of["need"]=>N.eval(N.multiply(N.fromInteger 0)(N.fromInteger 2))(~4)
   |["strict"]=>E.eval(E.multiply(E.fromInteger 0)(E.fromInteger 2))(~4)
   |_=>raise Fail"expected policy"
 val _=print(IntInf.toString result^"\n")
end

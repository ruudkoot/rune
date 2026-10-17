
structure K=BenchHiddenFn(BenchNeed)
structure NeedProbe=struct
  val a=K.vec(List.map K.N.literal[1.25,2.5,0.0])
  val b=K.vec(List.map K.N.literal[3.0,4.0,0.0])
  val first=BenchStream.head(K.plot(BenchStream.singleton(K.edgeT a b)))
  val(x,y)=K.inspectCommand first
  val _=T.check("hidden-command/Need/internal",fn()=>Real.==(x,1.25)andalso Real.==(y,2.5))
  val _=print("Need internal "^Real.toString x^" "^Real.toString y^"\n")
  val _=case first of K.Move(x,y)=>
    (print("Need external "^Real.toString(BenchNeed.force x)^" "^Real.toString(BenchNeed.force y)^"\n");
     T.check("hidden-command/Need/external",fn()=>Real.==(BenchNeed.force x,1.25)andalso Real.==(BenchNeed.force y,2.5)))
    |_=>raise Fail "unexpected command"
end

structure K=BenchHiddenFn(BenchStrict)
structure StrictProbe=struct
  val a=K.vec(List.map K.N.literal[1.25,2.5,0.0])
  val b=K.vec(List.map K.N.literal[3.0,4.0,0.0])
  val first=BenchStream.head(K.plot(BenchStream.singleton(K.edgeT a b)))
  val(x,y)=K.inspectCommand first
  val _=T.check("hidden-command/Strict/internal",fn()=>Real.==(x,1.25)andalso Real.==(y,2.5))
  val _=print("Strict internal "^Real.toString x^" "^Real.toString y^"\n")
  val _=case first of K.Move(x,y)=>
    (print("Strict external "^Real.toString(BenchStrict.force x)^" "^Real.toString(BenchStrict.force y)^"\n");
     T.check("hidden-command/Strict/external",fn()=>Real.==(BenchStrict.force x,1.25)andalso Real.==(BenchStrict.force y,2.5)))
    |_=>raise Fail "unexpected command"
end

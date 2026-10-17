val _=List.app(fn(x,y)=>print(
  Real.fmt(StringCvt.GEN(SOME 17))x^" "^Real.fmt(StringCvt.GEN(SOME 17))y^" "^
  Real.fmt(StringCvt.GEN(SOME 17))(Real.rem(x,y))^"\n"))
  [(7.0,3.0),(~7.0,3.0),(7.0,~3.0),(~7.0,~3.0),(6.0,3.0),(~6.0,3.0)]

val _=List.app(fn(x,y,wanted)=>
 let val label="rem/"^Real.toString x^"/"^Real.toString y
 in T.check(label^"/exact",fn()=>Real.==(Real.rem(x,y),wanted));
    T.check(label^"/sign",fn()=>Real.==(wanted,0.0)orelse Real.sameSign(Real.rem(x,y),x));
    T.check(label^"/magnitude",fn()=>Real.abs(Real.rem(x,y))<Real.abs y)
 end)[(7.0,3.0,1.0),(~7.0,3.0,~1.0),(7.0,~3.0,1.0),(~7.0,~3.0,~1.0),(6.0,3.0,0.0),(~6.0,3.0,0.0)]

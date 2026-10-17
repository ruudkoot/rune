val _=List.app(fn(x,y)=>print(
  Real.fmt(StringCvt.GEN(SOME 17))x^" "^Real.fmt(StringCvt.GEN(SOME 17))y^" "^
  Real.fmt(StringCvt.GEN(SOME 17))(Real.rem(x,y))^"\n"))
  [(7.0,3.0),(~7.0,3.0),(7.0,~3.0),(~7.0,~3.0),(6.0,3.0),(~6.0,3.0)]

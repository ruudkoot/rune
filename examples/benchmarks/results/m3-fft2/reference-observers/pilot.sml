structure Need=BenchFFT2Fn(BenchNeed)
structure Strict=BenchFFT2Fn(BenchStrict)
structure Main=struct
 val _=List.app(fn base=>
   let val m=Real.fromInt base+1.0/15.0
       fun emit mode results=print(mode^" "^Int.toString base^" "^
         String.concatWith " "(List.map(Real.fmt(StringCvt.GEN(SOME 17)))results)^"\n")
   in emit"Need"(Need.run m);emit"Strict"(Strict.run m)end)[70,245,490]
end

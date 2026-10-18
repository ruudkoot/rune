structure MiniLightPilot=
struct
 structure P=BenchMiniParse
 val input=P.read"tests/out/benchmarks/minilight-originals/smoke.model"
 val _=if P.next input="#MiniLight"then()else raise Fail"model header"
 val frames=Int.max(1,P.integer input)
 val image=BenchMiniImage.read input
 val camera=BenchMiniCamera.read input
 val scene=BenchMiniScene.read input(BenchMiniCamera.eye camera)
 val random=BenchMiniRandom.create()
 fun loop i=if i>frames then()else
   (BenchMiniCamera.frame camera scene image random;loop(i+1))
 val _=loop 1
 fun real value=Real.fmt(StringCvt.GEN(SOME 17))value
 val _=Array.appi(fn(i,pixel)=>print("pixel "^Int.toString i^" "^
   real(BenchMiniVector.sub pixel 0)^" "^real(BenchMiniVector.sub pixel 1)^" "^
   real(BenchMiniVector.sub pixel 2)^"\n"))(BenchMiniImage.pixels image)
 val _=print("state "^Int.toString(!(#index random))^" "^
   String.concat(List.map(fn w=>Int.toString(Word32.toInt w)^" ")(Array.foldr op :: [](#words random)))^"\n")
 val(header,bytes)=BenchMiniImage.formatted image(frames-1)
 val out=BinIO.openOut"tests/out/benchmarks/minilight-originals/smoke-rune.ppm"
 val _=BinIO.output(out,Byte.stringToBytes header)
 val _=BinIO.output(out,bytes)
 val _=BinIO.closeOut out
end

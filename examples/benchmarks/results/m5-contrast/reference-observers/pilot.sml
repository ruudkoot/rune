structure SauvolaPilot=
struct
 structure I=BenchSauvolaImage
 structure K=BenchSauvola
 val programs=[
   ("adaptive_contrast_spreading",K.adaptive),
   ("niblack_global_gray",K.niblackGlobal),
   ("niblack_local_gray",K.niblackLocal),
   ("niblack_local_monochrome",K.niblackMono),
   ("sauvola_global_gray",K.sauvolaGlobal),
   ("sauvola_global_monochrome",K.sauvolaGlobalMono),
   ("sauvola_local_gray",K.sauvolaLocal),
   ("sauvola_local_monochrome",K.sauvolaMono)]
 val image=I.read"tests/out/benchmarks/sauvola-originals/smoke.ppm"
 fun bits image=
   let fun char value=if value=0 then #"0"else if value=255 then #"1"else raise Fail"nonbinary result"
       val w=I.width image
   in CharVector.tabulate(w*I.height image*3,fn i=>
      let val pixel=I.get image((i div 3)mod w)((i div 3)div w)
      in char(case i mod 3 of 0=> #r pixel|1=> #g pixel|_=> #b pixel)end)^"\n"end
 fun read path=
   let val stream=TextIO.openIn path val contents=TextIO.inputAll stream val _=TextIO.closeIn stream in contents end
 val _=List.app(fn(name,f)=>
   let val result=f image
       val expected=read("tests/out/benchmarks/sauvola-originals/outputs/smoke/"^name^".bits")
   in if bits result=expected then print("PASS "^name^"\n")else raise Fail("incorrect result: "^name)end)programs
end

structure BenchSauvolaDriver=
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
 fun read path=
   let val stream=TextIO.openIn path
       val text=(TextIO.inputAll stream before TextIO.closeIn stream)
         handle ex=>(TextIO.closeIn stream;raise ex)
   in text end
 fun check image expected=
   let val n=I.width image*I.height image*3
       fun sample i=
         let val color=I.get image((i div 3)mod I.width image)((i div 3)div I.width image)
         in case i mod 3 of 0=> #r color|1=> #g color|_=> #b color end
       fun loop i=if i=n then()else
         let val value=sample i
             val wanted=case String.sub(expected,i)of #"0"=>0| #"1"=>255
               |_=>raise Fail"incorrect result: invalid contrast reference bit"
         in if value=wanted then loop(i+1)else raise Fail"incorrect result: contrast pixel"end
   in if String.size expected=n+1 andalso String.sub(expected,n)= #"\n"then loop 0
      else raise Fail"incorrect result: contrast reference dimensions"end
 fun run imagePath referencePrefix=
   let val image=I.read imagePath
       val _=List.app(fn(name,f)=>
         let val result=f image
             val _=if I.width result=I.width image andalso I.height result=I.height image
                   then()else raise Fail"incorrect result: contrast dimensions"
         in check result(read(referencePrefix^name^".bits"))end)programs
   in Int.toString(I.width image)^":"^Int.toString(I.height image)^":8"end
end

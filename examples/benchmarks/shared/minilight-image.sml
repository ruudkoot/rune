(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained. *)
structure BenchMiniImage=
struct
 structure V=BenchMiniVector
 datatype t=Image of{width:int,height:int,pixels:V.t array}
 fun read input=
   let val width=Int.max(1,Int.min(BenchMiniParse.integer input,10000))
       val height=Int.max(1,Int.min(BenchMiniParse.integer input,10000))
   in Image{width=width,height=height,pixels=Array.tabulate(width*height,fn _=>V.zero)}end
 fun width(Image{width,...})=width
 fun height(Image{height,...})=height
 fun pixels(Image{pixels,...})=pixels
 fun add(image as Image{width,height,pixels})x y radiance=
   if x>=0 andalso x<width andalso y>=0 andalso y<height then
     let val index=x+(height-1-y)*width
     in Array.update(pixels,index,V.add(Array.sub(pixels,index))radiance)end
   else()
 val luminance=V.create 0.2126 0.7152 0.0722
 fun toneMapping pixels divider=
   let val sum=Array.foldl(fn(pixel,total)=>
         total+Math.log10(Real.max(0.0001,V.dot pixel luminance*divider)))0.0 pixels
       val logMean=Math.pow(10.0,sum/Real.fromInt(Array.length pixels))
       val a=1.219+Math.pow(200.0*0.25,0.4)
       val b=1.219+Math.pow(logMean,0.4)
   in Math.pow(a/b,2.5)/200.0 end
 fun formatted(image as Image{width,height,pixels})iteration=
   let val divider=1.0/Real.fromInt(Int.max(0,iteration)+1)
       val scale=toneMapping pixels divider
       fun channel value=
         let val mapped=Real.max(0.0,Real.min(value*divider*scale,1.0))
             val gamma=Math.pow(mapped,0.45)
             val quantized=Real.max(0.0,Real.min(gamma*255.0+0.5,255.0))
         in Word8.fromInt(Real.trunc quantized)end
       val header="P6\n# http://www.hxa7241.org/minilight/\n\n"^Int.toString width^" "^Int.toString height^"\n255\n"
       val bytes=Word8Vector.tabulate(Array.length pixels*3,fn i=>
         channel(V.sub(Array.sub(pixels,i div 3))(i mod 3)))
   in(header,bytes)end
end

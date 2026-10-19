structure BenchMiniCheck=
struct
 structure V=BenchMiniVector
 structure I=BenchMiniImage
 type expected={width:int,height:int,frames:int,first:RealVector.vector,last:RealVector.vector,
   state:int vector,firstRGB:Word8Vector.vector,lastRGB:Word8Vector.vector}
 fun read path:expected=
   let val stream=TextIO.openIn path
       val text=(TextIO.inputAll stream before TextIO.closeIn stream)
         handle ex=>(TextIO.closeIn stream;raise ex)
       val tokens=ref(String.tokens Char.isSpace text)
       fun next()=case !tokens of []=>raise Fail"truncated MiniLight reference"
         |x::xs=>(tokens:=xs;x)
       fun integer()=case Int.fromString(next())of SOME n=>n|NONE=>raise Fail"invalid MiniLight reference integer"
       fun real()=case Real.fromString(next())of SOME r=>r|NONE=>raise Fail"invalid MiniLight reference real"
       val w=integer()val h=integer()val frames=integer()
       val _=if w>0 andalso h>0 andalso w<=10000 andalso h<=10000 andalso frames>0
             then()else raise Fail"invalid MiniLight reference geometry"
       val channels=w*h*3
       val first=RealVector.tabulate(channels,fn _=>real())
       val last=RealVector.tabulate(channels,fn _=>real())
       val state=Vector.tabulate(56,fn _=>integer())
       fun byte()=let val value=integer()in if value<0 orelse value>255
                   then raise Fail"invalid MiniLight reference byte"else Word8.fromInt value end
       val firstRGB=Word8Vector.tabulate(channels,fn _=>byte())
       val lastRGB=Word8Vector.tabulate(channels,fn _=>byte())
       val _=if null(!tokens)then()else raise Fail"extra MiniLight reference data"
   in {width=w,height=h,frames=frames,first=first,last=last,state=state,firstRGB=firstRGB,lastRGB=lastRGB}end
 fun close(a,b)=Real.isFinite a andalso Real.isFinite b andalso
   Real.abs(a-b)<=1.0E~8+1.0E~8*Real.abs b
 fun pixels image expected=
   let val values=I.pixels image
       val n=Array.length values*3
       fun loop i=i=n orelse(close(V.sub(Array.sub(values,i div 3))(i mod 3),RealVector.sub(expected,i))andalso loop(i+1))
   in RealVector.length expected=n andalso loop 0 end
 fun raster actual expected=
   let val n=Word8Vector.length actual
       fun loop i=i=n orelse(Word8Vector.sub(actual,i)=Word8Vector.sub(expected,i)andalso loop(i+1))
   in Word8Vector.length expected=n andalso loop 0 end
 fun randomState({words,index}:BenchOCamlRandom.state)expected=
   Vector.length expected=56 andalso !index=Vector.sub(expected,0)andalso
   let fun loop i=i=55 orelse(Word32.toInt(Array.sub(words,i))=Vector.sub(expected,i+1)andalso loop(i+1))
   in loop 0 end
 fun snapshot image frame expectedPixels expectedRGB=
   let val(header,bytes)=I.formatted image(frame-1)
       val wanted="P6\n# http://www.hxa7241.org/minilight/\n\n"^Int.toString(I.width image)^" "^Int.toString(I.height image)^"\n255\n"
   in if header=wanted andalso pixels image expectedPixels andalso raster bytes expectedRGB
      then()else raise Fail"incorrect result: MiniLight snapshot"end
 fun run model reference=
   let val expected=read reference
       val input=BenchMiniParse.read model
       val _=if BenchMiniParse.next input="#MiniLight"then()else raise Fail"invalid MiniLight model header"
       val frames=Int.max(1,BenchMiniParse.integer input)
       val image=I.read input
       val _=if frames= #frames expected andalso I.width image= #width expected andalso I.height image= #height expected
             then()else raise Fail"MiniLight reference geometry mismatch"
       val camera=BenchMiniCamera.read input
       val scene=BenchMiniScene.read input(BenchMiniCamera.eye camera)
       val random=BenchMiniRandom.create()
       fun loop frame=
         if frame>frames then()
         else(BenchMiniCamera.frame camera scene image random;
          if frame=1 then snapshot image frame(#first expected)(#firstRGB expected)else();
          if frame=frames andalso frame<>1 then snapshot image frame(#last expected)(#lastRGB expected)else();
          loop(frame+1))
       val _=loop 1
       val _=if pixels image(#last expected)andalso randomState random(#state expected)
             then()else raise Fail"incorrect result: MiniLight final accumulation or random state"
   in Int.toString frames^":"^Int.toString(I.width image*I.height image)^":"^Int.toString(if frames=1 then 1 else 2)end
end

(* Portable RGB24/PPM fragment used by the Sauvola source.
 * CamlImages 5.0.4 selected sources and notices accompany the import.
 * Contiguous Word8Array storage replaces its block-managed byte storage. *)
structure BenchSauvolaImage=
struct
 type rgb={r:int,g:int,b:int}
 datatype image=Image of{width:int,height:int,data:Word8Array.array}
 fun width(Image{width,...})=width
 fun height(Image{height,...})=height
 fun create width height=
   if width<=0 orelse height<=0 orelse width>4096 orelse height>4096 then raise Size
   else Image{width=width,height=height,data=Word8Array.array(width*height*3,0w0)}
 fun index(Image{width,height,...})x y=
   if x<0 orelse x>=width orelse y<0 orelse y>=height then raise Subscript
   else(y*width+x)*3
 fun get(image as Image{data,...})x y:rgb=
   let val i=index image x y
   in {r=Word8.toInt(Word8Array.sub(data,i)),g=Word8.toInt(Word8Array.sub(data,i+1)),
       b=Word8.toInt(Word8Array.sub(data,i+2))}end
 fun set(image as Image{data,...})x y({r,g,b}:rgb)=
   let val i=index image x y
       val _=if r<0 orelse r>255 orelse g<0 orelse g>255 orelse b<0 orelse b>255 then raise Domain else()
   in Word8Array.update(data,i,Word8.fromInt r);
      Word8Array.update(data,i+1,Word8.fromInt g);
      Word8Array.update(data,i+2,Word8.fromInt b)end
 fun loop first last f=if first>last then()else(f first;loop(first+1)last f)
 fun sub image x y w h=
   let val _=if w<=0 orelse h<=0 orelse x<0 orelse y<0 orelse x+w>width image orelse y+h>height image
             then raise Subscript else()
       val result=create w h
       val _=loop 0(h-1)(fn j=>loop 0(w-1)(fn i=>set result i j(get image(x+i)(y+j))))
   in result end
 fun brightness({r,g,b}:rgb)=(r*54+g*182+b*19)div 255
 fun read path=
   let val stream=BinIO.openIn path
       val bytes=(BinIO.inputAll stream before BinIO.closeIn stream)
         handle ex=>(BinIO.closeIn stream;raise ex)
       val n=Word8Vector.length bytes
       val position=ref 0
       fun char i=Char.chr(Word8.toInt(Word8Vector.sub(bytes,i)))
       fun line()=if !position=n then()else
         let val c=char(!position)val _=position:= !position+1
         in if c= #"\n"then()else line()end
       fun skip()=if !position=n then()else
         if Char.isSpace(char(!position))then(position:= !position+1;skip())
         else if char(!position)= #"#"then(line();skip())else()
       fun token()=
         let val _=skip()val start= !position
             fun finish()=if !position<n andalso not(Char.isSpace(char(!position)))andalso char(!position)<> #"#"
               then(position:= !position+1;finish())else()
             val _=finish()
         in if start= !position then raise Fail"truncated PPM token"
            else CharVector.tabulate(!position-start,fn i=>char(start+i))end
       fun integer()=let val text=token() val _=if List.all Char.isDigit(String.explode text)then()else raise Fail"invalid PPM integer"
         in case Int.fromString text of SOME i=>i|NONE=>raise Fail"invalid PPM integer"end
       val magic=token()
       val w=integer()val h=integer()val maximum=integer()
       val _=if maximum=255 then()else raise Fail"PPM maximum must be 255"
       val result as Image{data,...}=create w h
       val length=w*h*3
       val _=if magic="P6"then
         let val _=if !position<n andalso Char.isSpace(char(!position))then position:= !position+1
                   else raise Fail"missing P6 separator"
             val start= !position
             val _=if n-start=length then()else raise Fail"P6 raster length"
         in loop 0(length-1)(fn i=>Word8Array.update(data,i,Word8Vector.sub(bytes,start+i)))end
         else if magic="P3"then
           (loop 0(length-1)(fn i=>let val value=integer()
              in if value<0 orelse value>255 then raise Fail"PPM sample range"
                 else Word8Array.update(data,i,Word8.fromInt value)end);
            skip();if !position=n then()else raise Fail"extra P3 samples")
         else raise Fail"unsupported PPM magic"
   in result end
 fun writeP3 path image=
   let val stream=TextIO.openOut path
       fun output text=TextIO.output(stream,text)
       val _=output("P3\n"^Int.toString(width image)^" "^Int.toString(height image)^"\n255\n")
       val _=(loop 0(height image-1)(fn y=>loop 0(width image-1)(fn x=>
         let val{r,g,b}=get image x y
         in output(Int.toString r^" "^Int.toString g^" "^Int.toString b^"\n")end))
         handle ex=>(TextIO.closeOut stream;raise ex))
   in TextIO.closeOut stream end
end

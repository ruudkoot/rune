(* The renderer's floating calculations can select different sides of a
   degenerate CSG interval. Reference images and bounds are documented in
   PROVENANCE.md; this checker never changes the rendering algorithm. *)
structure ChessImageCheck =
struct
  fun read path =
    let val input=BinIO.openIn path
        val bytes=BinIO.inputAll input handle e=>(BinIO.closeIn input;raise e)
    in BinIO.closeIn input;bytes end
  fun header bytes =
    let fun loop(i,lines)=
          if lines=4 then i else if i=Word8Vector.length bytes then raise Fail "short PPM header"
          else loop(i+1,if Word8Vector.sub(bytes,i)=0w10 then lines+1 else lines)
    in loop(0,0) end
  fun sameSet(actual,references)=
    let val image=read actual val images=List.map read references
        val gold=case images of x::_=>x | []=>raise Fail "missing PPM references"
        val n=Word8Vector.length image val start=header gold
        val _=if List.all(fn bytes=>n=Word8Vector.length bytes)images andalso
                 (n-start) mod 3=0 then () else raise Fail "PPM dimensions"
        fun prefix i=if i=start then () else
          if List.all(fn bytes=>Word8Vector.sub(image,i)=Word8Vector.sub(bytes,i))images then prefix(i+1)
          else raise Fail "PPM header differs"
        fun channel(a,b)=Int.abs(Word8.toInt a-Word8.toInt b)<=2
        fun pixel(i,refImage)=List.all(fn offset=>channel(Word8Vector.sub(image,i+offset),Word8Vector.sub(refImage,i+offset)))[0,1,2]
        fun loop i=if i=n then () else if List.exists(fn bytes=>pixel(i,bytes))images then loop(i+3)
                    else raise Fail "rendered pixel differs"
        val _=prefix 0 val _=loop start
    in Int.toString((n-start) div 3) end
  fun same(actual,reference,alternate)=sameSet(actual,[reference,alternate])
end

(* Quantized-image validation; a one-level RGB tolerance handles rounding at
   integer boundaries. Dimensions, format and every channel are checked. *)
structure BenchPPM =
struct
  fun read path =
    let val input = BinIO.openIn path
        val bytes = BinIO.inputAll input
        val _ = BinIO.closeIn input
        val n = Word8Vector.length bytes
        fun char i = Char.chr (Word8.toInt (Word8Vector.sub (bytes,i)))
        fun comment i = if i=n orelse char i = #"\n" then i else comment(i+1)
        fun skip i = if i=n then i else if Char.isSpace(char i) then skip(i+1)
                     else if char i = #"#" then skip(comment(i+1)) else i
        fun token i = let val i=skip i
                         fun stop j = if j=n orelse Char.isSpace(char j) then j else stop(j+1)
                         val j=stop i
                     in (String.implode(List.tabulate(j-i,fn k=>char(i+k))),j) end
        val (magic,a)=token 0
        val (width,b)=token a
        val (height,c)=token b
        val (maximum,d)=token c
        fun integer s = case Int.fromString s of SOME x=>x | NONE=>raise Fail "PPM integer"
        val w=integer width
        val h=integer height
        val _=if magic="P6" andalso w>0 andalso h>0 andalso maximum="255"
                 andalso d<n andalso Char.isSpace(char d) then () else raise Fail "PPM header"
        val offset=d+1
        val _=if n-offset=3*w*h then () else raise Fail "PPM data length"
    in (w,h,Word8VectorSlice.vector(Word8VectorSlice.slice(bytes,offset,NONE))) end

  fun sameSet (actual,references) =
    let val(w,h,a)=read actual
        val images=List.map read references
        val _=if not(List.null images) andalso List.all(fn(w1,h1,_)=>w=w1 andalso h=h1)images
              then () else raise Fail "PPM dimensions"
        val n=Word8Vector.length a
        fun pixel(i,(_,_,b))=List.all(fn k=>
          Int.abs(Word8.toInt(Word8Vector.sub(a,i+k))-Word8.toInt(Word8Vector.sub(b,i+k)))<=1)[0,1,2]
        fun loop i = if i=n then () else
          if List.exists(fn b=>pixel(i,b))images then loop(i+3) else raise Fail "PPM channel differs"
        val _=loop 0
    in Int.toString(w*h) end
  fun same(actual,expected)=sameSet(actual,[expected])
end

structure BenchReverseComplementTwo =
struct
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun run path emit=
    let val table=Word8Array.array(256,Word8.fromInt 32)
        val buffer=Word8Array.array(61,Word8.fromInt 10)
        val index=ref 1
        val letters="TVGHEFCDIJMLKNOPQYSAABWXRZ"
        val _=for 0 25(fn i=>Word8Array.update(table,65+i,Word8.fromInt(Char.ord(String.sub(letters,i)))))
        val _=for 0 25(fn i=>Word8Array.update(table,97+i,Word8Array.sub(table,65+i)))
        val input=TextIO.openIn path
        fun emitBuffer count=for 0(count-1)(fn i=>emit(Word8Array.sub(buffer,i)))
        fun emitText text=for 0(String.size text-1)(fn i=>emit(Word8.fromInt(Char.ord(String.sub(text,i)))))
        fun write []=(if !index>1 then emitBuffer(!index)else();index:=1)
          | write(s::rest)=
            let fun reverse i=if i<0 then()else
                  (Word8Array.update(buffer,!index,Word8Array.sub(table,Char.ord(String.sub(s,i))));
                   if !index<60 then index:= !index+1 else(emitBuffer 61;index:=1);
                   reverse(i-1))
            in reverse(String.size s-1);write rest end
        fun line()=case(TextIO.inputLine input handle _=>NONE)of
            NONE=>("",true)
          | SOME text=>
            (if String.size text>0 andalso String.sub(text,String.size text-1)= #"\n"
             then String.substring(text,0,String.size text-1)else text,false)
        fun read lines=
          let val(text,eof)=line()
          in if text<>""andalso String.sub(text,0)<> #">"then read(text::lines)
             else(write lines;emitText(if List.null lines then text else "\n"^text);
                  if eof then()else read[])end
        val _=read[]handle ex=>(TextIO.closeIn input;raise ex)
    in TextIO.closeIn input end
end

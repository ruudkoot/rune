(* Implements: FOREIGN_TEXT *)
structure ForeignText : FOREIGN_TEXT =
struct
  datatype encoding=Bytes | Utf8 | Wtf8 | Utf16
  exception Error of {offset:int,message:string}
  fun fail offset message=raise Error{offset=offset,message=message}
  fun codepoints allow text=
    let val n=size text
        fun byte i=Char.ord(String.sub(text,i))
        fun next i=case Utf8.decode(text,i) of SOME pair=>pair | NONE=>
          if allow andalso i+2<n andalso byte i=237 andalso byte(i+1)>=160 andalso byte(i+1)<=191 andalso
             byte(i+2)>=128 andalso byte(i+2)<=191 then
            ((byte i-224)*4096+(byte(i+1)-128)*64+byte(i+2)-128,3)
          else fail i "malformed foreign text"
        fun go(i,acc)=if i=n then rev acc else let val(cp,width)=next i in go(i+width,(i,cp)::acc) end
    in go(0,[]) end
  fun utf8 cp=if cp>=55296 andalso cp<=57343 then String.implode
      [Char.chr(224+cp div 4096),Char.chr(128+cp div 64 mod 64),Char.chr(128+cp mod 64)] else Utf8.encode cp
  fun prefix width terminated bytes=
    if not terminated then bytes else
    let val n=size bytes
        fun zero i=String.sub(bytes,i)= #"\000" andalso (width=1 orelse String.sub(bytes,i+1)= #"\000")
        fun go i=if i=n then fail i "native terminator is outside the annotated extent"
          else if zero i then String.substring(bytes,0,i) else go(i+width)
    in go 0 end
  fun encode{encoding,littleEndian,terminated,text}=
    let val ()=if terminated then case CharVector.findi(fn(_,c)=>c= #"\000")text of
          SOME(i,_)=>fail i "embedded NUL in terminated foreign text" | NONE=>() else ()
        fun unit cp=ForeignBytes.integer{width=2,signed=false,littleEndian=littleEndian,value=IntInf.fromInt cp}
        fun units(_,cp)=if cp<=65535 then unit cp else
          let val n=cp-65536 in unit(55296+n div 1024) ^ unit(56320+n mod 1024) end
        val output=case encoding of Bytes=>text
          | Utf8=>(ignore(codepoints false text);text)
          | Wtf8=>(ignore(codepoints true text);text)
          | Utf16=>String.concat(List.map units(codepoints true text))
    in output ^ (if terminated then if encoding=Utf16 then "\000\000" else "\000" else "") end
  fun decode{encoding,littleEndian,terminated,bytes}=
    let val ()=if encoding=Utf16 andalso size bytes mod 2<>0 then fail(size bytes-1)"odd UTF-16 byte count" else ()
        val input=prefix (if encoding=Utf16 then 2 else 1) terminated bytes
        fun unit i=IntInf.toInt(ForeignBytes.value{signed=false,littleEndian=littleEndian,bytes=String.substring(input,i,2)})
        fun wide(i,acc)=if i=size input then String.concat(rev acc) else
          let val first=unit i
              val pair=first>=55296 andalso first<=56319 andalso i+2<size input andalso unit(i+2)>=56320 andalso unit(i+2)<=57343
              val cp=if pair then 65536+(first-55296)*1024+unit(i+2)-56320 else first
          in wide(i+(if pair then 4 else 2),utf8 cp::acc) end
    in case encoding of Bytes=>input | Utf8=>(ignore(codepoints false input);input)
      | Wtf8=>(ignore(codepoints true input);input) | Utf16=>wide(0,[]) end
end

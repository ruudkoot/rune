(* Implements: FOREIGN_BYTES *)
structure ForeignBytes : FOREIGN_BYTES =
struct
  exception Error of string
  fun power n=IntInf.<<(1,Word.fromInt n)
  fun valid width=if width>=1 andalso width<=16 then () else raise Error "foreign integer width must be 1..16 bytes"
  fun integer{width,signed,littleEndian,value}=
    let val ()=valid width val modulus=power(width*8)
        val half=power(width*8-1)
        val ()=if value >= (if signed then IntInf.~ half else 0) andalso value < (if signed then half else modulus)
               then () else raise Error "foreign integer value is out of range"
        val bits=IntInf.mod(value,modulus)
    in String.implode(List.tabulate(width,fn i=>Char.chr(IntInf.toInt(IntInf.andb(
      IntInf.~>>(bits,Word.fromInt((if littleEndian then i else width-i-1)*8)),255))))) end
  fun value{signed,littleEndian,bytes}=
    let val width=size bytes val ()=valid width
        fun byte i=IntInf.fromInt(Char.ord(String.sub(bytes,if littleEndian then width-i-1 else i)))
        fun loop(i,n)=if i=width then n else loop(i+1,IntInf.+(IntInf.*(n,256),byte i))
        val n=loop(0,0)
    in if signed andalso n>=power(width*8-1) then IntInf.-(n,power(width*8)) else n end
  fun real64{littleEndian,value}=if PackRealLittle.bytesPerElem<>8 orelse PackRealBig.bytesPerElem<>8
    then raise Error "default SML real is not binary64" else Byte.bytesToString(
    (if littleEndian then PackRealLittle.toBytes else PackRealBig.toBytes)value)
  fun real64Value{littleEndian,bytes}=if size bytes<>8 then raise Error "foreign binary64 requires eight bytes" else
    if PackRealLittle.bytesPerElem<>8 orelse PackRealBig.bytesPerElem<>8 then raise Error "default SML real is not binary64" else
    (if littleEndian then PackRealLittle.fromBytes else PackRealBig.fromBytes)(Byte.stringToBytes bytes)
  fun rounded(number,shift)=
    let val divisor=power shift val quotient=IntInf.div(number,divisor)
        val remainder=IntInf.mod(number,divisor) val half=IntInf.div(divisor,2)
    in if remainder>half orelse(remainder=half andalso IntInf.mod(quotient,2)=1)
       then IntInf.+(quotient,1) else quotient end
  fun real32{littleEndian,value=number}=
    let val bits=value{signed=false,littleEndian=true,bytes=real64{littleEndian=true,value=number}}
        val sign=IntInf.*(IntInf.div(bits,power 63),power 31)
        val exponent=IntInf.toInt(IntInf.mod(IntInf.div(bits,power 52),2048))
        val fraction=IntInf.mod(bits,power 52)
        fun finite()=
          if exponent=0 then 0 else
          let val e=exponent-1023 val significand=IntInf.+(power 52,fraction)
          in if e>127 then IntInf.*(255,power 23)
             else if e< ~126 then rounded(significand,29+(~126-e))
             else let val mantissa=rounded(significand,29)
                      val carry=mantissa=power 24
                      val e=if carry then e+1 else e
                  in if e>127 then IntInf.*(255,power 23)
                     else IntInf.+(IntInf.*(IntInf.fromInt(e+127),power 23),
                       IntInf.-(if carry then power 23 else mantissa,power 23)) end
          end
        val magnitude=if exponent=2047 then
          IntInf.+(IntInf.*(255,power 23),if fraction=0 then 0 else power 22) else finite()
    in integer{width=4,signed=false,littleEndian=littleEndian,value=IntInf.+(sign,magnitude)} end
  fun real32Value{littleEndian,bytes}=
    if size bytes<>4 then raise Error "foreign binary32 requires four bytes" else
    let val bits=value{signed=false,littleEndian=littleEndian,bytes=bytes}
        val sign=IntInf.*(IntInf.div(bits,power 31),power 63)
        val exponent=IntInf.toInt(IntInf.mod(IntInf.div(bits,power 23),256))
        val fraction=IntInf.mod(bits,power 23)
        fun subnormal()=if fraction=0 then 0 else
          let fun leading p=if fraction>=power(p+1) then leading(p+1) else p
              val p=leading 0
          in IntInf.+(IntInf.*(IntInf.fromInt(p-149+1023),power 52),
             IntInf.*(IntInf.-(fraction,power p),power(52-p))) end
        val magnitude=if exponent=0 then subnormal() else
          IntInf.+(IntInf.*(IntInf.fromInt(if exponent=255 then 2047 else exponent+896),power 52),
            IntInf.*(fraction,power 29))
    in real64Value{littleEndian=true,bytes=integer{width=8,signed=false,littleEndian=true,value=IntInf.+(sign,magnitude)}} end
end

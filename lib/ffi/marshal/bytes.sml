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
end

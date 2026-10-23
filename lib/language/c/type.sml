(* Implements: C_TYPE *)
structure CType : C_TYPE =
struct
  fun canonical name =
    let val words=String.tokens Char.isSpace name
        fun count name=length(List.filter(fn word=>word=name)words)
        val signed=count "signed" val unsigned=count "unsigned"
        val sign=if unsigned=1 then "unsigned " else ""
        fun only allowed=List.all(fn word=>List.exists(fn allowed=>word=allowed)allowed)words
        val validSign=signed<=1 andalso unsigned<=1 andalso signed+unsigned<=1
        val longs=count "long" val shorts=count "short" val ints=count "int" val chars=count "char"
        fun integer base=if validSign then sign ^ base else name
    in if words=["void"] then "void" else if words=["bool"] orelse words=["_Bool"] then "_Bool"
       else if words=["float"] then "float"
       else if count "double"=1 andalso longs<=1 andalso only["double","long"] then
         (if longs=1 then "long double" else "double")
       else if validSign andalso only["signed","unsigned","__int8"] andalso count "__int8"=1 then
         (if unsigned=1 then "unsigned char" else "signed char")
       else if only["signed","unsigned","__int16"] andalso count "__int16"=1 then integer "short"
       else if only["signed","unsigned","__int32"] andalso count "__int32"=1 then integer "int"
       else if only["signed","unsigned","__int64"] andalso count "__int64"=1 then integer "long long"
       else if validSign andalso only["signed","unsigned","char","short","int","long"] andalso
          chars<=1 andalso shorts<=1 andalso ints<=1 andalso longs<=2 then
         if chars=1 andalso shorts=0 andalso ints=0 andalso longs=0 then
           (if unsigned=1 then "unsigned char" else if signed=1 then "signed char" else "char")
         else if chars=0 andalso shorts=1 andalso longs=0 then sign ^ "short"
         else if chars=0 andalso shorts=0 andalso not(null words) then
           sign ^ (if longs=2 then "long long" else if longs=1 then "long" else "int")
         else name
       else name
    end
  fun parse {tokens,typedefs} =
    SOME(CParse.typeName{tokens=tokens,predefinedTypes=typedefs}) handle CParse.Error _=>NONE
  fun integer {target,charSigned,ty} =
    let fun walk(CParse.Attributed(ty,_))=walk ty
          | walk(CParse.Builtin name)=
            let val name=canonical name
                val signed=not(String.isPrefix "unsigned " name)
                val base=if signed then name else String.extract(name,9,NONE)
                val rank=case base of "char"=>SOME CInteger.Char | "signed char"=>SOME CInteger.Char
                  | "short"=>SOME CInteger.Short | "int"=>SOME CInteger.Int | "long"=>SOME CInteger.Long
                  | "long long"=>SOME CInteger.LongLong | _=>NONE
            in case rank of NONE=>if name="_Bool" then SOME{rank=CInteger.Char,width=1,signed=false} else NONE
              | SOME rank=>SOME(CInteger.integerType target rank (if name="char" then charSigned else signed)) end
          | walk _=NONE
    in walk ty end
  fun spelling({rank,width,signed}:CInteger.integerType)=
    if width=1 then "_Bool" else
    (if signed then (if rank=CInteger.Char then "signed " else "") else "unsigned ") ^
    (case rank of CInteger.Char=>"char" | CInteger.Short=>"short" | CInteger.Int=>"int"
      | CInteger.Long=>"long" | CInteger.LongLong=>"long long")
end

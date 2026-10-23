(* Implements: FOREIGN_TARGET *)
structure ForeignTarget : FOREIGN_TARGET =
struct
  type profile={name:string,triple:string,abi:string,byteOrder:ForeignModel.byteOrder,analysis:CAnalysis.target,
    predefined:(string*string)list}
  exception Error=ForeignJson.Error
  fun decode input=
    let val document=ForeignJson.decode input
        fun object path allowed value=ForeignJson.object document path allowed value
        fun member path fields key=ForeignJson.member document path fields key
        fun fail path text=ForeignJson.error document path text
        fun string path value=ForeignJson.string document path value
        fun number path value=case value of Json.Number text=>
              (case Int.fromString text of SOME n=>if Int.toString n=text then n else fail path "target fact must be an integer"
               | NONE=>fail path "target integer is out of range") | _=>fail path "expected target integer"
        val fields=object [] ["schema","name","triple","abi","byteOrder","charSigned","enumRule","sizeType","widths","alignments","verifiedBy","predefined"] (ForeignJson.value document)
        val ()=if number["schema"](member []fields "schema")=1 then () else fail["schema"]"unsupported target schema"
        fun text key=string[key](member []fields key)
        val name=text "name" val triple=text "triple" val abi=text "abi"
        val ()=if List.exists(fn s=>s=abi)["sysv","win32","win64"] then () else fail["abi"]"unsupported target ABI"
        val byteOrder=case text "byteOrder" of "little"=>ForeignModel.Little | "big"=>ForeignModel.Big | _=>fail["byteOrder"]"unknown target byte order"
        val charSigned=ForeignJson.boolean document ["charSigned"](member []fields "charSigned")
        val enumRule=case text "enumRule" of "signed"=>CAnalysis.SignedEnums | "unsigned-nonnegative"=>CAnalysis.UnsignedNonnegative
          | _=>fail["enumRule"]"unsupported enum representation policy"
        val widths=object["widths"]["char","short","int","long","longLong","pointer","size","wchar","float","double","bool"](member []fields "widths")
        val aligns=object["alignments"]["char","short","int","long","longLong","pointer","wchar","float","double","bool"](member []fields "alignments")
        fun width key=number["widths",key](member["widths"]widths key)
        fun align key=number["alignments",key](member["alignments"]aligns key)
        val scalarNames=["char","short","int","long","longLong","pointer","wchar","float","double","bool"]
        fun power n=n=1 orelse(n>1 andalso n mod 2=0 andalso power(n div 2))
        val ()=List.app(fn key=>if width key>0 andalso width key<=16 andalso power(align key)
          andalso align key<=width key andalso width key mod align key=0
          then () else fail["widths",key]"invalid scalar width/alignment")scalarNames
        val ()=if width "char"=1 andalso width "bool"=1 andalso width "float"=4 andalso width "double"=8 andalso
          List.exists(fn n=>n=width "pointer")[4,8] andalso width "size"=width "pointer" andalso
          width "short"<=width "int" andalso width "int"<=width "long" andalso width "long"<=width "longLong"
          then () else fail["widths"]"unsupported or inconsistent delivery target widths"
        val ()=if (abi="win32" andalso width "pointer"<>4) orelse (abi="win64" andalso width "pointer"<>8)
          then fail["abi"]"Windows ABI disagrees with pointer width" else ()
        val integers={char=width "char"*8,short=width "short"*8,int=width "int"*8,long=width "long"*8,longLong=width "longLong"*8}
        val sizeType=case CType.integer{target=integers,charSigned=charSigned,ty=CParse.Builtin(text "sizeType")} of
          SOME ty=>if not(#signed ty) andalso #width ty=width "size"*8 then ty else fail["sizeType"]"size_t width/signedness disagrees with target"
          | NONE=>fail["sizeType"]"size_t is not a supported integer type"
        fun scalar key signed={size=width key,alignment=align key,signed=signed}
        val scalars=[("char",scalar "char"(SOME charSigned)),("signed char",scalar "char"(SOME true)),("unsigned char",scalar "char"(SOME false)),
          ("_Bool",scalar "bool"(SOME false)),("float",scalar "float" NONE),("double",scalar "double" NONE)] @
          List.concat(List.map(fn(c,key)=>[(c,scalar key(SOME true)),("unsigned " ^ c,scalar key(SOME false))])
            [("short","short"),("int","int"),("long","long"),("long long","longLong")])
        val objects={name=name,pointer=scalar "pointer" NONE,enumeration=scalar "int" NONE,scalars=scalars,
          maximumObject=IntInf.-(IntInf.<<(1,Word.fromInt(width "size"*8-1)),1)}
        val ()=ignore(text "verifiedBy")
        val predefined=List.map(fn entry=>case ForeignJson.array document ["predefined"]entry of
          [a,b]=>(string["predefined"]a,string["predefined"]b) | _=>fail["predefined"]"expected macro name/value pair")
          (ForeignJson.array document ["predefined"](member []fields "predefined"))
        fun distinct []=()
          | distinct((name,_)::rest)=if List.exists(fn(n,_)=>n=name)rest then fail["predefined"]"duplicate target macro"
            else if name="" then fail["predefined"]"empty target macro" else distinct rest
        val ()=distinct predefined
    in {name=name,triple=triple,abi=abi,byteOrder=byteOrder,analysis={integers=integers,objects=objects,charSigned=charSigned,sizeType=sizeType,enumRule=enumRule},predefined=predefined} end
  fun model({name,abi,byteOrder,analysis,...}:profile) : ForeignModel.target=
    {name=name,abi=abi,byteOrder=byteOrder,scalars= #scalars(#objects analysis)}
end

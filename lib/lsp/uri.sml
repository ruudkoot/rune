(* Client URI identity and native file-path conversion.

   Implements: LSP_URI *)
structure LspUri :> LSP_URI =
struct
  datatype platform=Posix | Windows
  datatype t=Uri of {original:string,scheme:string,authority:string option,path:string,suffix:bool}
  exception Invalid
  fun lower text=String.map (fn c => if c>= #"A" andalso c<= #"Z" then Char.chr (Char.ord c+32) else c) text
  fun alpha c=(c>= #"a" andalso c<= #"z") orelse (c>= #"A" andalso c<= #"Z")
  fun digit c=c>= #"0" andalso c<= #"9"
  fun schemeChar c=alpha c orelse digit c orelse Char.contains "+-." c
  fun parse original =
    let val length=size original
        val ()=if length>0 andalso Utf8.isValid original andalso
          CharVector.all (fn c => Char.ord c>32 andalso Char.ord c<>127 andalso not (Char.contains "\\<>\"{}|^`" c)) original then () else raise Invalid
        fun colon i=if i=length then raise Invalid else if String.sub (original,i)= #":" then i else colon (i+1)
        val at=colon 0
        val scheme=String.substring (original,0,at)
        val ()=if at>0 andalso alpha (String.sub (scheme,0)) andalso CharVector.all schemeChar scheme then () else raise Invalid
        val rest=String.extract (original,at+1,NONE)
        fun stop i=if i=size rest orelse Char.contains "?#" (String.sub (rest,i)) then i else stop (i+1)
        val last=stop 0
        val body=String.substring (rest,0,last)
        val (authority,path)=if String.isPrefix "//" body then
          let fun slash i=if i=size body orelse String.sub (body,i)= #"/" then i else slash (i+1)
              val endHost=slash 2
          in (SOME (String.substring (body,2,endHost-2)),String.extract (body,endHost,NONE)) end else (NONE,body)
        fun escapes i=if i=length then () else if String.sub (original,i)<> #"%" then escapes (i+1)
          else if i+2<length andalso Char.isHexDigit (String.sub (original,i+1)) andalso Char.isHexDigit (String.sub (original,i+2))
          then escapes (i+3) else raise Invalid
        val ()=escapes 0
    in Uri {original=original,scheme=lower scheme,authority=authority,path=path,suffix=last<size rest} end
  fun original (Uri {original,...})=original
  fun decode text =
    let fun digit c=if Char.isDigit c then Char.ord c-48 else Char.ord (Char.toLower c)-87
        fun scan (i,parts)=if i=size text then String.concat (List.rev parts)
          else if String.sub (text,i)= #"%" then
            scan (i+3,String.str (Char.chr (digit (String.sub (text,i+1))*16+digit (String.sub (text,i+2)))) :: parts)
          else scan (i+1,String.str (String.sub (text,i)) :: parts)
    in scan (0,[]) end
  fun wtf8 text =
    let fun byte i=Char.ord (String.sub (text,i))
        fun scan i=if i=size text then true else
          case Utf8.decode (text,i) of SOME (_,bytes) => scan (i+bytes)
          | NONE => i+2<size text andalso byte i=0xED andalso byte (i+1)>=0xA0 andalso byte (i+1)<=0xBF
                    andalso byte (i+2)>=0x80 andalso byte (i+2)<=0xBF andalso scan (i+3)
    in scan 0 end
  fun dots path =
    let val parts=String.fields (fn c => c = #"/") path
        val kept=List.filter (fn p => p<>".") parts
    in String.concatWith "/" kept end
  fun drive path=size path>=3 andalso alpha (String.sub (path,0)) andalso
    String.sub (path,1)= #":" andalso String.sub (path,2)= #"/"
  fun native (platform,Uri {scheme,authority,path,suffix,...}) =
    if scheme<>"file" orelse suffix orelse not (String.isPrefix "/" path) then NONE else
    let val path=decode path
        val host=case authority of NONE => "" | SOME name => decode name
        val ()=if CharVector.exists (fn c => c = #"\000") (host ^ path) orelse
          CharVector.exists (fn c => Char.contains "@\\/" c) host then raise Invalid else ()
        val isLocal=host="" orelse lower host="localhost"
    in case platform of
      Posix => if not isLocal then NONE else SOME {path=path,key=dots path}
    | Windows =>
        if not (wtf8 (host ^ path)) then raise Invalid else
        if not isLocal then SOME {path="//" ^ host ^ path,key=dots ("//" ^ lower host ^ path)}
        else let val unrooted=String.extract (path,1,NONE)
             in if drive unrooted then SOME {path=unrooted,
                  key=String.str (Char.toUpper (String.sub (unrooted,0))) ^ dots (String.extract (unrooted,1,NONE))} else NONE end
    end
  fun encode path =
    let val hex="0123456789ABCDEF"
    in String.translate (fn c => if Char.isAlphaNum c andalso Char.ord c<128 orelse Char.contains "-._~/:" c
          then String.str c else "%" ^ String.str (String.sub (hex,Char.ord c div 16)) ^ String.str (String.sub (hex,Char.ord c mod 16))) path end
  fun fromPath (platform,path) =
    if CharVector.exists (fn c => c = #"\000") path then raise Invalid else
    case platform of
      Posix => if String.isPrefix "/" path then parse ("file://" ^ encode path) else raise Invalid
    | Windows =>
        let val path=String.map (fn #"\\" => #"/" | c => c) path
            val ()=if wtf8 path then () else raise Invalid
        in if drive path then parse ("file:///" ^ encode path)
           else if String.isPrefix "//" path then parse ("file:" ^ encode path) else raise Invalid end
end

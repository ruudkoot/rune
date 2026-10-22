(* Deterministic archive records. gzip is only the Deflate instrument;
   names, modes, clocks, checksums and archive layout are owned by SML. *)
structure BuildArchive =
struct
  open BuildCommon
  type entry={name:string,data:string,mode:int}
  fun bytesLE width (n:IntInf.int) =
    let fun loop 0 _ acc=String.implode (List.rev acc) | loop k n acc=loop (k-1) (IntInf.div (n,256)) (Char.chr (IntInf.toInt (IntInf.mod (n,256)))::acc)
    in need (n>=0,"negative archive integer");loop width n [] end
  fun small width n=bytesLE width (IntInf.fromInt n)
  fun output stream data=BinIO.output (stream,Byte.stringToBytes data)
  fun padded width text=(need (size text<=width,"archive field too long");text ^ String.implode (List.tabulate (width-size text,fn _ => #"\000")))
  fun octal width n=StringCvt.padLeft #"0" (width-1) (Int.fmt StringCvt.OCT n) ^ "\000"
  fun tarHeader {name,data,mode}:string =
    let val (prefix,name)=if size name<=100 then ("",name) else
           let val slashes=List.filter (fn i => String.sub (name,i) = #"/" andalso i<=155 andalso size name-i-1<=100) (List.tabulate (size name,fn i => i))
               val i=case List.rev slashes of first::_ => first | [] => raise Failed ("USTAR filename too long: " ^ name)
           in (String.substring (name,0,i),String.extract (name,i+1,NONE)) end
        val sizeField=StringCvt.padLeft #"0" 11 (Int.fmt StringCvt.OCT (size data)) ^ "\000"
        val base=padded 100 name ^ octal 8 mode ^ octal 8 0 ^ octal 8 0 ^ sizeField ^ octal 12 0 ^ "        " ^ "0" ^ padded 100 "" ^ "ustar\00000" ^ padded 32 "" ^ padded 32 "" ^ padded 16 "" ^ padded 155 prefix ^ padded 12 ""
        val checksum=CharVector.foldl (fn (c,total) => total+Char.ord c) 0 base
        val check=StringCvt.padLeft #"0" 6 (Int.fmt StringCvt.OCT checksum) ^ "\000 "
    in need (size base=512,"invalid USTAR header size");String.substring (base,0,148) ^ check ^ String.extract (base,156,NONE) end
  fun entries top files=sort (fn (a:entry,b:entry) => #name a< #name b) (List.map (fn {name,data,mode}:entry => {name=top ^ "/" ^ name,data=data,mode=mode}) files)
  fun gzip directory prefix level data =
    let val file=prefix ^ ".input" val ()=write (file,data)
        val result=execute directory (prefix ^ ".gzip") 180.0 ["gzip","-" ^ Int.toString level,"--no-name","--stdout",file] (Posix.ProcEnv.environ ())
    in need (#status result=0,"gzip failed: " ^ #errors result);#output result end
  fun tar path top files =
    let val pending=privateDirectory (OS.Path.dir path) ".archive" val raw=pending ^ "/payload.tar" val stream=BinIO.openOut raw
        val total=ref 0
        fun add (entry:entry)=
          let val n=size (#data entry) val padding=(512-n mod 512) mod 512 val zeros=String.implode (List.tabulate (padding,fn _ => #"\000"))
          in output stream (tarHeader entry);output stream (#data entry);output stream zeros;total:= !total+512+n+padding end
        val ()=List.app add (entries top files)
        val tail=1024+(10240-(!total+1024) mod 10240) mod 10240
        val ()=output stream (String.implode (List.tabulate (tail,fn _ => #"\000"))) val ()=BinIO.closeOut stream
        fun compress ()=
          let val result=execute root (pending ^ "/compress") 180.0 ["gzip","-9","--no-name","--stdout",raw] (Posix.ProcEnv.environ ())
              val ()=need (#status result=0,"gzip failed: " ^ #errors result)
              val target=pending ^ "/payload.tar.gz" val ()=write (target,#output result)
          in OS.FileSys.rename {old=target,new=path} end
    in (compress () handle e => (remove pending;raise e));remove pending end
  val crcTable=Vector.tabulate (256,fn n =>
    let fun loop 0 n=n | loop k n=loop (k-1) (if Word32.andb (n,0w1)=0w0 then Word32.>> (n,0w1) else Word32.xorb (Word32.>> (n,0w1),0wxEDB88320))
    in loop 8 (Word32.fromInt n) end)
  fun crc32 data=Word32.notb (CharVector.foldl (fn (c,crc) => Word32.xorb (Word32.>> (crc,0w8),Vector.sub (crcTable,Word32.toInt (Word32.andb (Word32.xorb (crc,Word32.fromInt (Char.ord c)),0wxFF))))) 0wxFFFFFFFF data)
  fun zip path top files =
    let val pending=privateDirectory (OS.Path.dir path) ".archive" val target=pending ^ "/payload.zip" val stream=BinIO.openOut target
        val offset=ref (0:IntInf.int) val central=ref [] : string list ref val index=ref 0
        fun write data=(output stream data;offset:= !offset+IntInf.fromInt (size data))
        fun add (entry:entry) =
          let val ()=index:= !index+1 val name= #name entry val data= #data entry val mode= #mode entry
              val compressed=gzip root (pending ^ "/member-" ^ Int.toString (!index)) 6 data
              val ()=need (size compressed>=18 andalso String.isPrefix "\031\139\008\000" compressed,"unexpected gzip framing")
              val deflate=String.substring (compressed,10,size compressed-18)
              val flags=if CharVector.all (fn c => Char.ord c<128) name then 0 else 2048
              val crc=bytesLE 4 (IntInf.fromLarge (Word32.toLargeInt (crc32 data)))
              val lengths=small 4 (size deflate) ^ small 4 (size data)
              val localOffset= !offset
              val header="PK\003\004" ^ small 2 20 ^ small 2 flags ^ small 2 8 ^ small 2 0 ^ small 2 33 ^ crc ^ lengths ^ small 2 (size name) ^ small 2 0
              val record="PK\001\002" ^ small 2 788 ^ small 2 20 ^ small 2 flags ^ small 2 8 ^ small 2 0 ^ small 2 33 ^ crc ^ lengths ^ small 2 (size name) ^ small 2 0 ^ small 2 0 ^ small 2 0 ^ small 2 0 ^ small 4 (mode*65536) ^ bytesLE 4 localOffset ^ name
          in need (size name<=65535,"ZIP filename too long");write (header ^ name);write deflate;central:=record:: !central end
        fun publish ()=
          let val rows=entries top files val ()=need (length rows<=65535,"ZIP entry count needs ZIP64") val ()=List.app add rows
              val start= !offset val directory=String.concat (List.rev (!central)) val ()=write directory
              val footer="PK\005\006" ^ small 2 0 ^ small 2 0 ^ small 2 (length rows) ^ small 2 (length rows) ^ small 4 (size directory) ^ bytesLE 4 start ^ small 2 0
          in write footer;BinIO.closeOut stream;OS.FileSys.rename {old=target,new=path} end
    in (publish () handle e => (BinIO.closeOut stream;remove pending;raise e));remove pending end
  type member={name:string,kind:char,data:string,link:string}
  fun readTar data =
    let fun cstring source=hd (String.fields (fn c => c = #"\000") source)
        fun octal source=let val source=Substring.string (Substring.dropr (fn c => c = #"\000" orelse Char.isSpace c) (Substring.dropl Char.isSpace (Substring.full source)))
                         in if source="" then 0 else case StringCvt.scanString (Int.scan StringCvt.OCT) source of SOME n => n | NONE => raise Failed "invalid tar integer" end
        fun record text =
          let fun loop i entries=if i>=size text then entries else
                 let val rest=String.extract (text,i,NONE) val split=Substring.position " " (Substring.full rest)
                     val count=integer (Substring.string (#1 split)) val header=Substring.size (#1 split)+1
                     val ()=need (count>header andalso i+count<=size text,"invalid PAX record length")
                     val field=String.substring (text,i+header,count-header-1)
                     val (key,value)=case Substring.position "=" (Substring.full field) of (a,b) => (Substring.string a,Substring.string (Substring.triml 1 b))
                 in loop (i+count) ((key,value)::entries) end
          in loop 0 [] end
        fun lookup key entries fallback=case List.find (fn (name,_) => name=key) entries of SOME (_,v) => v | NONE => fallback
        fun loop at global next longName longLink result =
          if at+512>size data then (need (at=size data,"truncated tar header");List.rev result) else
          let val header=String.substring (data,at,512)
          in if CharVector.all (fn c => c = #"\000") header then List.rev result else
             let val stored=octal (String.substring (header,148,8))
                 val computed=CharVector.foldli (fn (i,c,total) => total+(if i>=148 andalso i<156 then 32 else Char.ord c)) 0 header
                 val ()=need (stored=computed,"tar header checksum differs")
                 val size=octal (String.substring (header,124,12)) val begin=at+512
                 val ()=need (size>=0 andalso begin<=String.size data-size,"truncated tar payload")
                 val payload=String.substring (data,begin,size) val after=begin+size+(512-size mod 512) mod 512
                 val kind=String.sub (header,156)
                 val base=cstring (String.substring (header,0,100))
                 val prefix=if String.substring (header,257,6)="ustar\000" then cstring (String.substring (header,345,155)) else ""
                 val name=if prefix="" then base else prefix ^ "/" ^ base
                 val name=lookup "path" (next @ global) (getOpt (longName,name))
                 val link=lookup "linkpath" (next @ global) (getOpt (longLink,cstring (String.substring (header,157,100))))
             in if kind = #"x" then loop after global (record payload) longName longLink result
                else if kind = #"g" then loop after (record payload @ global) next longName longLink result
                else if kind = #"L" then loop after global next (SOME (cstring payload)) longLink result
                else if kind = #"K" then loop after global next longName (SOME (cstring payload)) result
                else loop after global [] NONE NONE ({name=name,kind=kind,data=payload,link=link}::result) end end
    in loop 0 [] [] NONE NONE [] end

end

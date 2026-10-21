(* Bounded executable-header readers for package admission. Addresses stay
   arbitrary precision until they have been checked against the file size. *)
structure BuildFormats =
struct
  open BuildCommon
  fun uint data be offset width =
    let val ()=need (offset>=0 andalso width>=0 andalso offset<=size data-width,"truncated executable header")
        fun loop i n=if i=width then n else loop (i+1) (n*256+IntInf.fromInt (Char.ord (String.sub (data,offset+(if be then i else width-i-1)))))
    in loop 0 (0:IntInf.int) end
  fun offset data value= (need (value>=0 andalso value<=IntInf.fromInt (size data),"segment runs past the end of the file");IntInf.toInt value)
  fun integer data be at width=offset data (uint data be at width)
  fun slice data at bytes=(need (at>=0 andalso bytes>=0 andalso at<=size data-bytes,"segment runs past the end of the file");String.substring (data,at,bytes))
  fun cstring data at =
    let val ()=need (at>=0 andalso at<size data,"string runs past the end of the file")
        fun stop i=if i>=size data then i else if String.sub (data,i) = #"\000" then i else stop (i+1)
        val text=String.substring (data,at,stop at-at)
    in need (CharVector.all (fn c => Char.ord c<128) text,"non-ASCII executable header string");text end
  type segment={kind:IntInf.int,offset:IntInf.int,address:IntInf.int,bytes:IntInf.int}
  fun elf data =
    let val ()=need (size data>=16 andalso String.isPrefix "\127ELF" data,"not an ELF file")
        val cls=Char.ord (String.sub (data,4)) val endian=Char.ord (String.sub (data,5)) val be=endian=2
        val ()=need ((cls=1 orelse cls=2) andalso (endian=1 orelse endian=2),"not an ELF file")
        val phoff=integer data be (if cls=2 then 32 else 28) (if cls=2 then 8 else 4)
        val entsize=IntInf.toInt (uint data be (if cls=2 then 54 else 42) 2)
        val count=IntInf.toInt (uint data be (if cls=2 then 56 else 44) 2)
        fun segment i =
          let val at=phoff+i*entsize val kind=uint data be at 4
          in if cls=2 then {kind=kind,offset=uint data be (at+8) 8,address=uint data be (at+16) 8,bytes=uint data be (at+32) 8}:segment
             else {kind=kind,offset=uint data be (at+4) 4,address=uint data be (at+8) 4,bytes=uint data be (at+16) 4} end
        val segments=List.tabulate (count,segment)
        val machine=uint data be 18 2
        fun blob (s:segment)=slice data (offset data (#offset s)) (offset data (#bytes s))
        val interpreter=case List.find (fn (s:segment) => #kind s=3) segments of NONE => raise Failed "no interpreter" | SOME s =>
              let val bytes=blob s in if bytes="" then "" else cstring bytes 0 end
        fun address at =case List.find (fn (s:segment) => #kind s=1 andalso #address s<=at andalso at< #address s+ #bytes s) segments of
             NONE => raise Failed "dynamic string address is not in a load segment" | SOME s => offset data (#offset s+at- #address s)
        val needed=case List.find (fn (s:segment) => #kind s=2) segments of NONE => [] | SOME dynamic =>
          let val step=if cls=2 then 16 else 8 val base=offset data (#offset dynamic) val finish=offset data (#offset dynamic+ #bytes dynamic)
              fun loop at strings names =if at+step>finish then (strings,List.rev names) else
                let val tag=uint data be at (step div 2) val value=uint data be (at+step div 2) (step div 2)
                in if tag=0 then (strings,List.rev names) else if tag=5 then loop (at+step) (SOME value) names
                   else if tag=1 then loop (at+step) strings (value::names) else loop (at+step) strings names end
              val (strings,names)=loop base NONE []
          in case strings of NONE => [] | SOME at => let val base=address at in List.map (fn n => cstring data (offset data (IntInf.fromInt base+n))) names end end
    in {class=cls,bigEndian=be,machine=machine,interpreter=interpreter,needed=needed} end
  fun linux data arch =
    let val ()=need (not (String.isPrefix "#!" data),"is a script") val parsed=elf data
        val (cls,be,machine,exact,suffix)=case arch of "x86_64" => (2,false,62,NONE,"/ld-linux-x86-64.so.2")
          | "i686" => (1,false,3,NONE,"/ld-linux.so.2") | "aarch64" => (2,false,183,SOME "/lib/ld-linux-aarch64.so.1","")
          | "ppc64" => (2,true,21,SOME "/lib64/ld64.so.1","") | _ => raise Usage ("unknown Linux architecture " ^ arch)
        val ()=need (#class parsed=cls andalso #bigEndian parsed=be andalso #machine parsed=IntInf.fromInt machine,"is not a " ^ arch ^ " ELF file")
        val interpreter= #interpreter parsed
        val ()=case exact of SOME path => need (interpreter=path,"interpreter is " ^ interpreter ^ ", wanted " ^ path) | NONE => need (String.isSuffix suffix interpreter,"interpreter is " ^ interpreter)
    in List.app (fn name => need (not (String.isPrefix "libgmp" name),"depends on " ^ name)) (#needed parsed) end
  fun windows data arch =
    let val ()=need (not (String.isPrefix "#!" data),"is a script")
        val ()=need (size data>=64 andalso String.isPrefix "MZ" data,"not a PE file")
        val at=integer data false 60 4 val ()=need (at<=size data-6 andalso slice data at 4="PE\000\000","not a PE file")
        val machine=uint data false (at+4) 2 val wanted=if arch="x86_64" then 0x8664 else if arch="i686" then 0x14c else raise Usage ("unknown Windows architecture " ^ arch)
    in need (machine=IntInf.fromInt wanted,"PE machine is 0x" ^ String.map Char.toLower (IntInf.fmt StringCvt.HEX machine) ^ ", wanted 0x" ^ String.map Char.toLower (Int.fmt StringCvt.HEX wanted)) end
end

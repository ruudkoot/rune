(* Adapted from OCaml 4.14.1 Bytes (Xavier Leroy, INRIA 1996) and
 * String (Damien Doligez, INRIA 2014), LGPL 2.1 with linking exception.
 * Complete source and license notices accompany the eventual import. *)
(* Portable operations required by the pinned stdlib string/bytes workloads.
 * Only this fragment is a compatibility layer; storage is a portable Word8Array. *)
structure BenchStdlibText=
struct
 val text=BenchStdlibTextInput.text
 fun for first last f=if first>last then()else(f first;for(first+1)last f)
 fun uppercase c=if c>= #"a"andalso c<= #"z"then Char.chr(Char.ord c-32)else c
 fun space c=c= #" "orelse c= #"\n"orelse c= #"\r"orelse c= #"\t"orelse c= #"\012"
 fun trimBounds length get=
   let fun left i=if i<length andalso space(get i)then left(i+1)else i
       val start=left 0
       fun right i=if i>=start andalso space(get i)then right(i-1)else i
   in(start,right(length-1)-start+1)end
 fun trimString value=
   let val(start,count)=trimBounds(String.size value)(fn i=>String.sub(value,i))
   in if count=String.size value then value else String.substring(value,start,count)end
 fun indexString value wanted=
   let fun search i=if i=String.size value then raise Fail"character not found"
         else if String.sub(value,i)=wanted then i else search(i+1)
   in search 0 end
 fun splitOnChar separator value=
   let fun scan i finish parts=
         if i<0 then String.substring(value,0,finish)::parts
         else if String.sub(value,i)=separator then
           scan(i-1)i(String.substring(value,i+1,finish-i-1)::parts)
         else scan(i-1)finish parts
   in scan(String.size value-1)(String.size value)[]end
 fun appString f value=for 0(String.size value-1)(fn i=>f(String.sub(value,i)))
 fun concatStrings separator values=
   let fun pieces []=[]|pieces[x]=[x]|pieces(x::xs)=x::separator::pieces xs
   in String.concat(pieces values)end
 fun compareStrings(a,b)=case String.compare(a,b)of LESS=> ~1|EQUAL=>0|GREATER=>1
 structure Bytes=
 struct
  type t=Word8Array.array
  val length=Word8Array.length
  fun get array i=Char.chr(Word8.toInt(Word8Array.sub(array,i)))
  fun set array i c=Word8Array.update(array,i,Word8.fromInt(Char.ord c))
  fun ofString value=Word8Array.tabulate(String.size value,fn i=>Word8.fromInt(Char.ord(String.sub(value,i))))
  fun toString array=CharVector.tabulate(length array,fn i=>get array i)
  fun make n c=Word8Array.array(n,Word8.fromInt(Char.ord c))
  fun copy array=Word8Array.tabulate(length array,fn i=>Word8Array.sub(array,i))
  fun blit(source,start,dest,offset,count)=
    if start<0 orelse offset<0 orelse count<0 orelse start+count>length source orelse offset+count>length dest
    then raise Subscript
    else if source=dest andalso offset>start then
      let fun backwards i=if i<0 then()else(Word8Array.update(dest,offset+i,Word8Array.sub(source,start+i));backwards(i-1))
      in backwards(count-1)end
    else for 0(count-1)(fn i=>Word8Array.update(dest,offset+i,Word8Array.sub(source,start+i)))
  fun sub array start count=
    if start<0 orelse count<0 orelse start+count>length array then raise Subscript
    else Word8Array.tabulate(count,fn i=>Word8Array.sub(array,start+i))
  fun cat first second=
    let val size=length first val dest=make(size+length second) #"\000"
        val _=blit(first,0,dest,0,size)
        val _=blit(second,0,dest,size,length second)
    in dest end
  fun concat delimiter arrays=
    let val separatorLength=length delimiter
        fun sumLengths total []=total
          |sumLengths total[a]=length a+total
          |sumLengths total(a::rest)=sumLengths(length a+separatorLength+total)rest
        val dest=make(sumLengths 0 arrays) #"\000"
        fun loop _ []=()
          |loop offset(a::rest)=
            let val _=blit(a,0,dest,offset,length a)
                val next=offset+length a
            in case rest of []=>()|_=>(blit(delimiter,0,dest,next,length delimiter);loop(next+length delimiter)rest)end
        val _=loop 0 arrays
    in dest end
  fun app f array=for 0(length array-1)(fn i=>f(get array i))
  fun map f array=Word8Array.tabulate(length array,fn i=>Word8.fromInt(Char.ord(f(get array i))))
  fun trim array=let val(start,count)=trimBounds(length array)(get array)in sub array start count end
  fun index array wanted=
    let fun search i=if i=length array then raise Fail"character not found"
          else if get array i=wanted then i else search(i+1)
    in search 0 end
  fun contains array wanted=(index array wanted;true)handle Fail _=>false
 end
end

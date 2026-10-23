(* Implements: FOREIGN_MEMORY *)
structure ForeignMemory :> FOREIGN_MEMORY =
struct
  datatype buffer=Buffer of {resource:RuneForeign.resource,length:int}
  datatype direction=Input | Output | InputOutput
  type argument={array:Word8Array.array,offset:int,length:int,direction:direction}
  exception Bounds
  fun raw(Buffer{resource,...})=resource
  fun length(Buffer{length,...})=length
  fun range total offset count=if offset<0 orelse count<0 orelse offset>total orelse count>total-offset then raise Bounds else ()
  fun allocate count=if count<0 then raise Bounds else Buffer{resource=RuneForeign.allocate(Word64.fromInt count),length=count}
  fun release buffer=RuneForeign.release(raw buffer)
  fun read(buffer,offset,count)=(range(length buffer)offset count;RuneForeign.read(raw buffer,Word64.fromInt offset,count))
  fun write(buffer,offset,bytes)=(range(length buffer)offset(size bytes);RuneForeign.write(raw buffer,Word64.fromInt offset,bytes))
  fun fromBytes bytes=let val buffer=allocate(size bytes)
    in (write(buffer,0,bytes);buffer)handle e=>((release buffer handle _=>());raise e) end
  fun slice(buffer,offset,count)=(range(length buffer)offset count;
    Buffer{resource=RuneForeign.view(raw buffer,Word64.fromInt offset,Word64.fromInt count),length=count})
  fun pointer{pointer,length}=if length<0 then raise Bounds else
    Buffer{resource=RuneForeign.view(pointer,0w0,Word64.fromInt length),length=length}
  fun terminated{buffer,unitBytes}=
    if unitBytes<>1 andalso unitBytes<>2 then raise Bounds else
    let fun loop(offset,acc)=
          let val unit=read(buffer,offset,unitBytes)
          in if CharVector.all(fn c=>c= #"\000")unit then String.concat(rev(unit::acc))
             else loop(offset+unitBytes,unit::acc) end
    in loop(0,[]) end
  fun register scope buffer=
    ((ignore(ForeignScope.defer(scope,fn()=>release buffer));buffer)
      handle e=>((release buffer handle _=>());raise e))
  fun withBytes bytes body=ForeignScope.withScope(fn scope=>body(register scope(fromBytes bytes)))
  fun withArrays arguments body=ForeignScope.withScope(fn scope=>
    let val ()=List.app(fn({array,offset,length,...}:argument)=>range(Word8Array.length array)offset length)arguments
        val owners=ref([]:(Word8Array.array*buffer)list)
        fun owner array=case List.find(fn(known,_)=>known=array)(!owners) of SOME(_,buffer)=>buffer
          | NONE=>let val buffer=register scope(allocate(Word8Array.length array))
                       val ()=owners:=(array,buffer):: !owners
                  in buffer end
        (* Register every backing allocation before copy-back actions and
           views, so reverse cleanup first drops views, then copies, then frees. *)
        val ()=List.app(fn({array,...}:argument)=>ignore(owner array))arguments
        fun input({array,offset,length,direction}:argument)=
          if direction=Output then () else write(owner array,offset,
            Byte.bytesToString(Word8ArraySlice.vector(Word8ArraySlice.slice(array,offset,SOME length))))
        fun output({array,offset,length,direction}:argument)=
          if direction=Input then () else Word8Array.copyVec{dst=array,di=offset,
            src=Byte.stringToBytes(read(owner array,offset,length))}
        val ()=List.app input arguments
        val ()=List.app(fn argument=>ignore(ForeignScope.defer(scope,fn()=>output argument)))arguments
        val views=List.map(fn({array,offset,length,...}:argument)=>register scope(slice(owner array,offset,length)))arguments
    in body views end)
end

(* Old-field provenance in format-2 traces. Allocations are streamed into
   packed offset/kind arrays; only fields with stores need history. *)
structure MeasureCheckOld =
struct
  open MeasureCommon
  structure F=MeasureFormat
  fun uint bytes at n =
    let fun loop i value=if i<0 then value else loop (i-1) (value*256+IntInf.fromInt (Word8.toInt (Word8Vector.sub (bytes,at+i))))
    in loop (n-1) 0 end
  fun main [directory] =
    let val alloc=directory ^ "/alloc.bin" val stores=directory ^ "/stores.bin" val graph=directory ^ "/graph.bin"
        val allocSize=OS.FileSys.fileSize alloc val storeSize=OS.FileSys.fileSize stores
        val ()=need (Position.mod (allocSize,16)=0 andalso Position.mod (storeSize,24)=0,"truncated trace record")
        val count=Position.toInt (Position.div (allocSize,16))
        val n=Position.toInt (Position.div (storeSize,24))
        val kinds=Word8Array.array (count,0w0)
        val offsets=Word64Array.array (count,0w0)
        val input=BinIO.openIn alloc
        fun allocation i offset=if i=count then () else
          let val bytes=BinIO.inputN (input,16)
              val kind=Word8Vector.sub (bytes,0)
              val length=uint bytes 4 4
              val fields=if List.exists (fn k => Word8.toInt kind=k) [0,4,10,11,12,13] then 0 else length
              val ()=Word8Array.update (kinds,i,kind)
              val ()=Word64Array.update (offsets,i,Word64.fromLargeInt (IntInf.toLarge offset))
          in allocation (i+1) (offset+fields) end
        val ()=(allocation 0 0 handle e => (BinIO.closeIn input;raise e)) val ()=BinIO.closeIn input
        type store={src:int,field:int,site:int,old:IntInf.int,new:IntInf.int,slot:IntInf.int,sequence:int}
        val input=BinIO.openIn stores
        fun readStores i acc=if i=n then List.rev acc else
          let val bytes=BinIO.inputN (input,24)
              val src=IntInf.toInt (uint bytes 4 4) val field=IntInf.toInt (uint bytes 16 4)
              val ()=need (src>=0 andalso src<count,"store source outside allocation trace")
              val offset=IntInf.fromLarge (Word64.toLargeInt (Word64Array.sub (offsets,src)))
              val row={src=src,field=field,site=Word8.toInt (Word8Vector.sub (bytes,20)),old=uint bytes 12 4,new=uint bytes 8 4,slot=offset+IntInf.fromInt field,sequence=i}:store
          in readStores (i+1) (row::acc) end
        val rows=(readStores 0 [] handle e => (BinIO.closeIn input;raise e)) val ()=BinIO.closeIn input
        val ordered=sorted (fn (a:store,b:store) => #slot a< #slot b orelse (#slot a= #slot b andalso #sequence a< #sequence b)) rows
        val fd=Posix.FileSys.openf (graph,Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
        fun initial slot =
          let val _=Posix.IO.lseek (fd,Position.fromLarge (IntInf.toLarge (slot*4)),Posix.IO.SEEK_SET)
              val bytes=Posix.IO.readVec (fd,4)
          in need (Word8Vector.length bytes=4,"graph field outside allocation graph");uint bytes 0 4 end
        val bad=ref 0 val firstBad=ref 0 val examples=ref [] : (store*IntInf.int*bool) list ref
        fun compare [] _ _=()
          | compare ((row:store)::rest) previous value=
             let val first=previous<>SOME (#slot row)
                 val expected=if first then initial (#slot row) else value
                 val ()=if #old row=expected then () else
                   (bad:= !bad+1;if first then firstBad:= !firstBad+1 else ();
                    if length (!examples)<5 then examples:= !examples @ [(row,expected,first)] else ())
             in compare rest (SOME (#slot row)) (#new row) end
        val ()=(compare ordered NONE 0 handle e => (Posix.IO.close fd;raise e)) val ()=Posix.IO.close fd
    in if n=0 then say (directory ^ ": no stores\n") else
        (say (F.format "%s: %d stores, old_id agrees on %d (%.4f%%); disagreements %d (%d at a field's first store, i.e. against graph.bin)\n"
              [F.Text directory,F.Integer (IntInf.fromInt n),F.Integer (IntInf.fromInt (n- !bad)),F.Decimal (100.0*Real.fromInt (n- !bad)/Real.fromInt n),F.Integer (IntInf.fromInt (!bad)),F.Integer (IntInf.fromInt (!firstBad))]);
         List.app (fn (row:store,expected,first) => say (F.format "  store src %d (%s) field %d site %d: old %d, expected %d (%s)\n"
                 [F.Integer (IntInf.fromInt (#src row)),F.Text (Int.toString (Word8.toInt (Word8Array.sub (kinds,#src row)))),F.Integer (IntInf.fromInt (#field row)),F.Integer (IntInf.fromInt (#site row)),
                  F.Integer (#old row),F.Integer expected,F.Text (if first then "graph" else "previous store")])) (!examples));0 end
    | main _=raise Usage "checkold TRACE_DIR"
end

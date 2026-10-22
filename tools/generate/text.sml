(* Small deterministic text operations used by the retired AWK transforms.
   Patterns are compiled by the same SML matcher used for terminal fixtures. *)
structure GenerateText =
struct
  open MeasureCommon
  fun replace source key replacement =
    if key="" then raise Failed "empty generator replacement" else
    let fun loop text acc=let val (a,b)=Substring.position key (Substring.full text)
          in if Substring.isEmpty b then String.concat (List.rev (text::acc))
             else loop (Substring.string (Substring.triml (size key) b)) (replacement::Substring.string a::acc) end
    in loop source [] end
  fun substituteUsing find pattern transform text =
    let val expression=TerminalPattern.compile false pattern
        fun loop start acc=case find expression text start of NONE => String.concat (List.rev (String.extract (text,start,NONE)::acc))
          | SOME (first,last) => (need (last>first,"empty generator pattern match");loop last (transform (String.substring (text,first,last-first))::String.substring (text,start,first-start)::acc))
    in loop 0 [] end
  fun substitute pattern transform text=substituteUsing TerminalPattern.find pattern transform text
  fun substituteEnd pattern transform text=substituteUsing TerminalPattern.findWholeEnd pattern transform text
  fun matches pattern text=isSome (TerminalPattern.find (TerminalPattern.compile false pattern) text 0)
  fun distinct values=List.foldl (fn (v,old) => if List.exists (fn x => x=v) old then old else old @ [v]) [] values
  fun required file=(need (exists file andalso not (isDir file),"missing generator input: " ^ file);read file)
  fun dataLines file=List.filter (fn line => let val line=trim line in line<>"" andalso not (String.isPrefix "#" line) end) (lines (required file))
  fun splitAt needle source =let val (a,b)=Substring.position needle (Substring.full source)
       in if Substring.isEmpty b then NONE else SOME (Substring.string a,Substring.string (Substring.triml (size needle) b)) end
  fun prefix word text=if String.isPrefix word text then String.extract (text,size word,NONE) else text
  fun lineMap transform text =
    let val rows=String.fields (fn c => c = #"\n") text
        val rows=if String.isSuffix "\n" text then List.take (rows,length rows-1) else rows
    in String.concat (List.map (fn line => transform line ^ "\n") rows) end
  fun filterLines keep source =
    let val rows=String.fields (fn c => c = #"\n") source
        val rows=if String.isSuffix "\n" source then List.take (rows,length rows-1) else rows
    in String.concat (List.map (fn row => row ^ "\n") (List.filter keep rows)) end
  fun privateDirectory parent label =
    let val ()=mkdirs parent
        fun attempt remaining=if remaining=0 then raise Failed "cannot allocate a private generator directory" else
          let val reservation=OS.FileSys.tmpName ()
              val directory=parent ^ "/" ^ label ^ "-" ^ OS.Path.file reservation
              val made=(OS.FileSys.mkDir directory;true) handle OS.SysErr _ => false
              val ()=OS.FileSys.remove reservation
          in if made then directory else attempt (remaining-1) end
    in attempt 16 end
  fun atomic file text =
    let val ()=mkdirs (OS.Path.dir file)
        val reservation=OS.FileSys.tmpName ()
        val pending=file ^ "." ^ OS.Path.file reservation ^ ".pending"
        fun cleanup ()=(rmTree pending;rmTree reservation)
    in (write (pending,text);OS.FileSys.rename {old=pending,new=file};cleanup ()) handle e => (cleanup ();raise e) end
end

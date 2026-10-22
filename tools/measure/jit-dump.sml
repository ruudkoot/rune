(* JIT index/role bytes and exclusive callgrind counts. objdump is only the
   machine-instruction decoder; association, aggregation and reports are SML. *)
structure MeasureJitDump =
struct
  open MeasureCommon
  structure F=MeasureFormat
  type func={seq:string,id:int,tier:int,address:IntInf.int,bytes:int,locals:int,arity:int,reps:string,homes:string,name:string}
  type part={offset:int,pc:int,role:string,opcode:string}
  type instruction={offset:int,pc:int option,role:string,opcode:string,source:string,text:string,bytes:int}
  fun hex s=case StringCvt.scanString (IntInf.scan StringCvt.HEX) s of SOME n => n | NONE => raise Failed ("invalid hexadecimal address: " ^ s)
  fun index directory =List.map (fn line => case tabs line of [seq,id,tier,address,bytes,locals,arity,reps,homes,name] =>
       {seq=seq,id=integer id,tier=integer tier,address=hex address,bytes=integer bytes,locals=integer locals,arity=integer arity,reps=reps,homes=homes,name=name}:func
     | _ => raise Failed "invalid JIT index row") (lines (read (directory ^ "/index.tsv")))
  fun parts directory seq=List.map (fn line => case tabs line of offset::pc::role::rest =>
       {offset=integer offset,pc=integer pc,role=role,opcode=if null rest then "" else hd rest}:part | _ => raise Failed "invalid JIT part row") (lines (read (directory ^ "/" ^ seq ^ ".lst")))
  fun machine directory =
    let fun aarch64 file=if not (String.isPrefix "jit-" file andalso String.isSuffix ".dump" file) then false else
          let val stream=BinIO.openIn (directory ^ "/" ^ file)
              val data=BinIO.inputN (stream,16) before BinIO.closeIn stream
          in Word8Vector.length data=16 andalso Word8.toInt (Word8Vector.sub (data,12))=183 andalso
             List.all (fn i => Word8Vector.sub (data,i)=0w0) [13,14,15] end
    in if List.exists aarch64 (entries directory) then "aarch64" else "i386:x86-64" end
  fun disassemble directory (row:func) arch =
    let val file=directory ^ "/" ^ #seq row ^ ".bin"
        val args=tool "OBJDUMP" "objdump" @ ["-D","-b","binary","-m",arch] @ (if arch="aarch64" then [] else ["-M","intel"])
                     @ ["--adjust-vma=0x" ^ String.map Char.toLower (IntInf.fmt StringCvt.HEX (#address row)),file]
        val output=successful (execute root (directory ^ "/" ^ #seq row ^ "-objdump") args)
        val instructions=ref [] : (int*string*int) list ref
        fun byte token=size token=2 andalso CharVector.all Char.isHexDigit token
        fun line line =
          let val (address,rest)=Substring.position ":" (Substring.full line)
              val address=trim (Substring.string address)
          in if address="" orelse not (CharVector.all Char.isHexDigit address) orelse Substring.isEmpty rest then () else
             let val rest=trim (Substring.string (Substring.triml 1 rest))
                 fun bytes at count =
                   let val remaining=String.extract (rest,at,NONE)
                       val prefix=Substring.string (Substring.takel (not o Char.isSpace) (Substring.full remaining))
                   in if prefix="" orelse not (byte prefix) then (count,trim remaining)
                      else let val at=at+size prefix
                               val space=size (Substring.string (Substring.takel Char.isSpace (Substring.full (String.extract (rest,at,NONE)))))
                           in bytes (at+space) (count+1) end end
                 val (n,text)=if arch="aarch64" then
                        let val words=String.tokens Char.isSpace rest val token=if null words then "" else hd words
                        in if size token=8 andalso CharVector.all Char.isHexDigit token then (4,trim (String.extract (rest,8,NONE))) else (0,"") end
                      else bytes 0 0
                 val offset=IntInf.toInt (hex address- #address row)
             in if n=0 then () else if text="" then
                   (case !instructions of [] => () | (offset,text,bytes)::rest => instructions:=(offset,text,bytes+n)::rest)
                else instructions:=(offset,text,n):: !instructions end end
        val ()=List.app line (lines output)
    in List.rev (!instructions) end
  fun load directory (row:func) arch =
    let val all=parts directory (#seq row)
        fun one (offset,text,bytes) : instruction =
          let val prior=List.filter (fn (p:part) => #offset p<=offset) all
              val part=if null prior then NONE else SOME (List.last prior)
              val source=case part of NONE => "" | SOME p => #opcode p
              val opName=case String.tokens Char.isSpace source of [] => "" | first::_ => first
          in {offset=offset,text=text,bytes=bytes,pc=Option.map (fn (p:part) => #pc p) part,role=case part of NONE => "body" | SOME p => #role p,opcode=opName,source=source} end
    in List.map one (disassemble directory row arch) end
  fun wanted names (row:func)=null names orelse List.exists (fn name => name= #seq row orelse name= #name row orelse name=Int.toString (#id row)) names
  fun pc (NONE)="None" | pc (SOME n)=Int.toString n
  fun show directory names =
    let val arch=machine directory
        fun one (row:func)=
          let val ()=say (F.format "# %s function %d %s, tier %d, at %x, %d bytes, %d registers (arity %d), representations %s, homes %s\n"
                 [F.Text (#seq row),F.Integer (IntInf.fromInt (#id row)),F.Text (#name row),F.Integer (IntInf.fromInt (#tier row)),F.Integer (#address row),
                  F.Integer (IntInf.fromInt (#bytes row)),F.Integer (IntInf.fromInt (#locals row)),F.Integer (IntInf.fromInt (#arity row)),F.Text (#reps row),F.Text (#homes row)])
              val last=ref NONE : (int option*string) option ref
          in List.app (fn (i:instruction) =>
                (if !last=SOME (#pc i,#role i) then () else (say ("#   " ^ #source i ^ "  [" ^ #role i ^ "]\n");last:=SOME (#pc i,#role i));
                 say (F.format "%6d  %6s  %-9s  %s\n" [F.Integer (IntInf.fromInt (#offset i)),F.Text (pc (#pc i)),F.Text (#role i),F.Text (#text i)]))) (load directory row arch) end
    in List.app one (List.filter (wanted names) (index directory));0 end
  fun lookup key rows=MeasureProfile.weight key rows
  fun add counts order key value=
    (if List.exists (fn old => old=key) (!order) then () else order:= !order @ [key];MeasureProfile.addWeight counts key value)
  fun ranked counts order=sorted (fn (a,b) => lookup a counts>lookup b counts) order
  fun roles directory =
    let val rows=index directory val arch=machine directory
        val ins=ref [] val bytes=ref [] val order=ref []
        val ()=List.app (fn row => List.app (fn (i:instruction) =>
              (add ins order (#role i) 1;add bytes order (#role i) (IntInf.fromInt (#bytes i)))) (load directory row arch)) rows
        val totalIns=List.foldl (fn ((_,n),total) => total+n) 0 (!ins)
        val totalBytes=List.foldl (fn ((_,n),total) => total+n) 0 (!bytes)
        fun float n=Real.fromLargeInt (IntInf.toLarge n)
        val ()=say (Int.toString (length rows) ^ " functions, " ^ intText totalIns ^ " machine instructions, " ^ intText totalBytes ^ " bytes\n")
    in List.app (fn role => say (F.format "%-10s %9d bytes %5.1f%%  %8d instructions %5.1f%%\n"
                [F.Text role,F.Integer (lookup role (!bytes)),F.Decimal (100.0*float (lookup role (!bytes))/float totalBytes),
                 F.Integer (lookup role (!ins)),F.Decimal (100.0*float (lookup role (!ins))/float totalIns)])) (ranked (!bytes) (!order));0 end
  fun callgrind file =
    let val previous=ref (0:IntInf.int) val positions=ref 1 val skip=ref false
        val counts=ref [] : (IntInf.int*IntInf.int) list ref
        fun address token=if String.isPrefix "0x" token then hex token else if token="*" then !previous
               else if String.isPrefix "+" token orelse String.isPrefix "-" token then
                  let val tail=String.extract (token,1,NONE) val value=if String.isPrefix "0x" tail then hex tail else MeasureMMU.natural tail
                  in if String.sub (token,0) = #"+" then !previous+value else !previous-value end
               else MeasureMMU.natural token
        fun line line =if String.isPrefix "positions:" line then positions:=length (String.tokens Char.isSpace line)-1
            else if line="" orelse not (Char.contains "0123456789+-*" (String.sub (line,0))) then
                 (if String.isPrefix "calls=" line then skip:=true else ())
            else let val fields=String.tokens Char.isSpace line val addr=address (hd fields)
                     val ()=previous:=addr
                 in if !skip then skip:=false else if length fields> !positions then counts:=(addr,MeasureMMU.natural (List.nth (fields,!positions))):: !counts else () end
        val ()=List.app line (lines (read file))
        val ordered=sorted (fn ((a,_),(b,_)) => a<b) (!counts)
        fun merge [] acc=List.rev acc
          | merge ((a,n)::rest) ((b,m)::done)=if a=b then merge rest ((b,m+n)::done) else merge rest ((a,n)::(b,m)::done)
          | merge (row::rest) []=merge rest [row]
        val values=Vector.fromList (merge ordered [])
        fun at key=
          let fun loop lo hi=if lo=hi then 0 else let val mid=(lo+hi) div 2 val (address,n)=Vector.sub (values,mid)
                 in if key=address then n else if key<address then loop lo mid else loop (mid+1) hi end
          in loop 0 (Vector.length values) end
        val total=Vector.foldl (fn ((_,n),total) => total+n) 0 values
    in (at,total) end
  fun stores text=
    let val (mnemonic,rest)=Substring.position " " (Substring.full text)
        val mnemonic=Substring.string mnemonic val operands=Substring.string rest
    in if List.exists (fn prefix => String.isPrefix prefix mnemonic) ["str","stp","stur"] then true
       else if List.exists (fn prefix => String.isPrefix prefix mnemonic) ["cmp","test","j","call","lea","nop","push","ucomi"] then String.isPrefix "push" mnemonic
       else String.isSubstring "[" (hd (fields #"," operands)) end
  fun key by (i:instruction)=if by="store" then (if stores (#text i) then "stores" else "other")
        else if by="role" then #role i else if by="op" then #opcode i else #opcode i ^ "/" ^ #role i
  fun counted file directory by listing =
    let val (at,total)=callgrind file val arch=machine directory
        val counts=ref [] val order=ref []
        val ()=List.app (fn row:func => List.app (fn i:instruction =>
             let val n=at (#address row+IntInf.fromInt (#offset i))
                 val ()=case listing of SOME name => if name= #seq row orelse name= #name row then
                        say (F.format "%12d  %6d %6s %-10s %-9s %s\n" [F.Integer n,F.Integer (IntInf.fromInt (#offset i)),F.Text (pc (#pc i)),F.Text (#opcode i),F.Text (#role i),F.Text (#text i)]) else () | NONE => ()
             in if n=0 then () else add counts order (key by i) n end) (load directory row arch)) (index directory)
    in (!counts,!order,total) end
  fun totals counts=List.foldl (fn ((_,n),total) => total+n) 0 counts
  fun float n=Real.fromLargeInt (IntInf.toLarge n)
  fun countArgs (file::directory::args) =
    let val by=ref "role" val calls=ref NONE val listing=ref NONE
        fun parse []=() | parse ("--by"::v::rest)=(by:=v;parse rest) | parse ("--calls"::v::rest)=(calls:=SOME (decimal v);parse rest)
          | parse ("--list"::v::rest)=(listing:=SOME v;parse rest) | parse _=raise Usage "jit-dump --callgrind FILE DIR [--by MODE] [--calls N] [--list NAME]"
        val ()=parse args val (counts,order,process)=counted file directory (!by) (!listing) val jit=totals counts
        val calls=case !calls of SOME n => if Real.== (n,0.0) then NONE else SOME n | NONE => NONE
        val ()=say (F.format "the compiled code: %d of the process's %d instructions (%.1f%%)\n" [F.Integer jit,F.Integer process,F.Decimal (100.0*float jit/float (IntInf.max (1,process)))])
        val ()=List.app (fn key => let val n=lookup key counts
                in say (F.format "%-24s %14d  %5.1f%%" [F.Text key,F.Integer n,F.Decimal (100.0*float n/float (IntInf.max (1,jit)))]
                     ^ (case calls of NONE => "" | SOME calls => F.format "  %8.2f per call" [F.Decimal (float n/calls)]) ^ "\n") end) (ranked counts order)
    in case calls of NONE => 0 | SOME calls => (say (F.format "%-24s %14d  100.0%%  %8.2f per call\n" [F.Text "total",F.Integer jit,F.Decimal (float jit/calls)]);0) end
    | countArgs _=raise Usage "jit-dump --callgrind FILE DIR"
  fun diff (first::second::calls::rest)=
    let val calls=decimal calls val ()=need (not (Real.== (calls,0.0)),"diff requires nonzero calls")
        val by=case rest of [] => "role" | first::_ => first
        val (a,oa,ta)=counted (first ^ "/callgrind.out") (first ^ "/dump") by NONE
        val (b,ob,tb)=counted (second ^ "/callgrind.out") (second ^ "/dump") by NONE
        val keys=oa @ List.filter (fn key => not (List.exists (fn other => other=key) oa)) ob
        fun difference key=lookup key b-lookup key a
        val keys=sorted (fn (a,b) => difference a>difference b) keys
        val jit=totals b-totals a
        val ()=List.app (fn key => let val n=difference key
             in if float (IntInf.abs n)/calls<0.005 then () else say (F.format "%-24s %8.2f per call  %5.1f%%\n"
                      [F.Text key,F.Decimal (float n/calls),F.Decimal (if jit=0 then 0.0 else 100.0*float n/float jit)]) end) keys
    in say (F.format "%-24s %8.2f per call in the compiled code; %.2f in the whole process\n" [F.Text "total",F.Decimal (float jit/calls),F.Decimal (float (tb-ta)/calls)]);0 end
    | diff _=raise Usage "jit-dump --diff RUN1 RUN2 CALLS [MODE]"
  fun main ("--roles"::directory::_)=roles directory
    | main ("--callgrind"::args)=countArgs args
    | main ("--diff"::args)=diff args
    | main (directory::names)=show directory names
    | main _=raise Usage "jit-dump DIR [FUNCTION...] | --roles DIR | --callgrind FILE DIR | --diff RUN1 RUN2 CALLS"
end

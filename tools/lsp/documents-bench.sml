(* Paired document-index measurements; validation and hashes are untimed. *)
structure LspDocumentsBench =
struct
  structure M=LspPosition
  exception Failed of string
  fun hash text=Hex.fromBytes (Sha256.digest text)
  fun write (file,text)=let val out=TextIO.openOut file in TextIO.output (out,text);TextIO.closeOut out end
  fun sample label repetition phase action =
    let val stats=Runtime.stats ()
        val cpu=Timer.startCPUTimer ()
        val start=Runtime.clock ()
        val result=action ()
        val wall=Time.- (Runtime.clock (),start)
        val used=Timer.checkCPUTimer cpu
        val afterStats=Runtime.stats ()
        val value=Json.Object [("fixture",Json.String label),("repetition",Json.int repetition),("phase",Json.String phase),
          ("wall_us",Json.Number (LargeInt.toString (Time.toMicroseconds wall))),
          ("cpu_us",Json.Number (LargeInt.toString (Time.toMicroseconds (Time.+ (#usr used,#sys used))))),
          ("allocated_bytes",Json.int (#bytes afterStats- #bytes stats)),
          ("allocated_objects",Json.int (#objects afterStats- #objects stats)),
          ("instructions",Json.int (#instructions afterStats- #instructions stats))]
    in (result,value) end
  fun run {out,repetitions,warmup,machine} =
    let val ()=if repetitions<1 orelse repetitions>1000 orelse warmup<0 orelse warmup>100 then raise Failed "invalid repetition count" else ()
        val ()=if OS.FileSys.access (out,[]) then raise Failed "result directory already exists" else OS.FileSys.mkDir out
        val stream=TextIO.openOut (out ^ "/samples.jsonl")
        val fixtures=[("ascii-line-100k",CharVector.tabulate (100000,fn _ => #"a")),
          ("ascii-lines-100k",String.concat (List.tabulate (4000,fn _ => "abcdefghijklmnopqrstuvwx\n"))),
          ("unicode-line-100k",String.concat (List.tabulate (20000,fn _ => "a\240\144\144\128"))),
          ("ascii-line-1m",CharVector.tabulate (1048576,fn _ => #"a"))]
        fun fixture (label,text) =
          let val (old,cold)=sample label 0 "cold-index" (fn () => M.make text)
              val ()=TextIO.output (stream,Json.encode cold ^ "\n")
              val at=size text div 2
              val expected=String.substring (text,0,at) ^ "x" ^ String.extract (text,at+1,NONE)
              val oracle=M.make expected
              fun full ()=M.make (String.substring (text,0,at) ^ "x" ^ String.extract (text,at+1,NONE))
              fun incremental ()=M.edit (old,at,at+1,"x")
              fun measure (repetition,phase,action) =
                let val (result,value)=sample label repetition phase action
                    val ()=if M.text result=expected then () else raise Failed "edit oracle differs"
                    val ()=List.app (fn encoding =>
                      if M.position (result,encoding,at)=M.position (oracle,encoding,at) then () else raise Failed "position oracle differs")
                      [LspProtocol.Utf8,LspProtocol.Utf16,LspProtocol.Utf32]
                in if repetition<0 then () else TextIO.output (stream,Json.encode value ^ "\n") end
              fun iteration repetition=if repetition mod 2=0 then
                (measure (repetition,"full-index",full);measure (repetition,"incremental-edit",incremental))
                else (measure (repetition,"incremental-edit",incremental);measure (repetition,"full-index",full))
              val ()=List.app (fn i => iteration (~i-1)) (List.tabulate (warmup,fn i => i))
              val ()=List.app iteration (List.tabulate (repetitions,fn i => i))
          in Json.Object [("name",Json.String label),("bytes",Json.int (size text)),("sha256",Json.String (hash text))] end
        val fixtures=List.map fixture fixtures
        val ()=TextIO.closeOut stream
        val metadata=Json.Object [("schema",Json.String "runelsp-document-bench-v1"),("compiler_version",Json.String Config.version),
          ("compiler_identity",Json.String Config.identity),("vm_version",Json.String Runtime.version),
          ("machine",Json.String machine),("repetitions",Json.int repetitions),("warmup",Json.int warmup),
          ("fixtures",Json.Array fixtures),("timing_scope",Json.String "text edit and position-index update; excludes validation/hashes")]
    in write (out ^ "/complete.json",Json.encodeIndented 2 metadata ^ "\n") end
  fun main args =
    let fun natural value=if value<>"" andalso CharVector.all Char.isDigit value then
          (case Int.fromString value of SOME n => n | NONE => raise Failed "integer out of range")
          else raise Failed "expected a nonnegative integer"
        fun parse ([],out,repetitions,warmup,machine) =
          (case out of SOME out => {out=out,repetitions=repetitions,warmup=warmup,machine=machine} | NONE => raise Failed "--out is required")
          | parse ("--out"::value::rest,_,repetitions,warmup,machine)=parse (rest,SOME value,repetitions,warmup,machine)
          | parse ("--repetitions"::value::rest,out,_,warmup,machine)=
              parse (rest,out,natural value,warmup,machine)
          | parse ("--warmup"::value::rest,out,repetitions,_,machine)=
              parse (rest,out,repetitions,natural value,machine)
          | parse ("--machine"::value::rest,out,repetitions,warmup,_)=parse (rest,out,repetitions,warmup,value)
          | parse _=raise Failed "usage: --out DIR [--repetitions N] [--warmup N] [--machine TEXT]"
    in run (parse (args,NONE,20,3,"unspecified"));OS.Process.success end
    handle e => (TextIO.output (TextIO.stdErr,"document benchmark failed: " ^
      (case e of Failed message => message | _ => General.exnMessage e) ^ "\n");OS.Process.failure)
end

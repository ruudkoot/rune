(* Paired batch/editor parsing, including lexing and the complete AST bridge. *)
structure LspSyntaxBench =
struct
  exception Failed of string
  fun read path=let val input=TextIO.openIn path in TextIO.inputAll input before TextIO.closeIn input end
  fun hash text=Hex.fromBytes (Sha256.digest text)
  fun sample action =
    let val stats=Runtime.stats ()
        val timer=Timer.startCPUTimer ()
        val start=Runtime.clock ()
        val result=action ()
        val wall=Time.toMicroseconds (Time.- (Runtime.clock (),start))
        val cpu=Timer.checkCPUTimer timer
        val afterStats=Runtime.stats ()
    in (result,[("wall_us",Json.Number (LargeInt.toString wall)),
      ("cpu_us",Json.Number (LargeInt.toString (Time.toMicroseconds (Time.+ (#usr cpu,#sys cpu))))),
      ("allocated_bytes",Json.int (#bytes afterStats- #bytes stats)),
      ("instructions",Json.int (#instructions afterStats- #instructions stats))]) end
  fun run {out,repetitions,warmup,machine} =
    let val ()=if OS.FileSys.access (out,[]) then raise Failed "output directory already exists" else OS.FileSys.mkDir out
        val stream=TextIO.openOut (out ^ "/samples.jsonl")
        fun generated n=String.concat (List.tabulate (n,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "+1\n"))
        val fixtures=[("small",read "tests/lsp/fixtures/small.sml"),
          ("fixity",read "tests/lsp/fixtures/fixity.sml"),
          ("compiler-parser",read "lib/compiler/frontend/parser.sml"),
          ("generated-1000",generated 1000),("generated-10000",generated 10000)]
        fun editor text=CompilerSyntax.parse {file="bench.sml",text=text,mode=Source.Ascii,orPatterns=false,fixity=Fixity.initial}
        fun batch text=CompilerSession.owned (fn () => Parser.parseFile (Source.fromString ("bench.sml",text)))
        fun full text=CompilerSession.owned (fn () => CompilerSyntax.bridge (editor text))
        fun fixture (name,text)=
          let val initial=CompilerSession.owned (fn () => editor text)
              val ()=if null (CompilerSyntax.problems initial) then () else raise Failed (name ^ ": fixture rejected")
              val edited=text ^ "\n"
              val expected=SyntaxAst.shape (batch edited)
              fun incremental ()=CompilerSession.owned (fn () =>
                CompilerSyntax.bridge (CompilerSyntax.edit (initial,{start=size text,stop=size text,text="\n",fixity=Fixity.initial})))
              fun measure (repetition,phase,action)=
                let val (program,fields)=sample action
                    val ()=if SyntaxAst.shape program=expected then () else raise Failed (name ^ ": structural oracle differs")
                in if repetition<0 then () else TextIO.output (stream,Json.encode (Json.Object
                  (("fixture",Json.String name) :: ("repetition",Json.int repetition) :: ("phase",Json.String phase) :: fields)) ^ "\n") end
              fun iteration i=if i mod 2=0 then
                (measure (i,"batch",fn () => batch edited);measure (i,"editor-full",fn () => full edited);measure (i,"editor-edit",incremental))
                else (measure (i,"editor-edit",incremental);measure (i,"editor-full",fn () => full edited);measure (i,"batch",fn () => batch edited))
              val ()=List.app (fn i => iteration (~i-1)) (List.tabulate (warmup,fn i => i))
              val ()=List.app iteration (List.tabulate (repetitions,fn i => i))
          in Json.Object [("name",Json.String name),("bytes",Json.int (size text)),("sha256",Json.String (hash text))] end
        val fixtures=List.map fixture fixtures
        val ()=TextIO.closeOut stream
        val metadata=Json.Object [("schema",Json.String "runelsp-syntax-bench-v1"),("compiler_version",Json.String Config.version),
          ("compiler_identity",Json.String Config.identity),("machine",Json.String machine),
          ("repetitions",Json.int repetitions),("warmup",Json.int warmup),("fixtures",Json.Array fixtures),
          ("scope",Json.String "source/index construction, lexing, parsing and required compiler AST bridge; fresh compiler owner for every phase"),
          ("edit",Json.String "append one newline at EOF; same original snapshot for every measured edit"),
          ("oracle",Json.String "full constructor/scalar/span traversal compared with fresh batch parse, outside timing")]
        val output=TextIO.openOut (out ^ "/complete.json")
    in TextIO.output (output,Json.encodeIndented 2 metadata ^ "\n");TextIO.closeOut output end
  fun main args =
    let fun integer value=if value<>"" andalso CharVector.all Char.isDigit value then
          (case Int.fromString value of SOME n => n | NONE => raise Failed "integer out of range") else raise Failed "expected a nonnegative integer"
        fun parse ([],SOME out,repetitions,warmup,machine)=
              if repetitions<1 orelse repetitions>1000 orelse warmup>100 then raise Failed "invalid repetition count"
              else {out=out,repetitions=repetitions,warmup=warmup,machine=machine}
          | parse ("--out"::value::rest,_,r,w,m)=parse (rest,SOME value,r,w,m)
          | parse ("--repetitions"::value::rest,o',_,w,m)=parse (rest,o',integer value,w,m)
          | parse ("--warmup"::value::rest,o',r,_,m)=parse (rest,o',r,integer value,m)
          | parse ("--machine"::value::rest,o',r,w,_)=parse (rest,o',r,w,value)
          | parse _=raise Failed "usage: --out DIR [--repetitions N] [--warmup N] [--machine TEXT]"
    in run (parse (args,NONE,20,3,"unspecified"));OS.Process.success end
    handle e => (TextIO.output (TextIO.stdErr,"syntax benchmark failed: " ^
      (case e of Failed message => message | _ => General.exnMessage e) ^ "\n");OS.Process.failure)
end

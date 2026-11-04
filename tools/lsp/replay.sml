(* A build through the real server, from the client's side: the first check,
   then edits, each followed by a pull of its diagnostics and a hover, every
   latency from the request's dispatch. tests/lsp/project-replay.sml holds a
   server to a fixed list of answers; this one measures, and a failed request
   is a sample rather than the end of the run.

   Usage: rune-lsp-replay VM SERVER ROOT LIB BUILD SOURCE OUT.json LINE CHARACTER
            [--comments N] [--body N OLD NEW] [--limit KIND SECONDS]...

   BUILD is the target, or - for a file's discovery. LINE and CHARACTER are a
   position in SOURCE to hover and complete. --comments N appends a comment at
   the end of SOURCE, N times, a different one each time. --body N OLD NEW
   replaces the first OLD by NEW with $N made the repetition: a body edit. The
   summary on standard output gives each kind's nearest-rank p50 and p95, which
   is the 19th of 20. --limit fails the run where a kind's p95 is over
   SECONDS, or a request of it failed: D28's targets (comment 0.25, hover
   0.05, edit-hover 0.05; docs/language-server.md, The scale target).
   RUNE_LSP_REPLAY_TIMEOUT: seconds for a response. *)
structure RuneLspReplay =
struct
  structure C=RuneLspTestClient
  fun object fields=Json.Object fields
  fun read file=let val input=BinIO.openIn file
    in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun write (file,text)=let val output=TextIO.openOut file
    in TextIO.output (output,text);TextIO.closeOut output end
  fun envInt (name,default)=case OS.Process.getEnv name of NONE => default | SOME value => getOpt (Int.fromString value,default)
  fun abbreviate value=
    let val text=Json.encode value
    in if size text<=600 then text else String.substring (text,0,600) ^ "...(" ^ Int.toString (size text) ^ " bytes)" end
  fun substitute (text,old,new)=
    let val (front,found)=Substring.position old (Substring.full text)
    in if Substring.isEmpty found then raise Fail ("no such text: " ^ old)
       else Substring.string front ^ new ^ String.extract (text,Substring.size front+size old,NONE) end
  fun expand (text,n)=String.concatWith (Int.toString n) (let
        fun split (acc,current,i)=if i>=size text then List.rev (String.implode (List.rev current)::acc)
          else if i+1<size text andalso String.sub (text,i)= #"$" andalso String.sub (text,i+1)= #"N"
          then split (String.implode (List.rev current)::acc,[],i+2)
          else split (acc,String.sub (text,i)::current,i+1)
      in split ([],[],0) end)
  fun sort xs=
    let fun insert (x,[])=[x] | insert (x,y::rest)=if Real.<= (x,y) then x::y::rest else y::insert (x,rest)
    in List.foldl insert [] xs end
  fun percentile (values,p)=List.nth (values,Int.max (0,Int.min (length values-1,(length values*p) div 100-1)))
  fun run (vm,server,root,lib,build,source,out,line,character,comments,body,limits) =
    let val root=OS.FileSys.fullPath root
        fun uri path=LspUri.original (LspUri.fromPath (LspUri.Posix,path))
        val document=object [("uri",Json.String (uri source))]
        val client=C.start (vm,[server,"--stdio","--lib",lib])
        val limit=Time.fromSeconds (LargeInt.fromInt (envInt ("RUNE_LSP_REPLAY_TIMEOUT",900)))
        val samples=ref []
        val kinds=ref [] : (string*real list ref) list ref
        val failedKinds=ref [] : string list ref
        fun response id=C.receiveWithin (client,fn value => Json.member ("id",value)=SOME (Json.int id),limit)
        fun note (name,kind,timer,status,detail)=
          let val seconds=Time.toReal (Timer.checkRealTimer timer)
              val sample=object [("phase",Json.String name),("seconds",Json.Number (Real.toString seconds)),
                ("status",Json.String status),("detail",Json.String detail)]
              val ()=case List.find (fn (other,_) => other=kind) (!kinds) of SOME (_,all) => all:=seconds:: !all
                | NONE => kinds:= !kinds @ [(kind,ref [seconds])]
          in samples:=sample:: !samples;write (out,Json.encode (Json.Array (List.rev (!samples))) ^ "\n");
             print (name ^ " " ^ Real.fmt (StringCvt.FIX (SOME 3)) seconds ^ " s " ^ status ^ (if status="ok" then "" else " " ^ detail) ^ "\n");
             TextIO.flushOut TextIO.stdOut end
        fun answer (name,kind,timer,id)=
          let val value=response id
          in case Json.member ("error",value) of
               SOME failure => (failedKinds:=kind:: !failedKinds;note (name,kind,timer,"error",abbreviate failure);NONE)
             | NONE => (note (name,kind,timer,"ok",abbreviate (getOpt (Json.member ("result",value),Json.Null)));Json.member ("result",value)) end
          handle Fail message => (failedKinds:=kind:: !failedKinds;note (name,kind,timer,"failed",message);NONE)
        fun timed (name,kind,id,method,params)=
          let val timer=Timer.startRealTimer ()
          in C.request (client,id,method,params);answer (name,kind,timer,id) end
        val target=object [("name",Json.String "target"),("build",Json.String (if build="-" then "" else uri build))]
        val settings=if build="-" then object [("libraryRoot",Json.String (uri lib))]
          else object [("libraryRoot",Json.String (uri lib)),("targets",Json.Array [target]),("activeContext",Json.String "target")]
        val params=object [("textDocument",document),("position",object [("line",Json.int line),("character",Json.int character)])]
        val identifier=object [("textDocument",document)]
        fun work () =
          let val _=timed ("initialize","initialize",1,"initialize",object [("capabilities",object [("textDocument",object [
                  ("diagnostic",object []),("documentLink",object [("tooltipSupport",Json.Bool true)])])]),
                  ("workspaceFolders",Json.Array [object [("uri",Json.String (uri root)),("name",Json.String "root")]]),
                  ("initializationOptions",settings)])
              val ()=C.notify (client,"initialized",object [])
              val text=read source
              val ()=C.notify (client,"textDocument/didOpen",object [("textDocument",object [("uri",Json.String (uri source)),
                ("languageId",Json.String "sml"),("version",Json.int 1),("text",Json.String text)])])
              val _=timed ("cold-diagnostic","cold",10,"textDocument/diagnostic",identifier)
              val _=timed ("first-hover","hover-first",11,"textDocument/hover",params)
              val _=timed ("documentSymbol","symbols",12,"textDocument/documentSymbol",identifier)
              val _=timed ("warm-hover","hover",20,"textDocument/hover",params)
              val _=timed ("warm-definition","definition",21,"textDocument/definition",params)
              val _=timed ("warm-completion","completion",22,"textDocument/completion",params)
              val version=ref 1
              val serial=ref 100
              fun change (kind,n,body)=
                let val ()=version:= !version+1
                    val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String (uri source)),
                      ("version",Json.int (!version))]),("contentChanges",Json.Array [object [("text",Json.String body)]])])
                    val id= !serial
                    val ()=serial:=id+2
                    val _=timed (kind ^ "-diagnostic-" ^ Int.toString n,kind,id,"textDocument/diagnostic",identifier)
                    val _=timed (kind ^ "-hover-" ^ Int.toString n,"edit-hover",id+1,"textDocument/hover",params)
                in () end
              fun count (n,limit,action)=if n>limit then () else (action n;count (n+1,limit,action))
              val ()=count (1,comments,fn n => change ("comment",n,text ^ "\n(* replay leaf revision " ^ Int.toString n ^ " *)\n"))
              val ()=case body of NONE => () | SOME (times,old,new) =>
                count (1,times,fn n => change ("body",n,substitute (text,old,expand (new,n))))
              val ()=(C.request (client,9000,"shutdown",Json.Null);ignore (response 9000);C.notify (client,"exit",Json.Null))
              val timer=Timer.startRealTimer ()
              val ()=(C.awaitExit (client,Time.fromSeconds 10);note ("shutdown-exit","shutdown",timer,"ok",""))
              val ()=List.app (fn (kind,all) =>
               let val ordered=sort (!all)
               in print ("SUMMARY " ^ kind ^ " n=" ^ Int.toString (length ordered) ^ " p50 " ^
                    Real.fmt (StringCvt.FIX (SOME 3)) (percentile (ordered,50)) ^ " p95 " ^ Real.fmt (StringCvt.FIX (SOME 3)) (percentile (ordered,95)) ^
                    " max " ^ Real.fmt (StringCvt.FIX (SOME 3)) (List.last ordered) ^ "\n") end) (!kinds)
              fun over (kind,limit)=case List.find (fn (other,_) => other=kind) (!kinds) of
                  NONE => SOME (kind ^ " was not measured")
                | SOME (_,all) => let val p95=percentile (sort (!all),95)
                    in if List.exists (fn other => other=kind) (!failedKinds) then SOME (kind ^ ": a request failed")
                       else if p95>limit then SOME (kind ^ " p95 " ^ Real.fmt (StringCvt.FIX (SOME 3)) p95 ^ " s, over " ^
                         Real.fmt (StringCvt.FIX (SOME 3)) limit ^ " s") else NONE end
              val failures=List.mapPartial over limits
          in List.app (fn failure => print ("FAIL " ^ failure ^ "\n")) failures;null failures end
    in (work () before C.close client) handle error => (C.close client;raise error) end
  fun main (vm::server::root::lib::build::source::out::line::character::rest) =
        let fun options ([],comments,body,limits)=(comments,body,List.rev limits)
              | options ("--comments"::n::rest,_,body,limits)=options (rest,valOf (Int.fromString n),body,limits)
              | options ("--body"::n::old::new::rest,comments,_,limits)=options (rest,comments,SOME (valOf (Int.fromString n),old,new),limits)
              | options ("--limit"::kind::seconds::rest,comments,body,limits)=
                  options (rest,comments,body,(kind,valOf (Real.fromString seconds))::limits)
              | options (other::_,_,_,_)=raise Fail ("unknown option: " ^ other)
            val (comments,body,limits)=options (rest,20,NONE,[])
        in run (vm,server,root,lib,build,source,out,valOf (Int.fromString line),valOf (Int.fromString character),comments,body,limits) end
    | main _=raise Fail "usage: rune-lsp-replay VM SERVER ROOT LIB BUILD SOURCE OUT.json LINE CHARACTER [--comments N] [--body N OLD NEW] [--limit KIND SECONDS]..."
end
val ()=if RuneLspReplay.main (CommandLine.arguments ()) then () else OS.Process.exit OS.Process.failure
  handle error => (TextIO.output (TextIO.stdErr,"rune-lsp-replay: " ^ General.exnMessage error ^ "\n");OS.Process.exit OS.Process.failure)

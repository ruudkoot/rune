(* What the language server makes of a tree's files (D26; docs/language-server.md,
   Contexts), through its own code, in one process.

   Usage: rune-lsp-contexts --lib DIR --root DIR --out FILE [--before]
            (--builds FILE | --zero FILE | --share BUILD BUILD)

   --builds names a file of build files, one a line, relative to the root:
   every source of each, once, is a file the server is asked of, with the
   root the client's folder, as an editor opening it would: how many
   contexts it has, and whether a client is asked to choose. --zero names a
   file of files in no build, one a line: each is checked as the server
   checks it, and its errors and the first unbound name are written.
   --before does as the server did before M19: a file's contexts by their
   number alone (no owner, no comparison), and a file in no build alone with
   the Basis Library. --share checks the first build, then the second over
   the same libraries, in contexts that share (C.Analysis.share), and the
   second again in one that does not: what each elaborated, loaded, took
   and kept. One JSON line a file or a check, and a summary on stdout. *)
structure RuneLspContexts =
struct
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure E=RuneLspWorkerAnalysis
  structure M=RuneLspWorkerModel
  structure C=RuneCompiler
  structure A=C.Analysis
  structure U=LspUri
  fun read file=let val input=BinIO.openIn file
    in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun lines file=List.filter (fn line => line<>"") (String.fields (fn c => c= #"\n") (read file))
  fun num n=Int.toString n
  fun say text=(print text;TextIO.flushOut TextIO.stdOut)
  fun seconds timer=Time.toReal (Timer.checkRealTimer timer)
  fun main arguments =
    let val lib=ref "" val root=ref "" val out=ref "" val before'=ref false
        val builds=ref NONE : string option ref val zero=ref NONE : string option ref
        val pair=ref NONE : (string*string) option ref
        fun options []=()
          | options ("--lib"::value::rest)=(lib:=value;options rest)
          | options ("--root"::value::rest)=(root:=value;options rest)
          | options ("--out"::value::rest)=(out:=value;options rest)
          | options ("--builds"::value::rest)=(builds:=SOME value;options rest)
          | options ("--zero"::value::rest)=(zero:=SOME value;options rest)
          | options ("--before"::rest)=(before':=true;options rest)
          | options ("--share"::first::second::rest)=(pair:=SOME (first,second);options rest)
          | options (other::_)=raise Fail ("unknown option: " ^ other)
        val ()=options arguments
        val ()=W.owners:=not (!before')
        val platform=U.Posix
        val rootPath=OS.FileSys.fullPath (!root)
        fun full name=OS.Path.concat (rootPath,name)
        fun uriOf path=U.original (U.fromPath (platform,path))
        val output=TextIO.openOut (!out)
        fun emit fields=(TextIO.output (output,Json.encode (Json.Object fields) ^ "\n");TextIO.flushOut output)
        val workspace=W.new {platform=platform,lib= !lib}
        val ()=W.setRoots (workspace,[uriOf rootPath])
        fun fresh ()=D.new (LspProtocol.Utf16,{maxDocuments=8,maxDocumentBytes=16*1024*1024,maxTotalBytes=64*1024*1024,
          maxDocumentLines=500000,maxTotalLines=1000000})
        val worker=E.new ()
        val serial=ref 1000000
        (* a plan of the worker's, made here: what a check in a context reads of it *)
        fun planned (documents,uri,selection,contexts,implicit)=
          (serial:= !serial+1;
           {serial= !serial,key=uri,stamps=[],texts=[],configuration=W.configurationFor (workspace,uri),
            selection=selection,contexts=contexts,implicit=implicit,decided=false}:E.planned)
        fun args (documents,uri)={state=M.capture (workspace,documents),uri=uri,encoding=LspProtocol.Utf16,
          capabilities=Json.Object [],cancelled=fn () => false}
        fun prompts file =
          let val names=lines file
              (* every source of every build, once *)
              val session=C.session {lib=SOME (!lib),flags=[]}
              val seen=W.table 4096
              val all=ref [] : string list ref
              val unreadable=ref 0
              val ()=List.app (fn name =>
                let val build=full name
                    val project=C.Project.read (session,{file=build,workspace=W.rootFile platform build,variables=[],overlays=[],windows=false})
                in List.app (fn source:C.Project.source =>
                     let val path=OS.FileSys.fullPath (#file source) handle OS.SysErr _ => #file source
                         val key=W.pathKey platform path
                     in if isSome (W.lookup (seen,key)) then () else (W.add (seen,key,());all:=path:: !all) end)
                   (C.Project.sources project) end
                handle C.Failed _ => unreadable:= !unreadable+1) names
              val ()=C.close session
              val files=List.rev (!all)
              val ()=say (num (length names) ^ " builds, " ^ num (!unreadable) ^ " unreadable, " ^ num (length files) ^ " files in a build\n")
              val documents=fresh ()
              val timer=Timer.startRealTimer ()
              val {uris,...}=RuneLspProjects.enrich (workspace,documents,fn () => false)
              val ()=say ("the folder's builds: " ^ num (length uris) ^ " files in " ^ Real.fmt (StringCvt.FIX (SOME 1)) (seconds timer) ^ " s\n")
              val counts=ref [] : (string*int) list ref
              fun count key=counts:=(case List.find (fn (k,_) => k=key) (!counts) of
                  SOME (_,n) => (key,n+1)::List.filter (fn (k,_) => k<>key) (!counts) | NONE => (key,1):: !counts)
              fun one path=
                let val uri=uriOf path
                    val timer=Timer.startRealTimer ()
                    val (selection,contexts)=W.resolve (workspace,documents,uri)
                    val candidates=length contexts
                    val owned= !W.owners andalso isSome (W.ownerBuild platform path)
                    val (selection,contexts)=case selection of
                        W.Ambiguous _ => if !before' then (selection,contexts) else
                          let val decided=E.decide (worker,args (documents,uri),workspace,documents,
                                planned (documents,uri,selection,contexts,NONE))
                          in (#selection decided,#contexts decided) end
                      | _ => (selection,contexts)
                    val kind=case selection of W.Selected _ => "selected" | W.Ambiguous _ => "prompt" | W.Loose => "none"
                    val ()=count kind
                    val ()=if candidates>1 then count "several candidates" else ()
                    val ()=if candidates>1 andalso kind="selected" then count "several candidates, no prompt" else ()
                in emit [("file",Json.String path),("candidates",Json.int candidates),("owned",Json.Bool owned),
                     ("kind",Json.String kind),("contexts",Json.int (length contexts)),
                     ("builds",Json.Array (List.map (fn context:W.context => Json.String (#build context)) contexts)),
                     ("seconds",Json.Number (Real.fmt (StringCvt.FIX (SOME 6)) (seconds timer)))];
                   if kind="prompt" then say ("prompt: " ^ path ^ " (" ^ num (length contexts) ^ " contexts)\n") else () end
                handle C.Failed diagnostics => (count "failed";emit [("file",Json.String path),("kind",Json.String "failed"),
                  ("message",Json.String (String.concatWith "\n" (List.map #message diagnostics)))])
                     | error => (count "failed";say ("failed: " ^ path ^ ": " ^ General.exnMessage error ^ "\n");
                         emit [("file",Json.String path),("kind",Json.String "failed"),("message",Json.String (General.exnMessage error))])
              val ()=List.app one files
              (* what a sweep covers: the files enrich found, each with a context *)
              val covered=List.filter (fn uri => case W.select (workspace,documents,uri) of
                  W.Selected _ => true | W.Ambiguous (_::_) => not (!before') | _ => false) uris
          in say ("sweep: " ^ num (length covered) ^ " of " ^ num (length uris) ^ " files have a context\n");
             List.app (fn (key,n) => say (key ^ ": " ^ num n ^ "\n")) (List.rev (!counts)) end
        fun zeros file =
          let val names=lines file
              fun one name=
                let val path=full name
                    val uri=uriOf path
                    val documents=fresh ()
                    val _=D.openDocument (documents,{uri=uri,languageId="sml",version=1,text=read path})
                    val timer=Timer.startRealTimer ()
                    val (selected,implicit,units)=if !before' then (NONE,NONE,1) else
                      case E.implicitFor (workspace,documents,uri) of
                        SOME (context,overlay,_) => (SOME context,SOME overlay,length (C.Project.sources (#project context)))
                      | NONE => (NONE,NONE,1)
                    val view=E.checkIn (worker,args (documents,uri),workspace,documents,
                      planned (documents,uri,case selected of SOME c => W.Selected c | NONE => W.Loose,
                        case selected of SOME c => [c] | NONE => [],implicit),selected)
                    val diagnostics=A.diagnostics (#snapshot view)
                    val own=List.filter (fn diagnostic:C.diagnostic => #file diagnostic=path orelse
                      (OS.FileSys.fullPath (#file diagnostic) handle OS.SysErr _ => #file diagnostic)=path) diagnostics
                    val unbound=List.filter (fn diagnostic:C.diagnostic => String.isSubstring "unbound" (#message diagnostic)) diagnostics
                    val class=if null diagnostics then "clean" else if not (null unbound) then "unbound" else "other"
                in emit [("file",Json.String name),("class",Json.String class),("units",Json.int units),
                     ("errors",Json.int (length diagnostics)),("own",Json.int (length own)),
                     ("message",Json.String (case diagnostics of first::_ => #message first | [] => "")),
                     ("unbound",Json.String (case unbound of first::_ => #message first | [] => "")),
                     ("seconds",Json.Number (Real.fmt (StringCvt.FIX (SOME 6)) (seconds timer)))];class end
                handle error => (emit [("file",Json.String name),("class",Json.String "failed"),
                  ("message",Json.String (General.exnMessage error))];"failed")
              val classes=List.map one names
              fun count class=length (List.filter (fn other => other=class) classes)
          in say (num (length names) ^ " files: clean " ^ num (count "clean") ^ ", unbound " ^ num (count "unbound") ^
               ", other " ^ num (count "other") ^ ", failed " ^ num (count "failed") ^ "\n") end
        (* two builds over one library: what the second costs where it shares *)
        fun share (first,second) =
          let val compiler=C.session {lib=SOME (!lib),flags=[]}
              fun inputsOf project=List.map (fn source:C.Project.source => {file= #file source,text=read (#file source),
                mode= #mode source,annotations= #annotations source,revision=""}:A.input) (C.Project.sources project)
              fun checked (label,build,shares)=
                let val path=full build
                    val project=C.Project.read (compiler,{file=path,workspace=W.rootFile platform path,variables=[],overlays=[],windows=false})
                    val context=A.create (compiler,{context=label})
                    val ()=(A.share (context,shares);A.focus (context,SOME []))
                    val ()=Runtime.collect ()
                    val start=Runtime.stats ()
                    val timer=Timer.startRealTimer ()
                    val snapshot=A.check (context,{project=SOME project,inputs=inputsOf project,cancelled=fn () => false})
                    val spent=seconds timer
                    val stop=Runtime.stats ()
                    val ()=(Runtime.collect ();Runtime.collect ())
                    val live= #live (Runtime.stats ())
                    val {checked,reused}=A.work snapshot
                    val {loaded,...}=A.route snapshot
                    val units=length (C.Project.sources project)+length (A.dependencies snapshot)
                    val instructions= #instructions stop- #instructions start
                in emit [("check",Json.String label),("build",Json.String build),("shares",Json.Bool shares),("units",Json.int units),
                     ("checked",Json.int checked),("reused",Json.int reused),("loaded",Json.int loaded),
                     ("diagnostics",Json.int (length (A.diagnostics snapshot))),
                     ("seconds",Json.Number (Real.fmt (StringCvt.FIX (SOME 3)) spent)),
                     ("instructions",Json.int instructions),("live",Json.int live)];
                   say (label ^ ": " ^ build ^ ", " ^ num units ^ " units, checked " ^ num checked ^ ", loaded " ^ num loaded ^
                     ", " ^ Real.fmt (StringCvt.FIX (SOME 2)) spent ^ " s, " ^
                     Real.fmt (StringCvt.FIX (SOME 2)) (real instructions/1.0E9) ^ "G instructions, live " ^
                     Real.fmt (StringCvt.FIX (SOME 1)) (real live/1048576.0) ^ " MiB" ^
                     (case A.diagnostics snapshot of [] => "" | d::_ => ", " ^ #message d) ^ "\n");
                   context end
              val one=checked ("first",first,true)
              val two=checked ("second, sharing",second,true)
              val ()=A.close two
              val alone=checked ("second, alone",second,false)
          in A.close one;A.close alone;C.close compiler end
        val ()=case (!builds,!zero,!pair) of (SOME file,_,_) => prompts file | (NONE,SOME file,_) => zeros file
          | (NONE,NONE,SOME pair) => share pair
          | _ => raise Fail "one of --builds, --zero and --share"
    in TextIO.closeOut output;OS.Process.success end
    handle Fail message => (print ("rune-lsp-contexts: " ^ message ^ "\n");OS.Process.failure)
end

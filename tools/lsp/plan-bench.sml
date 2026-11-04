(* Planning a check at scale (D28's first row): the worker's own plan of a
   file, on a tree of build files (bin/rune-lsp-fixture --no-text makes one),
   every build a target, as the configured workspace of E20's planning curve.

   Usage: rune-lsp-plan-bench --lib DIR --root DIR --open FILE --out FILE
            [--events] [--reads] [--limit MS] [--repeat N]

   FILE is a source of a build under the root; it need not exist, since the
   editor holds its text. The bench plans its check cold, then after each of
   these, each REPEAT times:
     same      nothing changed
     edit      the open file's text changed
     touch     a build that holds the file rewritten on disk, as it was
     add       a source added to that build on disk, and taken out again
     other     another program's build changed on disk, which holds
               nothing a library's file is planned from
   and writes a JSON line for each plan: its seconds, the builds it read, and
   whether it took the memo. --events has the worker told of each change by
   a file event, as an editor that watches does; without it, the worker
   looks at the stamps of what it read. --reads fails the run if a plan after
   the first reads a build outside the changed set, or one after no change
   to what it read (same, edit, other) does not take the memo: what make
   check holds. --limit fails it if a plan after the first takes longer, at
   the median of its repetitions: what the nightly tier holds, a measure of
   time asking for the machine to itself (docs/testing.md). *)
structure RuneLspPlanBench =
struct
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure E=RuneLspWorkerAnalysis
  structure M=RuneLspWorkerModel
  structure V=RuneLspWorkerWire
  structure C=CompilerApi
  structure U=LspUri
  fun read file=let val input=BinIO.openIn file
    in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun write (file,text)=let val output=BinIO.openOut file
    in BinIO.output (output,Byte.stringToBytes text);BinIO.closeOut output end
  fun num n=Int.toString n
  fun say text=(print text;TextIO.flushOut TextIO.stdOut)
  fun seconds timer=Time.toReal (Timer.checkRealTimer timer)
  fun fixed (digits,x)=Real.fmt (StringCvt.FIX (SOME digits)) x
  fun sort xs=
    let fun insert (x,[])=[x] | insert (x,y::rest)=if Real.<= (x,y) then x::y::rest else y::insert (x,rest)
    in List.foldl insert [] xs end
  fun median xs=let val s=sort xs in List.nth (s,(length s-1) div 2) end
  (* the build files under a directory, sorted *)
  fun builds root=
    let fun walk (dir,found)=
          let val stream=OS.FileSys.openDir dir
              fun loop found=case OS.FileSys.readDir stream of NONE => found | SOME name =>
                let val path=OS.Path.concat (dir,name)
                in loop (if OS.FileSys.isDir path then walk (path,found)
                         else if String.isSuffix ".build" name then path::found else found) end
          in loop found before OS.FileSys.closeDir stream end
        fun insert (x,[])=[x] | insert (x,y::rest)=if x<y then x::y::rest else y::insert (x,rest)
    in List.foldl insert [] (walk (root,[])) end
  fun main arguments =
    let val lib=ref "" val root=ref "" val opened=ref "" val out=ref "" val events=ref false
        val limit=ref NONE : real option ref val repeat=ref 3 val reads=ref false
        fun options []=()
          | options ("--lib"::value::rest)=(lib:=value;options rest)
          | options ("--root"::value::rest)=(root:=value;options rest)
          | options ("--open"::value::rest)=(opened:=value;options rest)
          | options ("--out"::value::rest)=(out:=value;options rest)
          | options ("--events"::rest)=(events:=true;options rest)
          | options ("--reads"::rest)=(reads:=true;options rest)
          | options ("--limit"::value::rest)=(limit:=SOME (real (valOf (Int.fromString value)) / 1000.0);options rest)
          | options ("--repeat"::value::rest)=(repeat:=valOf (Int.fromString value);options rest)
          | options (other::_)=raise Fail ("unknown option: " ^ other)
        val ()=options arguments
        val platform=U.Posix
        val rootPath=OS.FileSys.fullPath (!root)
        val libPath=OS.FileSys.fullPath (!lib)
        fun uriOf path=U.original (U.fromPath (platform,path))
        val openPath=if OS.Path.isAbsolute (!opened) then !opened else OS.Path.concat (rootPath,!opened)
        val uri=uriOf openPath
        val output=TextIO.openOut (!out)
        fun emit fields=(TextIO.output (output,Json.encode (Json.Object fields) ^ "\n");TextIO.flushOut output)
        val all=builds rootPath
        (* every build a target, but a program over every library *)
        val targets=List.filter (fn build => OS.Path.file build<>"all.build") all
        val workspace=W.new {platform=platform,lib=libPath}
        val ()=W.setRoots (workspace,[uriOf rootPath])
        val ()=W.configure (workspace,Json.Object [("libraryRoot",Json.String (uriOf libPath)),
          ("targets",Json.Array (List.map (fn build => Json.Object [("name",Json.String build),("build",Json.String (uriOf build))]) targets))])
        val documents=D.new (LspProtocol.Utf16,{maxDocuments=8,maxDocumentBytes=16*1024*1024,maxTotalBytes=64*1024*1024,
          maxDocumentLines=500000,maxTotalLines=1000000})
        val text=(read openPath) handle IO.Io _ => "structure Opened = struct val x = 1 end\n"
        val _=D.openDocument (documents,{uri=uri,languageId="sml",version=1,text=text})
        val version=ref 1
        val worker=E.new ()
        (* the build that holds the open file, and one that does not *)
        val library=OS.Path.concat (OS.Path.dir openPath,"library.build")
        val holder=if (OS.FileSys.access (library,[]) handle OS.SysErr _ => false) then library
          else OS.Path.joinBaseExt {base=OS.Path.base openPath,ext=SOME "build"}
        (* a program's build, which no library's closure holds *)
        val other=valOf (List.find (fn build => build<>holder andalso not (String.isSuffix "library.build" build)) targets)
        val failures=ref [] : string list ref
        val times=ref [] : (string*real list ref) list ref
        fun plan (name,changed)=
          let val () =if !events then W.changed (workspace,List.map (fn (file,moved) => (uriOf file,moved)) changed) else W.dirty workspace
              (* as the service captures it: with the roots the client watches *)
              val state=V.Object (("watchedRoots",M.strings (if !events then [uriOf rootPath] else []))::
                V.object (M.capture (workspace,documents)))
              val (copy,docs)=M.restore state
              val before'=E.planStats worker
              val timer=Timer.startRealTimer ()
              val planned=E.plan (worker,state,copy,docs,uri,fn () => false)
              val s=seconds timer
              val after=E.planStats worker
              val read= #builds after- #builds before'
              val kind=case #selection planned of W.Selected _ => "selected" | W.Ambiguous _ => "ambiguous" | W.Loose => "loose"
              val memo= #plans after= #plans before'
              val ()=emit [("plan",Json.String name),("seconds",Json.Number (fixed (6,s))),("builds",Json.int read),
                ("memo",Json.Bool memo),("selection",Json.String kind),("contexts",Json.int (length (#contexts planned)))]
              val ()=say (name ^ " " ^ fixed (3,s) ^ " s, " ^ num read ^ " builds read" ^ (if memo then ", memo" else "") ^ "\n")
              val ()=if name="cold" then () else
                (case List.find (fn (n,_) => n=name) (!times) of SOME (_,all) => all:=s:: !all
                   | NONE => times:= !times @ [(name,ref [s])];
                 if !reads andalso read>length (List.filter (not o #2) changed) then failures:=(name ^ " read " ^ num read ^ " builds, of a changed set of " ^ num (length changed)):: !failures else ();
                 if !reads andalso not memo andalso List.exists (fn other => other=name) ["same","edit","other","other-back"]
                 then failures:=(name ^ " planned again, though nothing it read changed"):: !failures else ())
          in () end
        val ()=say (num (length targets) ^ " targets under " ^ rootPath ^ "\n")
        val ()=plan ("cold",[])
        fun again (n,f)=if n=0 then () else (f ();again (n-1,f))
        val ()=again (!repeat,fn () => plan ("same",[]))
        val ()=again (!repeat,fn () =>
          (version:= !version+1;
           ignore (D.changeDocument (documents,{uri=uri,version=IntInf.fromInt (!version),changes=[D.Replace (text ^ "\n(* edit " ^ num (!version) ^ " *)\n")]}));
           plan ("edit",[])))
        val holderText=read holder
        val otherText=read other
        val ()=again (!repeat,fn () => (write (holder,holderText);plan ("touch",[(holder,false)])))
        val added=OS.Path.concat (OS.Path.dir holder,"added_by_bench.sml")
        fun withAdded text=
          let val (front,found)=Substring.position "files\n" (Substring.full text)
          in if Substring.isEmpty found then text ^ "files\n  added_by_bench.sml\nend\n"
             else Substring.string front ^ "files\n  added_by_bench.sml\n" ^ String.extract (text,Substring.size front+6,NONE) end
        val ()=again (!repeat,fn () =>
          (write (added,"structure AddedByBench = struct end\n");write (holder,withAdded holderText);plan ("add",[(holder,false),(added,true)]);
           write (holder,holderText);OS.FileSys.remove added;plan ("remove",[(holder,false),(added,true)])))
        val ()=again (!repeat,fn () => (write (other,otherText ^ "(* changed *)\n");plan ("other",[(other,false)]);
          write (other,otherText);plan ("other-back",[(other,false)])))
        val ()=TextIO.closeOut output
        val ()=List.app (fn (name,all) =>
          let val m=median (!all)
          in say ("SUMMARY " ^ name ^ " n=" ^ num (length (!all)) ^ " median " ^ fixed (3,m) ^ " s max " ^ fixed (3,List.last (sort (!all))) ^ " s\n");
             case !limit of SOME l => if m>l then failures:=(name ^ " took " ^ fixed (3,m) ^ " s at the median, over " ^ fixed (3,l)):: !failures else ()
               | NONE => () end) (!times)
    in case !failures of [] => OS.Process.success
       | _ => (List.app (fn f => say ("FAIL " ^ f ^ "\n")) (List.rev (!failures));OS.Process.failure) end
end

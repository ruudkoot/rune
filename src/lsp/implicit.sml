(* A file in no build (D26): an implicit library over its directory, and a
   name-to-file index read from syntax, which well-formed units make
   possible (docs/units.md, Well-formed units). The context is the file
   after what its names need, each name looked for in the file's own
   directory first, then among the libraries, then anywhere in its
   workspace, the nearest first; the names of what is found are looked for
   in turn. It is analysis only: nothing here is written, and no batch build
   reads it (docs/language-server.md, Contexts). *)
structure RuneLspImplicit =
struct
  structure C=RuneCompiler
  structure W=RuneLspWorkspace
  type name={kind:string,name:string}
  (* what a scan of a file's text found, a superset of what it declares at its
     top level, and what its parse says, each while the file's stamp stands *)
  type scanned={stamp:string,names:name list}
  type parsed={stamp:string,declares:name list,uses:name list}
  (* the most files a workspace's index reads, and a context holds *)
  val maximumFiles=50000
  val maximumUnits=2000
  fun stampOf file=(Time.toString (OS.FileSys.modTime file) ^ ":" ^ Position.toString (OS.FileSys.fileSize file))
    handle OS.SysErr _ => "absent"
  fun read file=let val input=BinIO.openIn file
    in (Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input)
       handle error => (BinIO.closeIn input handle _ => ();raise error) end
  fun exists file=OS.FileSys.access (file,[]) handle OS.SysErr _ => false
  fun isDir file=OS.FileSys.isDir file handle OS.SysErr _ => false
  fun entries directory=
    let val stream=OS.FileSys.openDir directory
        fun all found=case OS.FileSys.readDir stream of NONE => found | SOME entry => all (entry::found)
    in (all [] before OS.FileSys.closeDir stream) handle error => (OS.FileSys.closeDir stream handle _ => ();raise error) end
    handle OS.SysErr _ => []
  fun source file=List.exists (fn suffix => String.isSuffix suffix file) [".sml",".sig",".fun"]
  (* The SML files under a workspace's root. A hidden directory is no one's,
     and one with a root file or a repository of its own is another
     workspace (D4) *)
  fun files (platform,root) =
    let val count=ref 0
        fun walk (directory,depth,found)=
          if depth>32 orelse !count>=maximumFiles then found else
          List.foldl (fn (entry,found) =>
            if String.isPrefix "." entry then found else
            let val path=W.join platform (directory,entry)
            in if isDir path then
                 if exists (W.join platform (path,"rune.workspace")) orelse exists (W.join platform (path,".git")) then found
                 else walk (path,depth+1,found)
               else if source entry andalso !count<maximumFiles then (count:= !count+1;path::found) else found end)
            found (entries directory)
    in walk (root,0,[]) end
  (* the identifiers after structure, signature and functor in a text, outside
     comments and strings: at any depth, so a superset *)
  fun scan text =
    let val n=size text
        fun idChar c=Char.isAlphaNum c orelse c= #"_" orelse c= #"'"
        fun word j=if j<n andalso idChar (String.sub (text,j)) then word (j+1) else j
        fun space i=if i<n andalso Char.isSpace (String.sub (text,i)) then space (i+1) else i
        fun comment (i,depth)=if i+1>=n then n else
          let val c=String.sub (text,i)
          in if c= #"(" andalso String.sub (text,i+1)= #"*" then comment (i+2,depth+1)
             else if c= #"*" andalso String.sub (text,i+1)= #")" then (if depth=1 then i+2 else comment (i+2,depth-1))
             else comment (i+1,depth) end
        fun quoted i=if i>=n then n else case String.sub (text,i) of #"\"" => i+1 | #"\\" => quoted (i+2) | _ => quoted (i+1)
        fun go (i,found)=if i>=n then found else
          let val c=String.sub (text,i)
          in if c= #"(" andalso i+1<n andalso String.sub (text,i+1)= #"*" then go (comment (i+2,1),found)
             else if c= #"\"" then go (quoted (i+1),found)
             else if Char.isAlpha c then
               let val j=word (i+1)
                   val keyword=String.substring (text,i,j-i)
               in if keyword="structure" orelse keyword="signature" orelse keyword="functor" then
                    let val k=space j val e=word k
                    in if e>k then go (e,{kind=keyword,name=String.substring (text,k,e-k)}::found) else go (j,found) end
                  else go (j,found) end
             else go (i+1,found) end
    in go (0,[]) end
  (* by file, what its scan and its parse found *)
  val scans=ref (W.table 0) : scanned W.table ref
  val parses=W.table 4096 : parsed W.table
  (* A workspace's index: by name, the files whose scan found it. The tree is
     walked again for it at most every so often (fresh): a file found is
     parsed by its stamp in any case, so what is stale is a file added since,
     and the client's file events are not in the worker *)
  type index={root:string,stamps:(string*string) list,byName:string list W.table,walked:Time.time}
  val current=ref NONE : index option ref
  val fresh=Time.fromSeconds 30
  fun recent time=Time.< (Time.- (Time.now (),time),fresh)
  fun scanned (file,stamp)=case W.lookup (!scans,file) of
      SOME (known:scanned) => if #stamp known=stamp then #names known else rescan (file,stamp)
    | NONE => rescan (file,stamp)
  and rescan (file,stamp)=
    let val names=(scan (read file)) handle IO.Io _ => [] | OS.SysErr _ => []
    in W.add (!scans,file,{stamp=stamp,names=names});names end
  fun index (platform,root) : index =
    case !current of
      SOME known => if #root known=root andalso recent (#walked known) then known else walkIndex (platform,root)
    | NONE => walkIndex (platform,root)
  and walkIndex (platform,root)=
    let val found=files (platform,root)
        val stamps=List.map (fn file => (file,stampOf file)) found
    in case !current of
         SOME known => if #root known=root andalso #stamps known=stamps then
             let val again={root=root,stamps=stamps,byName= #byName known,walked=Time.now ()} in current:=SOME again;again end
           else build (root,stamps)
       | NONE => build (root,stamps) end
  and build (root,stamps) =
    let val ()=if Array.length (!scans)<2*length stamps then
          let val fresh=W.table (2*length stamps)
              val ()=List.app (fn (file,_) => Option.app (fn known => W.add (fresh,file,known)) (W.lookup (!scans,file))) stamps
          in scans:=fresh end else ()
        val byName=W.table (4*length stamps+16)
        val ()=List.app (fn (file,stamp) => List.app (fn {name,...} =>
          case W.lookup (byName,name) of
            SOME files => if List.exists (fn other => other=file) files then () else W.add (byName,name,file::files)
          | NONE => W.add (byName,name,[file])) (scanned (file,stamp))) stamps
        val made={root=root,stamps=stamps,byName=byName,walked=Time.now ()}
    in current:=SOME made;made end
  (* what a file declares at its top level and the names it uses, from its parse *)
  fun parsedText (file,text) =
    let val syntax=C.Syntax.parse {file=file,text=text,mode="ascii",orPatterns=true,fixity=C.Syntax.initial}
        val {declares,uses}=C.Syntax.names syntax
    in {declares=declares,uses=uses} end
    handle C.Failed _ => {declares=[],uses=[]}
  fun parsed file =
    let val stamp=stampOf file
        fun fresh ()=
          let val {declares,uses}=(parsedText (file,read file)) handle IO.Io _ => {declares=[],uses=[]}
              val ()=W.add (parses,file,{stamp=stamp,declares=declares,uses=uses})
          in {declares=declares,uses=uses} end
    in case W.lookup (parses,file) of
         SOME (known:parsed) => if #stamp known=stamp then {declares= #declares known,uses= #uses known} else fresh ()
       | NONE => fresh () end
  (* A MANIFEST's names: what a header exports, or else all its files provide *)
  fun manifestNames text =
    let val lines=String.fields (fn c => c= #"\n") text
        fun words text=String.tokens Char.isSpace text
        val exported=List.concat (List.map (fn line =>
          if String.isPrefix "# exports:" line then
            List.map (fn word => case String.fields (fn c => c= #":") word of [_,name] => name | _ => word)
              (words (String.extract (line,size "# exports:",NONE)))
          else []) lines)
        val provided=List.concat (List.map (fn line =>
          if String.isPrefix "#" line then [] else
          case String.fields (fn c => c= #"|") line of _::_::_::provides::_ => words provides | _ => []) lines)
    in if null exported then provided else exported end
  (* the libraries under a directory of libraries, each by its place there,
     its directory and the names it lets out; and the Basis Library's names *)
  type library={name:string,directory:string,names:string list}
  fun libraries (platform,root) : library list =
    let fun walk (directory,place,depth,found)=
          if depth>8 then found else
          List.foldl (fn (entry,found) =>
            if String.isPrefix "." entry then found else
            let val path=W.join platform (directory,entry)
                val named=if place="" then entry else place ^ "/" ^ entry
            in if not (isDir path) then found else
               let val manifest=W.join platform (path,"MANIFEST")
                   val found=if exists manifest andalso named<>"basis" then
                       ({name=named,directory=W.pathKey platform path,names=manifestNames (read manifest)}::found)
                       handle IO.Io _ => found
                     else found
               in walk (path,named,depth+1,found) end end) found (entries directory)
    in List.rev (walk (root,"",0,[])) end
  fun basisNames (platform,root)=(manifestNames (read (W.join platform (W.join platform (root,"basis"),"MANIFEST"))))
    handle IO.Io _ => [] | OS.SysErr _ => []
  (* the libraries and the Basis Library's names, walked again as the index is *)
  val known=ref [] : (string list*(library list*string list*Time.time)) list ref
  fun librariesOf (platform,lib,roots)=
    case List.find (fn (key,(_,_,walked)) => key=lib::roots andalso recent walked) (!known) of
      SOME (_,(available,basis,_)) => (available,basis)
    | NONE =>
        let val available=List.concat (List.map (fn root => libraries (platform,root)) (lib::roots))
            val basis=basisNames (platform,lib)
        in known:=[(lib::roots,(available,basis,Time.now ()))];(available,basis) end
  (* how near two files are: the directories they share *)
  fun nearness (platform,a,b) =
    let fun parts path=String.tokens (fn c => c= #"/" orelse c= #"\\") (W.directory platform path)
        fun common (x::xs,y::ys)=if x=y then 1+common (xs,ys) else 0
          | common _=0
    in common (parts a,parts b) end
  fun quote path="\"" ^ String.translate (fn #"\"" => "\\\"" | #"\\" => "\\\\" | c => String.str c) path ^ "\""
  (* The implicit library of file, whose text is text: the build that names
     it after what its names need, at a place no file has, beside it; and
     what was read to say so, whose stamps say that it holds *)
  fun context {platform,lib,libraryRoots,root,file,text} : {build:string,text:string,read:string list,units:int} =
    let val idx=index (platform,root)
        val (available,basisList)=librariesOf (platform,lib,libraryRoots)
        val basis=List.foldl (fn (name,table) => (W.add (table,name,());table)) (W.table 512) basisList
        val provider=W.table (4*List.foldl (fn (library:library,n) => n+length (#names library)) 1 available)
        val ()=List.app (fn library:library => List.app (fn name =>
          case W.lookup (provider,name) of NONE => W.add (provider,name,#name library) | SOME _ => ()) (#names library)) available
        (* the library a file is of, the deepest whose directory holds it *)
        fun libraryOf path=
          let val key=W.pathKey platform path
          in List.foldl (fn (library:library,best:library option) =>
               if not (W.below (#directory library,key)) then best else case best of
                 SOME other => if size (#directory other)>=size (#directory library) then best else SOME library
               | NONE => SOME library) NONE available end
        val own=parsedText (file,text)
        fun namesOf path=if path=file then own else parsed path
        (* the Basis Library comes whole, before any file, and none of its files is taken *)
        val basisDirectory=W.pathKey platform (W.join platform (lib,"basis"))
        fun declares (path,{kind,name})=List.exists (fn declared:name => #kind declared=kind andalso #name declared=name)
          (#declares (namesOf path))
        (* where a name a unit at path uses is declared *)
        fun declarer (path,wanted as {kind,name}:name) =
          if kind="type" orelse isSome (W.lookup (basis,name)) then NONE else
          let val candidates=List.filter (fn other => other<>path andalso not (W.below (basisDirectory,W.pathKey platform other))
                andalso declares (other,wanted)) (getOpt (W.lookup (#byName idx,name),[]))
              val directory=W.directory platform path
              val beside=List.filter (fn other => W.directory platform other=directory) candidates
              fun nearest []=NONE
                | nearest (first::rest)=SOME (List.foldl (fn (other,best) =>
                    let val a=nearness (platform,path,other) val b=nearness (platform,path,best)
                    in if a>b orelse a=b andalso other<best then other else best end) first rest)
          (* beside it; else the nearest, or its library where the library
             lets the name out, as a build would import it; else a library
             that names it, whose files the index did not read *)
          in case nearest beside of SOME found => SOME (SOME found,NONE) | NONE =>
             case nearest candidates of
               SOME found => (case libraryOf found of
                   SOME library => if List.exists (fn other => other=name) (#names library)
                     then SOME (NONE,SOME (#name library)) else SOME (SOME found,NONE)
                 | NONE => SOME (SOME found,NONE))
             | NONE => Option.map (fn library => (NONE,SOME library)) (W.lookup (provider,name)) end
        val visited=ref [] : string list ref
        val order=ref [] : string list ref
        val imports=ref [] : string list ref
        fun visit path=
          if List.exists (fn other => other=path) (!visited) orelse length (!order)>=maximumUnits then () else
          (visited:=path:: !visited;
           List.app (fn wanted => case declarer (path,wanted) of
               SOME (SOME found,_) => visit found
             | SOME (NONE,SOME library) => if List.exists (fn other => other=library) (!imports) then () else imports:= !imports @ [library]
             | _ => ()) (#uses (namesOf path));
           order:=path:: !order)
        val ()=visit file
        val units=List.rev (!order)
        val build=W.join platform (W.directory platform file,".rune-implicit-" ^ OS.Path.file file ^ ".build")
        val text=(if null (!imports) then "" else "libraries " ^ String.concatWith " " (!imports) ^ " end\n") ^
          "files\n" ^ String.concat (List.map (fn unit => "  " ^ quote unit ^ "\n") units) ^ "end\n"
        val read=W.directory platform file :: List.filter (fn unit => unit<>file) units
    in {build=build,text=text,read=read,units=length units} end
end

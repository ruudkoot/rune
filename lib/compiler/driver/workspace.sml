(* The workspace and a unit's logical name (docs/units.md, Names;
   docs/build.md, The workspace; the build-system roadmap's D3 and D4).

   A workspace is the directory of a root file, rune.workspace, found upward
   from a file. The file names the directories libraries are found under and
   the named targets, each a build file with its options.

   A unit's name is where its file is, however a path spelt it: a file of a
   library is library:path, its path below the library's directory -- the
   deepest above it with a library.build -- and any other its path from the
   root, with ../ where it is not below it. A library is named by its place
   under a directory of libraries (ffi/runtime), else by its directory's
   name, so that it keeps its name where it moves. A name holds no directory
   of the machine, but for a file on another drive than the root, which no
   relative path reaches. A library's name holds neither : nor @, which
   leaves room for a version: library@1.2:path.

   Two units of one name in a build -- a file given twice, or files of two
   libraries of one name -- are told apart by a rank, name#2, in the order of
   the build, so that no two units of a build have one name. *)
structure Workspace =
struct
  structure P = CompilerProject
  exception Invalid of string

  val rootFile = "rune.workspace"

  type target = {name : string, build : string, options : string list}
  (* root: its directory; libraryRoots: the directories it names *)
  type t = {root : string, file : string, libraryRoots : string list, targets : target list}

  fun onWindows () : bool =
    List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
    handle OS.SysErr _ => false

  fun here () = OS.FileSys.getDir () handle OS.SysErr _ => "."

  (* the same path however it was spelt, from cwd where it is relative *)
  fun keyOf (windows,cwd) path =
    P.pathKey windows (if P.absolute windows path then path else P.concat windows (cwd,path))
    handle P.Invalid _ => P.pathKey windows path

  fun exists path = OS.FileSys.access (path,[]) handle OS.SysErr _ => false

  (* ---- the root file ---- *)

  (* item ::= "roots" path ... "end" | "target" name "=" path string ... "end",
     with the build language's words and comments. Paths are relative to the
     file: no ambient path, and no machine's. *)
  fun parse {file : string, text : string, windows : bool} : t =
    let
      val root = P.directory windows file
      fun bad message = raise Invalid (file ^ ": " ^ message)
      fun place path =
        if P.absolute windows path orelse String.isSubstring "$(" path
        then bad ("a path of a workspace is relative to it, and " ^ path ^ " is not")
        else P.pathKey windows (P.concat windows (root,path))
      fun text' (BuildFile.W s) = s
        | text' (BuildFile.S s) = s
      fun untilEnd ([],_) = bad "a list that does not end"
        | untilEnd (BuildFile.W "end" :: rest,acc) = (List.rev acc,rest)
        | untilEnd ((word as BuildFile.W s) :: rest,acc) =
            if List.exists (fn mark => mark=s) ["=",",","(",")"] then bad ("unexpected " ^ s) else untilEnd (rest,word :: acc)
        | untilEnd (word :: rest,acc) = untilEnd (rest,word :: acc)
      fun option (BuildFile.S s) = s
        | option (BuildFile.W s) = bad ("a target's option is a string, and " ^ s ^ " is not")
      fun items ([],roots,targets) = {root=root,file=file,libraryRoots=List.rev roots,targets=List.rev targets}
        | items (BuildFile.W "roots" :: rest,roots,targets) =
            let val (paths,rest)=untilEnd (rest,[])
            in items (rest,List.foldl (fn (path,all) => place (text' path) :: all) roots paths,targets) end
        | items (BuildFile.W "target" :: name :: BuildFile.W "=" :: rest,roots,targets) =
            let val name=text' name
                val ()=if List.exists (fn target : target => #name target=name) targets
                       then bad ("two targets are named " ^ name) else ()
            in case untilEnd (rest,[]) of
                 (build :: options,rest) =>
                   items (rest,roots,{name=name,build=place (text' build),options=List.map option options} :: targets)
               | ([],_) => bad ("the target " ^ name ^ " names no build file")
            end
        | items (BuildFile.W "target" :: _,_,_) = bad "a target is target NAME = BUILD OPTION ... end"
        | items (word :: _,_,_) = bad ("unexpected " ^ text' word ^ ": a workspace has roots and targets")
    in items (BuildFile.words (file,text),[],[]) end
    handle BuildFile.Error message => raise Invalid message

  fun read (file : string, windows : bool) : t =
    let val ins = BinIO.openIn file
        val text = Byte.bytesToString (BinIO.inputAll ins) before BinIO.closeIn ins
    in parse {file=file,text=text,windows=windows} end
    handle IO.Io _ => raise Invalid ("cannot read the workspace " ^ file)

  (* where a root file above a file would be, the nearest first *)
  fun candidates {file : string, windows : bool} : string list =
    let fun up dir =
          P.concat windows (dir,rootFile) ::
          (let val parent = P.directory windows dir in if parent=dir then [] else up parent end)
    in up (P.directory windows (keyOf (windows,here ()) file)) end

  (* the directory of the nearest root file above a file, not read: where
     the workspace's store is (StorePolicy.directory) *)
  fun rootOf {file : string, windows : bool} : string option =
    Option.map (P.directory windows) (List.find exists (candidates {file=file,windows=windows}))

  (* the nearest root file above a file, read *)
  fun find {file : string, windows : bool} : t option =
    let
      fun up dir =
        let val candidate = P.concat windows (dir,rootFile)
        in
          if exists candidate then SOME (read (candidate,windows))
          else let val parent = P.directory windows dir in if parent=dir then NONE else up parent end
        end
    in up (P.directory windows (keyOf (windows,here ()) file)) end

  (* ---- what names are made in ---- *)

  (* root: what a program's own files are named from; libraries: the
     directories of libraries, --lib first; lib: --lib as it was given, which
     the entries of its libraries begin with *)
  type scope = {windows : bool, root : string, libraries : string list, lib : string option, cwd : string}

  fun scopeAt {root : string option, file : string, workspace : t option, lib : string option, windows : bool} : scope =
    let
      val cwd = here ()
      val key = keyOf (windows,cwd)
    in
      {windows=windows,root=case root of SOME root => root | NONE => P.directory windows (key file),
       libraries=(case lib of SOME lib => [key lib] | NONE => [])
                 @ (case workspace of SOME w => #libraryRoots w | NONE => []),
       lib=lib,cwd=cwd}
    end

  (* a build's files are named from the workspace's root, or without one
     from the build file's directory *)
  fun ofBuild {file : string, workspace : t option, lib : string option, windows : bool} : scope =
    scopeAt {root=Option.map #root workspace,file=file,workspace=workspace,lib=lib,windows=windows}

  (* files given by themselves, which no build file holds together, from
     the directory of the first: they move together, as a project does,
     wherever the workspace around them is (S29) *)
  fun ofFiles {file : string, workspace : t option, lib : string option, windows : bool} : scope =
    scopeAt {root=NONE,file=file,workspace=workspace,lib=lib,windows=windows}

  (* ---- names ---- *)

  type names = {scope : scope, known : string option StringMap.map ref}
  fun names (scope : scope) : names = {scope=scope,known=ref StringMap.empty}

  (* path from the directory base, both keys *)
  fun relative (windows : bool) (base : string, key : string) : string =
    let
      fun arcs path = List.filter (fn arc => arc<>"") (String.fields (fn c => c = #"/") path)
      fun volume path =
        if not windows then ""
        else if P.drive path then String.map Char.toLower (String.substring (path,0,2))
        else if String.isPrefix "//" path then (String.concatWith "/" (List.take (arcs path,2)) handle Subscript => path)
        else ""
      fun drop (a :: rest,b :: more) = if a=b then drop (rest,more) else (a :: rest,b :: more)
        | drop pair = pair
      val (up,down) = drop (arcs base,arcs key)
    in
      if volume base<>volume key then key
      else String.concatWith "/" (List.map (fn _ => "..") up @ down)
    end

  (* a key from the current directory, so that a path to a library says no
     more of the machine than the paths a build gives *)
  fun fromHere (windows : bool, key : string) : string =
    relative windows (P.pathKey windows (here ()),key)

  (* the library that holds a directory, by the deepest library.build above
     it: as far as the root, and for a directory beside the root as far as
     what it shares with the root, so that nothing above the root has a say.
     Each directory is asked once. *)
  fun libraryOf ({scope={windows,root,...},known} : names) (dir : string) : string option =
    let
      fun above d = d<>root andalso String.isPrefix (if String.isSuffix "/" d then d else d ^ "/") root
      fun look d =
        case StringMap.find (!known,d) of
          SOME found => found
        | NONE =>
            let
              val up = P.directory windows d
              val found =
                if above d then NONE
                else if Source.probe (P.concat windows (d,"library.build")) then SOME d
                else if d=root orelse up=d then NONE
                else look up
            in known:=StringMap.insert (!known,d,found);found end
    in look dir end

  (* what no library's name holds: the room for a version *)
  val spelt = String.map (fn #":" => #"_" | #"@" => #"_" | c => c)

  (* a library by its place under a directory of libraries, else by its own *)
  fun libraryName ({scope={libraries,...},...} : names) (dir : string) : string =
    let
      fun below root =
        if String.isPrefix (root ^ "/") dir then SOME (String.extract (dir,size root+1,NONE)) else NONE
    in
      spelt (case List.mapPartial below libraries of
               name :: _ => name
             | [] => List.last (String.fields (fn c => c = #"/") dir))
    end

  (* the logical name of a file, before any rank *)
  fun name (names as {scope={windows,root,cwd,...},...} : names, path : string) : string =
    let
      val key = keyOf (windows,cwd) path
    in
      case libraryOf names (P.directory windows key) of
        SOME library => libraryName names library ^ ":" ^ relative windows (library,key)
      | NONE => relative windows (root,key)
    end

  (* that of a file of a library named to the compiler, which asks nothing
     of the file system where the library is under --lib: an installed one
     has no library.build, and a small program has many such files *)
  fun ofEntry (names as {scope={lib,...},...} : names, {dir : string, file : string}) : string =
    case lib of
      SOME root =>
        if String.isPrefix (root ^ "/") dir
        then spelt (String.extract (dir,size root+1,NONE)) ^ ":" ^ file
        else name (names,dir ^ "/" ^ file)
    | NONE => name (names,dir ^ "/" ^ file)

  (* ---- ranks ---- *)

  type ranks = unit StringMap.map ref
  fun ranks () : ranks = ref StringMap.empty

  (* name, marked as the build's *)
  fun take (ranks : ranks, name : string) : unit = ranks:=StringMap.insert (!ranks,name,())

  (* the name a unit of this name has, in the order of the build *)
  fun fresh (ranks : ranks, name : string) : string =
    let
      fun free n =
        let val ranked = name ^ "#" ^ Int.toString n
        in if StringMap.member (!ranks,ranked) then free (n+1) else ranked end
      val chosen = if StringMap.member (!ranks,name) then free 2 else name
    in take (ranks,chosen);chosen end

  (* Where a unit's source was, from its name, for what has no record of it:
     no rank, and under lib for a library's file. *)
  fun sourceOf (lib : string option, name : string) : string =
    let
      val stem = case List.rev (String.fields (fn c => c = #"#") name) of
                   rank :: rest =>
                     if not (null rest) andalso rank<>"" andalso CharVector.all Char.isDigit rank
                     then String.concatWith "#" (List.rev rest) else name
                 | [] => name
    in
      case (lib,String.fields (fn c => c = #":") stem) of
        (SOME lib,library :: path) =>
          if null path then stem else lib ^ "/" ^ library ^ "/" ^ String.concatWith ":" path
      | _ => stem
    end
end

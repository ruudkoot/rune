(* Ordered compiler sessions. Compilation attempts own fresh compiler roots;
   only successful artifacts join the history. Execution is explicit. *)
structure CompilerSession =
struct
  type source = {file : string, text : string, mode : Source.mode}
  type artifact = {identity : string, fingerprint : int, code : Link.unitCode,
                   bytes : string, pickle : string, mid : string, source : source, library : bool}
  type diagnostic = {severity : string, file : string, start : int, stop : int,
                     line : int, column : int, message : string}
  exception Failed of diagnostic list
  exception Closed
  datatype input = Text of source | Loaded of artifact | MidInput of {source : source, pickle : string, mid : string}
  (* functors: the functors to inline across units besides the libraries'
     marks, and whether the marks are left out (docs/build.md, Inline
     functors) *)
  type functors = {inline : string list, noInline : bool}
  (* language: the contexts of overloading and of free type variables at
     top level (--overloading, --free-tyvars; docs/language.md) *)
  type language = {overloading : Elaborate.overloadMode, freeTyvars : Elaborate.freeMode}
  type config = {target : string, allowPrim : bool, lib : string option, libraries : string list, functors : functors,
                 language : language}
  (* the language's choices of config, set in the compiler of an attempt *)
  fun language (config : config) : unit =
    (Elaborate.overloading := #overloading (#language config); Elaborate.freeTyvars := #freeTyvars (#language config))
  type platform = {link : string -> unit -> unit, inherited : (string * string option) list,
                   prepare : bool -> unit, current : unit -> (string * string) list}
  datatype session = Session of {token : unit ref, namespace : string, config : config, sources : input list ref,
                                closed : bool ref, platform : platform,
                                linked : (string * (unit -> unit) * bool ref * bool ref) list ref}
  datatype compiled = Compiled of {session : session, revision : int, artifact : artifact,
                                  dependencies : artifact list, finals : artifact list}

  fun sourceError (severity,span : Source.span,message) : diagnostic =
    let val (line,column) = case Source.findFile (#file span) of
          SOME file => Source.lineCol (file,#start span) | NONE => (1,1)
    in {severity=severity,file= #file span,start= #start span,stop= #stop span,
        line=line,column=column,message=message} end
  fun checked (Session {closed,...}) = if !closed then raise Closed else ()
  fun session (config : config,platform) =
    if #target config <> "registers" andalso #target config <> "stack" then raise Domain
    else Session {token=ref (),namespace="\001RuneSession:" ^ Int.toString (CompilerState.freshIdentity ()) ^ ":",
      config=config,sources=ref [],closed=ref false,platform=platform,linked=ref []}
  fun close (Session {closed,sources,linked,...}) = (closed:=true;sources:=[];linked:=[])

  (* The source history changes only after a successful operation. Every
     attempt owns a fresh compiler, so failure cannot mutate earlier types. *)
  exception CachedLoad
  fun compileSourcesWith (useCache,config : config,sources : input list) : {units : artifact list,finals : artifact list,cacheHits : int,compiled : int} =
    let
      val owner = CompilerState.session ()
      fun work () =
        let
          val () = UnitBasis.startSession ()
          (* the library lints at the boundaries where RUNE_LINT says
             nothing else (docs/ir.md, Levels) *)
          val () = Pass.lintDefault := 1
          val () = (Pass.whole:=false; Pipeline.keepMid:=true; CompilerSettings.target:= #target config;
                    Error.keep:=true;Error.silent:=true;Elaborate.recover:=true)
          val () = CompilerSettings.libDir:= #lib config
          val () = language config
          (* the functors to inline, set in this attempt's own compiler as
             rune's options set them *)
          val {inline,noInline} = #functors config
          val () =
            Elaborate.inlineFunctors:=
              List.foldl (fn (n,m) => StringMap.insert (m,n,())) StringMap.empty
                (inline @ (case (noInline,#lib config) of
                             (false,SOME root) =>
                               List.concat (List.map BasisManifest.inlineFunctors
                                 (root ^ "/basis" :: (BasisManifest.libraries (root,#libraries config)
                                                      handle BasisManifest.Usage _ => [])))
                           | _ => []))
          val cacheHits=ref 0
          val compiled=ref 0
          val env = ref Env.initial
          val fixity = ref Fixity.initial
          fun textUnit (source : source,name,allow,library,(ordinal,artifacts)) =
            let
              val ()=compiled:= !compiled+1
              val {file,text,mode} = source
              val input = Source.fromStringIn (mode,file,text)
              val () = Source.register input
              val start = UnitBasis.begin (!env,!fixity)
              val (decs,outgoing) = Parser.parseTokensWith (Lexer.tokenize input,!fixity)
              val () = Elaborate.allowPrim:=allow
              val () = Elaborate.elabTop (env,decs)
              val () = Elaborate.finish ()
              val () = if !Error.errors=0 then () else raise Failed (List.map sourceError (List.rev (!Error.kept)))
              val result = Pipeline.unitThrough {start=start,name=name,file=file,text=fn () => text,mode=mode,
                decs=decs,delta= !Elaborate.lastDelta,fixity=outgoing,used=[],fresh=false}
              val code = #code result
              val fingerprint = Pipeline.fingerprint ()
              val mid = case !Pipeline.lastMid of SOME mid => UnitMid.write (#exported result,mid) | NONE => ""
              val loaded = #loaded result
              val () = (env:=Env.plus (#env start,#delta loaded);
                        fixity:=Fixity.extend (#fixity start,#directives loaded);UnitBasis.bind loaded)
              val bytes = String.concat (UnitFile.chunks (fingerprint,code))
              (* its code read back, at level 2 *)
              val () = Pass.checkAt ("code-rt",2) (Pipeline.codeRoundTrip (fingerprint,bytes)) code
              val artifact = {identity= #identity code,fingerprint=fingerprint,code=code,
                bytes=bytes,pickle= #pickle (#exported result),
                mid=mid,source=source,library=library}
            in (ordinal+1,artifact :: artifacts) end
          fun compile (Text source,(ordinal,artifacts)) =
                textUnit (source,#file source ^ "#" ^ Int.toString ordinal,#allowPrim config,false,(ordinal,artifacts))
            | compile (Loaded (artifact : artifact),(ordinal,artifacts)) =
              let
                val {file,text,mode} = #source artifact
                val () = Source.register (Source.fromStringIn (mode,file,text))
                val () = if #fingerprint artifact = Pipeline.fingerprint () then () else raise Fail "unit instruction set differs"
                fun known ({unit,...} : Link.key) = unit="" orelse unit= #identity artifact orelse
                  List.exists (fn a : artifact => #identity a=unit) artifacts
                val code = #code artifact
                val () = if List.all (known o #1) (#globals code) andalso List.all (known o #2) (#imports code)
                         then () else raise Fail "unit dependency is not imported"
                val loaded = UnitBasis.load {pickle= #pickle artifact,file=file,at=UnitBasis.counters ()}
                val () = if #identity (#unit loaded) = #identity artifact then () else raise Fail "unit and basis identities differ"
                val () = (env:=Env.plus (!env,#delta loaded);
                          fixity:=Fixity.extend (!fixity,#directives loaded);UnitBasis.bind loaded)
              in (Int.max (ordinal+1,
                    case List.rev (String.fields (fn c => c = #"#") (#name (#unit loaded))) of
                      last :: _ => (case Int.fromString last of SOME n => n+1 | NONE => ordinal+1)
                    | [] => ordinal+1),artifact :: artifacts) end
            | compile (MidInput {source,pickle,mid},(ordinal,artifacts)) =
              let
                val {file,text,mode}=source
                val ()=Source.register (Source.fromStringIn (mode,file,text))
                val loaded=UnitBasis.load {pickle=pickle,file=file,at=UnitBasis.counters ()}
                val unit= #unit loaded
                val um=UnitMid.read (mid,unit,[],fn f => f)
                val lo=Vector.sub (#base unit,UnitBasis.kStamp)
                val hi=lo+Vector.sub (#count unit,UnitBasis.kStamp)
                val ()=Lower.knownBefore:=IntMap.filteri (fn (s,_) => s<lo orelse s>=hi) (!Lower.knownBefore)
                val ()=Translate.funNames:= IntMap.fromList (#funNames um)
                val low=Pipeline.lowOfMid (#mid um)
                val code=Pipeline.targetStage low
                val sc : Link.sessionCode={code=code,globals=IntMap.listItemsi (!Code.globals),defines=Link.defines low,
                  imports=List.map (fn (s,i) => (i,s)) (IntMap.listItemsi (!Lower.imported)),exports=IntMap.listItemsi (!Lower.globalFids)}
                val ()=Lower.knownBefore:=IntMap.foldli (fn (s,_,m) => IntMap.insert (m,s,())) (!Lower.knownBefore) (!Lower.globalFids)
                val own=Vector.tabulate (3,fn k =>
                  let val table=IntTable.table (Vector.sub (#count unit,k))
                      val ()=List.app (fn i => IntTable.insert (table,Vector.sub (#base unit,k)+i,i))
                        (List.tabulate (Vector.sub (#count unit,k),fn i => i))
                  in table end)
                val exported : UnitBasis.exported={pickle=pickle,identity= #identity unit,own=own,counts= #count unit,
                  provenance=Link.provenance (#target config,mode,Pickle.hash text)}
                val code=UnitBasis.relative (exported,sc)
                val fingerprint=Pipeline.fingerprint ()
                val artifact={identity= #identity code,fingerprint=fingerprint,code=code,bytes=String.concat (UnitFile.chunks (fingerprint,code)),
                  pickle=pickle,mid=mid,source=source,library=false}
                val ()=(env:=Env.plus (!env,#delta loaded);fixity:=Fixity.extend (!fixity,#directives loaded);UnitBasis.bind loaded)
              in (ordinal+1,artifact :: artifacts) end
          fun inputSource (Text source) = source
            | inputSource (Loaded artifact) = #source artifact
            | inputSource (MidInput {source,...}) = source
          fun mentioned (input,known) =
            let val {file,text,mode}=inputSource input
                val source=Source.fromStringIn (mode,file,text)
                val ()=Source.register source
            in BasisManifest.namesOf (Lexer.tokenize source,known) end
          val plan=CompilerPrelude.select {lib= #lib config,libraries= #libraries config,
            mentioned=List.foldl mentioned StringMap.empty sources}
          type context={basis : LibraryScope.basis,fixity : Fixity.env,binders : string StringMap.map}
          fun context () : context={basis={env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs},fixity= !fixity,binders= !UnitBasis.binders}
          fun restore (c : context) =
            (env:= #env (#basis c);Elaborate.sigs:= #sigs (#basis c);Elaborate.funs:= #funs (#basis c);
             fixity:= #fixity c;UnitBasis.binders:= #binders c)
          val contexts=ref [] : (string * context) list ref
          fun libraryUnit (e : BasisManifest.entry,state) =
            let val file=BasisManifest.path e
                val loaded=Source.readFile (Source.Ascii,file)
                val name=case #lib config of
                  SOME root => if String.isPrefix (root ^ "/") file then "lib/" ^ String.extract (file,size root+1,NONE) else file
                | NONE => file
                val allow=case #lib config of SOME root => #dir e=root ^ "/basis" | NONE => false
                val source={file=file,text= #text loaded,mode=Source.Ascii}
                val ()=UnitBasis.position (!env,!fixity)
                val key=UnitCache.key {name=name,text= #text loaded,allow=allow,settings=""}
                val found=case (useCache,UnitCache.frozen ()) of
                  (true,SOME directory) => UnitCache.find (directory,UnitCache.configuration (),key)
                | _ => UnitCache.Missed "cache disabled"
            in
              case found of
                UnitCache.Missed _ => textUnit (source,name,allow,true,state)
              | UnitCache.Found entry =>
                  ((let
                      val (fingerprint,code)=UnitFile.read (#code entry)
                      val moved=UnitBasis.movedTo (#file entry,file,#others entry)
                      val code=UnitBasis.relocate (code,#file entry,file,#others entry)
                      val mid=if #mid entry="" then "" else UnitMid.relocate (#mid entry,moved)
                      val artifact={identity= #identity code,fingerprint=fingerprint,code=code,
                        bytes=String.concat (UnitFile.chunks (fingerprint,code)),pickle= #pickle entry,mid=mid,source=source,library=true}
                      val result=compile (Loaded artifact,state)
                    in cacheHits:= !cacheHits+1;result end)
                   handle UnitFile.Bad _ => raise CachedLoad | Pickle.Bad _ => raise CachedLoad | UnitBasis.Missing _ => raise CachedLoad)
            end
          fun group (entries,state) =
            let val prior=context ()
                val state=List.foldl libraryUnit state entries
            in case BasisManifest.scopeOf entries of
                 NONE => state
               | SOME exports =>
                   let val raw=context ()
                       val visible=LibraryScope.restrict (#basis prior,#basis raw,exports)
                       fun public key = case String.fields (fn c => c = #" ") key of
                         [kind,name] => List.exists (fn (k,n) => n=name andalso
                           k=(case kind of "s" => "structure" | "t" => "type" | "sig" => "signature" | "fun" => "functor" | _ => "")) exports
                       | _ => false
                       val bound=StringMap.filteri (fn (key,_) => public key) (!UnitBasis.binders)
                       val narrowed : context={basis=visible,fixity= #fixity prior,
                         binders=StringMap.unionWith #2 (#binders prior,bound)}
                   in contexts:=(#dir (hd entries),raw) :: !contexts;restore narrowed;state end
            end
          val base= #2 (List.foldl group (0,[]) (#groups plan))
          val (ordinal,result)=List.foldl compile (1,base) sources
          fun final (entries,state) =
            let val prior=context ()
                val ()=case List.find (fn (dir,_) => dir= #dir (hd entries)) (!contexts) of SOME (_,raw) => restore raw | NONE => ()
                val state=List.foldl libraryUnit state entries
            in restore prior;state end
          val finals= #2 (List.foldl final (ordinal,[]) (CompilerPrelude.groups (#final plan)))
        in {units=List.rev result,finals=List.rev finals,cacheHits= !cacheHits,compiled= !compiled} end
      val result = CompilerState.withSession (owner,fn () => work ()
        handle Error.CompileError (span,message) => raise Failed [sourceError ("error",span,message)])
        handle e => (CompilerState.close owner;raise e)
    in CompilerState.close owner;result end

  fun compileSources (config,sources) = compileSourcesWith (true,config,sources)
    handle CachedLoad => compileSourcesWith (false,config,sources)

  fun compileText (session as Session {config,sources,...},source : source) =
    let
      val () = checked session
      val next = !sources @ [Text source]
      val output = compileSources (config,next)
      val artifacts = #units output
      val artifact = List.last artifacts
      val dependencies = List.take (artifacts,length artifacts-1)
      val () = sources:=next
    in Compiled {session=session,revision=length next,artifact=artifact,dependencies=dependencies,finals= #finals output} end

  fun writeBytes (file,bytes) =
    let val {dir,file=name}=OS.Path.splitDirFile file
        val reservation=OS.FileSys.tmpName ()
        val temporary=OS.Path.joinDirFile {dir=dir,file="." ^ name ^ "." ^ OS.Path.file reservation}
        fun remove path = OS.FileSys.remove path handle _ => ()
        fun write () =
          let val output=BinIO.openOut temporary
          in (BinIO.output (output,Byte.stringToBytes bytes);BinIO.closeOut output)
             handle e => (BinIO.closeOut output handle _ => ();raise e) end
    in (write ();OS.FileSys.rename {old=temporary,new=file};remove reservation)
       handle e => (remove temporary;remove reservation;raise e) end
  fun readBytes file = let val input=BinIO.openIn file
    in (Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input)
       handle e => (BinIO.closeIn input handle _ => ();raise e) end
  fun sidecar (file,ext) = OS.Path.joinBaseExt {base=OS.Path.base file,ext=SOME ext}
  fun sourceBytes (artifact : artifact) =
    let val w=Pickle.writer ()
        val {file,text,mode}= #source artifact
        val ()=Pickle.bytes (w,"RCS")
        val ()=Pickle.nat (w,2)
        val ()=List.app (fn s => Pickle.string (w,s)) [file,Source.modeName mode,text,Pickle.hash (#bytes artifact),Pickle.hash (#pickle artifact),Pickle.hash (#mid artifact)]
    in Pickle.contents w end
  fun decodeSource (bytes,unit,basis,mid) : source =
    let val r=Pickle.reader bytes
        val ()=if Pickle.rbytes (r,3)="RCS" andalso Pickle.rnat r=2 then () else raise Pickle.Bad "source companion version"
        val file=Pickle.rstring r
        val mode=case Source.modeNamed (Pickle.rstring r) of SOME mode => mode | NONE => raise Pickle.Bad "source companion mode"
        val text=Pickle.rstring r
        val codeHash=Pickle.rstring r
        val basisHash=Pickle.rstring r
        val midHash=Pickle.rstring r
        val ()=if basisHash=Pickle.hash basis andalso Pickle.atEnd r andalso
          (case unit of NONE => true | SOME bytes => Pickle.hash bytes=codeHash) andalso
          (case mid of NONE => true | SOME bytes => Pickle.hash bytes=midHash)
          then () else raise Pickle.Bad "source companion integrity"
        val header=Pickle.reader basis
        val _=List.tabulate (3,fn _ => Pickle.rnat header)
        val expected=Pickle.rstring header
        val sourceMode=Pickle.rstring header
        val ()=if expected=Pickle.hash text andalso sourceMode=Source.modeName mode then ()
          else raise Pickle.Bad "source companion does not match its checked basis"
    in {file=file,text=text,mode=mode} end
  fun writeUnit (Compiled {artifact,...},file) =
    (writeBytes (file,#bytes artifact);writeBytes (sidecar (file,"rbi"),#pickle artifact);
     writeBytes (sidecar (file,"rbm"),#mid artifact);writeBytes (sidecar (file,"rbs"),sourceBytes artifact))
  fun sourceFromBasis (config : config,pickle,files) : source =
    let val r=Pickle.reader pickle
        val _=List.tabulate (3,fn _ => Pickle.rnat r)
        val expected=Pickle.rstring r
        val mode=case Source.modeNamed (Pickle.rstring r) of SOME mode => mode | NONE => raise Pickle.Bad "unit source mode"
        val ()=if Pickle.rbytes (r,3)=UnitBasis.magic andalso Pickle.rnat r=UnitBasis.version then () else raise Pickle.Bad "unit basis version"
        val ()=if Pickle.rstring r=Pickle.probe () then () else raise Pickle.Bad "unit basis made by a compiler whose hash differs"
        val name=Pickle.rstring r
        val parts=String.fields (fn c => c = #"#") name
        val inferred=case List.rev parts of
          ordinal :: rest => if not (null rest) andalso ordinal<>"" andalso CharVector.all Char.isDigit ordinal
                            then String.concatWith "#" (List.rev rest) else name
        | [] => name
        val inferred=case #lib config of SOME lib => if String.isPrefix "lib/" inferred then lib ^ String.extract (inferred,3,NONE) else inferred
                                             | NONE => inferred
        fun read [] = raise Fail "unit source is unavailable; provide its source companion"
          | read (file :: rest) =
              case (SOME (Source.readFile (mode,file)) handle IO.Io _ => NONE) of
                SOME source => if Pickle.hash (#text source)=expected then {file=file,text= #text source,mode=mode} else read rest
              | NONE => read rest
    in read (files @ [inferred]) end
  fun readUnit (session as Session {config,sources,...},file) =
    let
      val ()=checked session
      val bytes=readBytes file
      val basis=readBytes (sidecar (file,"rbi"))
      val (fingerprint,code)=UnitFile.read bytes
      val mid=readBytes (sidecar (file,"rbm")) handle IO.Io _ => ""
      val source=(decodeSource (readBytes (sidecar (file,"rbs")),SOME bytes,basis,if mid="" then NONE else SOME mid)
        handle IO.Io _ => sourceFromBasis (config,basis,#files (#code code)))
      val artifact={identity= #identity code,fingerprint=fingerprint,code=code,bytes=bytes,pickle=basis,mid=mid,source=source,library=false}
      val next= !sources @ [Loaded artifact]
      val output=compileSources (config,next)
      val artifacts= #units output
      val dependencies=List.take (artifacts,length artifacts-1)
      val ()=if List.exists (fn a : artifact => #identity a= #identity artifact) dependencies
        then raise Fail "unit is already present in this context" else ()
      val ()=sources:=next
    in Compiled {session=session,revision=length next,artifact=artifact,dependencies=dependencies,finals= #finals output} end
  fun readMid (session as Session {config,sources,...},{basis,mid}) =
    let val ()=checked session
        val pickle=readBytes basis
        val midBytes=readBytes mid
        val source=(decodeSource (readBytes (sidecar (basis,"rbs")),NONE,pickle,SOME midBytes)
          handle IO.Io _ => sourceFromBasis (config,pickle,[]))
        val next= !sources @ [MidInput {source=source,pickle=pickle,mid=midBytes}]
        val output=compileSources (config,next)
      val artifacts= #units output
        val artifact=List.last artifacts
        val dependencies=List.take (artifacts,length artifacts-1)
        val ()=if List.exists (fn a : artifact => #identity a= #identity artifact) dependencies
          then raise Fail "unit is already present in this context" else ()
        val ()=sources:=next
    in Compiled {session=session,revision=length next,artifact=artifact,dependencies=dependencies,finals= #finals output} end
  fun writeMid (Compiled {artifact,...},file) =
    if #mid artifact="" then raise Fail "unit has no Mid representation"
    else writeBytes (file,#mid artifact)
  (* Runtime reachability is narrower than the compilation prefix. *)
  fun runtimeUnits (roots : artifact list,catalog : artifact list) =
    let
      fun required (a : artifact) =
        List.filter (fn identity => identity<>"" andalso identity<> #identity a)
          (List.map (#unit o #1) (#globals (#code a)) @ List.map (#unit o #2) (#imports (#code a)))
      fun visit (a : artifact,seen) =
        if List.exists (fn identity => identity= #identity a) seen then seen else
        List.foldl (fn (identity,seen) =>
          case List.find (fn candidate : artifact => #identity candidate=identity) catalog of
            NONE => raise Fail ("missing runtime dependency: " ^ identity)
          | SOME dependency => visit (dependency,seen)) (#identity a :: seen) (required a)
      val wanted=List.foldl visit [] roots
    in List.filter (fn a : artifact => List.exists (fn identity => identity= #identity a) wanted) catalog end
  fun owned action =
    let val owner=CompilerState.session ()
        (* the library lints at the boundaries where RUNE_LINT says nothing
           else (docs/ir.md, Levels) *)
        val result=CompilerState.withSession (owner,fn () => (Pass.lintDefault:=1;action ()))
                   handle e => (CompilerState.close owner;raise e)
    in CompilerState.close owner;result end
  fun writeProgram (compiled,path) = owned (fn () =>
    let
      val () = case compiled of [] => raise Fail "no units to write"
        | Compiled {session=Session {token,...},...} :: rest =>
            if List.all (fn Compiled {session=Session {token=other,...},...} => token=other) rest then ()
            else raise Fail "units belong to different compiler contexts"
      fun all (Compiled {artifact,dependencies,...}) = dependencies @ [artifact]
      fun latest (current as Compiled {revision,...},prior as Compiled {revision=old,...}) =
        if revision>old then current else prior
      val Compiled {finals,...}=List.foldl latest (hd compiled) (tl compiled)
      val artifacts = List.concat (List.map all compiled) @ finals
      fun add (a : artifact,acc) = if List.exists (fn b : artifact => #identity a = #identity b) acc then acc else acc @ [a]
      val artifacts = List.foldl add [] artifacts
      val roots=List.map (fn Compiled {artifact,...} => artifact) compiled @ finals
      val artifacts=runtimeUnits (roots,artifacts)
      val fingerprint = #fingerprint (hd artifacts)
      val () = if List.all (fn a : artifact => #fingerprint a=fingerprint) artifacts then () else raise Domain
      val code =
        if fingerprint=RegCodes.fingerprint then
          (Code.opcodeNames:=RegCodes.names;Link.program (Regs.program,RegCodes.linked,List.map #code artifacts))
        else Link.program (Stack.program,Opcodes.linked,List.map #code artifacts)
      val prior = !Emit.trailer
      val () = Emit.trailer:=Emit.unitsSection (!Link.lastExports)
      val () = Emit.writeFileAs (fingerprint,path,code) handle e => (Emit.trailer:=prior;raise e)
    in Emit.trailer:=prior end)
  fun run (Compiled {session=session as Session {platform,config,namespace,linked,...},artifact,dependencies,...}) =
    let
      val () = checked session
      val () = #prepare platform (Option.isSome (#lib config))
      fun runtimeIdentity identity =
        if identity="" orelse List.exists (fn (id,_) => id=identity) (#inherited platform) then identity
        else namespace ^ identity
      fun runtimeBytes (a : artifact) = owned (fn () =>
        let val code= #code a
            fun key ({unit,number} : Link.key) = {unit=runtimeIdentity unit,number=number}
            val moved : Link.unitCode={identity=runtimeIdentity (#identity code),provenance= #provenance code,code= #code code,
              globals=List.map (fn (k,n) => (key k,n)) (#globals code),
              imports=List.map (fn (n,k) => (n,key k)) (#imports code),exports= #exports code}
            val ()=if #fingerprint a=RegCodes.fingerprint then Code.opcodeNames:=RegCodes.names else ()
        in String.concat (UnitFile.chunks (#fingerprint a,moved)) end)
      fun entry (a : artifact) =
        case List.find (fn (identity,_,_,_) => identity= #identity a) (!linked) of
          SOME saved => saved
        | NONE => let val action= #link platform (runtimeBytes a)
                      val saved=(#identity a,action,ref false,ref false)
                  in linked:=saved :: !linked;saved end
      fun execute (_,action,complete,running) =
        if !running then raise Fail "cyclic unit execution"
        else
          let val ()=running:=true
              val ()=complete:=false
              val ()=action () handle e => (running:=false;raise e)
          in running:=false;complete:=true end
      fun dependency a =
        if List.exists (fn (identity,_) => identity= #identity (a : artifact)) (#inherited platform) then () else
        let val saved as (_,_,complete,running)=entry a
        in if !complete orelse !running then () else execute saved end
      val needed=runtimeUnits ([artifact],dependencies @ [artifact])
      val current= #current platform ()
      fun validate (a : artifact) =
        case List.find (fn (identity,_) => identity= #identity a) (#inherited platform) of
          NONE =>
            let fun name identity = String.substring (identity,0,Int.max (0,size identity-25))
            in if #library a andalso List.exists (fn (identity,_) => name identity=name (#identity a)) (#inherited platform)
               then raise Fail ("host library source differs: " ^ #identity a) else () end
        | SOME (_,NONE) => raise Fail ("host library source provenance is unavailable: " ^ #identity a)
        | SOME (_,SOME hash) => if not (#library a) then
            raise Fail ("imported unit collides with a host unit: " ^ #identity a)
          else if Option.map #2 (List.find (fn (identity,_) => identity= #identity a) current) <> SOME hash then
            raise Fail ("host unit linkage changed: " ^ #identity a)
          else if hash=Link.provenance (#target config,#mode (#source a),Pickle.hash (#text (#source a))) then () else
            raise Fail ("host library source differs: " ^ #identity a)
      val ()=List.app validate needed
      val () = List.app dependency (List.filter (fn a : artifact => #identity a <> #identity artifact) needed)
    in execute (entry artifact) end
end

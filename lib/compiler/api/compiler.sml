(* Ordered static compilation with explicit execution and artifact I/O.

   Implements: RUNE_COMPILER *)
structure RuneCompiler :> RUNE_COMPILER =
struct
  structure C = CompilerSession
  datatype session = Session of {compiler : C.session, mode : Source.mode}
  type compiled = C.compiled
  type diagnostic = C.diagnostic
  exception Failed = C.Failed
  exception Closed = C.Closed
  val version = Config.version
  fun invalid message = raise Failed [{severity="error",file="",start=0,stop=0,line=1,column=1,message=message}]
  fun guard file action = action ()
    handle Failed diagnostics => raise Failed diagnostics
         | Closed => raise Closed
         | IO.Io {function,name,cause} => raise Failed [{severity="error",file=file,start=0,stop=0,line=1,column=1,
             message=function ^ " " ^ name ^ ": " ^ General.exnMessage cause}]
         | Pickle.Bad message => invalid message
         | UnitFile.Bad message => invalid message
         | UnitMid.Bad message => invalid message
         | UnitBasis.Missing identity => invalid ("missing unit dependency: " ^ identity)
         | BasisManifest.Usage message => invalid message
         | Fail message => invalid message
  fun session {lib,flags} =
    let
      (* --inline-functor=F[,F...] and --no-inline-functors, as rune takes
         them (docs/build.md, Inline functors) *)
      val inline=ref [] val noInline=ref false
      fun prototype flag =
        if String.isPrefix "--inline-functor=" flag then
          (inline:= !inline @ List.filter (fn n => n<>"") (String.fields (fn c => c = #",") (String.extract (flag,17,NONE)));true)
        else if flag="--no-inline-functors" then (noInline:=true;inline:=[];true)
        else false
      fun options ([],target,allow,mode,libraries) = (target,allow,mode,List.rev libraries)
        | options ("--target=registers" :: rest,_,allow,mode,libraries) = options (rest,"registers",allow,mode,libraries)
        | options ("--target=stack" :: rest,_,allow,mode,libraries) = options (rest,"stack",allow,mode,libraries)
        | options ("--allow-prim" :: rest,target,_,mode,libraries) = options (rest,target,true,mode,libraries)
        | options ("--unicode" :: rest,target,allow,_,libraries) = options (rest,target,allow,Source.Unicode Source.Utf8,libraries)
        | options ("--unicode=utf8" :: rest,target,allow,_,libraries) = options (rest,target,allow,Source.Unicode Source.Utf8,libraries)
        | options ("--unicode=latin1" :: rest,target,allow,_,libraries) = options (rest,target,allow,Source.Unicode Source.Latin1,libraries)
        | options ("--library" :: name :: rest,target,allow,mode,libraries) = options (rest,target,allow,mode,name :: libraries)
        | options (flag :: rest,target,allow,mode,libraries) =
            if prototype flag then options (rest,target,allow,mode,libraries)
            else invalid ("unsupported compiler-library flag: " ^ flag)
      val (target,allow,mode,libraries)=options (flags,"registers",false,Source.Ascii,[])
    in Session {compiler=C.session ({target=target,allowPrim=allow,lib=lib,libraries=libraries,
                                     functors={inline= !inline,noInline= !noInline}},
      {link=CompilerApiPlatform.link,inherited=CompilerApiPlatform.inherited,
       prepare=CompilerApiPlatform.prepare,current=CompilerApiPlatform.current}),mode=mode} end
  fun close (Session {compiler,...}) = C.close compiler
  fun compileText (Session {compiler,mode},{file,text}) = guard file (fn () => C.compileText (compiler,{file=file,text=text,mode=mode}))
  fun compileFile (Session {compiler,mode},file) =
    guard file (fn () =>
      let val source=C.owned (fn () => Source.readFile (mode,file))
      in C.compileText (compiler,{file=file,text= #text source,mode=mode}) end)
  fun readUnit (Session {compiler,...},file) = guard file (fn () => C.readUnit (compiler,file))
  fun readMid (Session {compiler,...},files as {basis,...}) = guard basis (fn () => C.readMid (compiler,files))
  val run = C.run
  fun writeUnit (unit,file) = guard file (fn () => C.writeUnit (unit,file))
  fun writeMid (unit,file) = guard file (fn () => C.writeMid (unit,file))
  fun writeProgram (units,file) = guard file (fn () => C.writeProgram (units,file))
  fun typeAt (Session {compiler,...},position as {file,...}) =
    guard file (fn () => CompilerQuery.typeAt (compiler,position))

  structure Syntax =
  struct
    type t=CompilerSyntax.t
    type fixities=Fixity.env
    type piece={kind:string,start:int,stop:int,text:string}
    type event={kind:string,start:int,stop:int,values:string list}
    type work=CompilerSyntax.work
    val initial=Fixity.initial
    fun parse {file,text,mode,orPatterns,fixity} = guard file (fn () => C.owned (fn () =>
      case Source.modeNamed mode of NONE => invalid "unknown source mode" | SOME mode =>
        CompilerSyntax.parse {file=file,text=text,mode=mode,orPatterns=orPatterns,fixity=fixity}))
    fun edit (snapshot,change)=C.owned (fn () => CompilerSyntax.edit (snapshot,change))
    val text=CompilerSyntax.text
    val fixities=CompilerSyntax.fixity
    val pieces=CompilerSyntax.pieces
    val work=CompilerSyntax.work
    fun events snapshot=List.map (fn (kind,span:Source.span,values) =>
      {kind=kind,start= #start span,stop= #stop span,values=values}) (SyntaxAst.shape (CompilerSyntax.bridge snapshot))
    fun diagnostics (snapshot as CompilerSyntax.Syntax {file,text,mode,...}) =
      let val source=Source.fromStringIn (mode,file,text)
      in List.map (fn (span:Source.span,message) =>
        let val (line,column)=Source.lineCol (source,#start span)
        in {severity="error",file=file,start= #start span,stop= #stop span,line=line,column=column,message=message} end)
        (CompilerSyntax.problems snapshot) end
  end

  structure Project =
  struct
    structure P=CompilerProject
    type source={file:string,annotations:string list,mode:string,ordinal:int}
    type input={file:string,text:string,mode:string,kind:string,revision:string}
    type buildReference=CompilerBuildQuery.reference
    type pathCompletion=CompilerBuildQuery.completion
    type buildLink=CompilerBuildQuery.link
    datatype t=Project of {owner:unit ref,plan:P.plan,sources:source list,inputs:input list,fingerprint:string}
    fun sources (Project {sources,...})=sources
    fun inputs (Project {inputs,...})=inputs
    fun libraries (Project {plan,...})= #libraries plan
    fun cacheDirectories (Project {plan,...})= #caches plan
    fun fingerprint (Project {fingerprint,...})=fingerprint
    fun buildSyntax (request as {file,...})=guard file (fn () => C.owned (fn () =>
      let val result=CompilerBuildQuery.inspect request
      in {references= #references result,diagnostics= #diagnostics result} end))
    fun buildLinks (Session {compiler=compiler as C.Session {config,...},...},{file,text,variables,windows})=
      guard file (fn () => C.owned (fn () =>
        (C.checked compiler;BuildFile.variables:=StringMap.fromList variables;
         CompilerBuildQuery.links {file=file,text=text,windows=windows,lib= #lib config})))
    fun pathCompletions (Session {compiler=compiler as C.Session {config,...},...},
                         {file,text,offset,variables,windows})=guard file (fn () => C.owned (fn () =>
      let val ()=C.checked compiler
          val bindings=StringMap.fromList variables
          val ()=BuildFile.variables:=bindings
      in CompilerBuildQuery.completions {file=file,text=text,offset=offset,variables=StringMap.listItemsi bindings,
           windows=windows,lib= #lib config} end))
    fun read (Session {compiler=compiler as C.Session {config,token,...},mode},{file,variables,overlays,windows}) =
      guard file (fn () => C.owned (fn () =>
        let
          val ()=C.checked compiler
          val ()=(Error.silent:=true;Error.keep:=true;Error.kept:=[])
          val ()=BuildFile.variables:=StringMap.fromList variables
          val overlays=List.map (fn {file,text} => (P.inputKey windows file,text)) overlays
          fun fileId path = SOME (OS.FileSys.fileId path) handle OS.SysErr _ => NONE
          val overlayIds=List.map (fn (file,text) => (file,text,fileId file)) overlays
          fun load (mode,path) =
            let val key=P.inputKey windows path
                val id=fileId path
                fun matches (file,_,other) = file=key orelse
                  (case (id,other) of (SOME a,SOME b) => OS.FileSys.compare (a,b)=EQUAL | _ => false)
                val found=List.filter matches overlayIds
            in case found of [] => Source.load (mode,path)
             | (_,text,_) :: rest =>
                if List.exists (fn (_,other,_) => other<>text) rest then invalid "multiple open overlays refer to the same project input"
                else let val source=Source.fromStringIn (mode,path,text)
                     in Source.register source;source end end
          val sourceInputs=ref [] : input list ref
          fun build path =
            let val source=load (Source.Ascii,path)
            in {text= #text source,revision=Pickle.hash ("ascii:" ^ #text source)} end
          fun syntax (mode,path) =
            let val source=load (mode,path)
                val revision=Pickle.hash (Source.modeName mode ^ ":" ^ #text source)
                val ()=sourceInputs:={file=path,text= #text source,mode=Source.modeName mode,kind="source",revision=revision} :: !sourceInputs
            in #1 (Parser.parseTokensWith (Lexer.tokenize source,Fixity.initial)) end
          val plan=P.plan {file=file,defaultMode=mode,windows=windows,readBuild=build,syntax=syntax}
          val inputs=List.map (fn {path,text,revision} =>
            {file=path,text=text,revision=revision,mode="ascii",kind="build"}) (#inputs plan) @ List.rev (!sourceInputs)
          val units=P.units (#steps plan)
          val sources=ListPair.map (fn ((path,annotations),ordinal) =>
            {file=path,annotations=annotations,mode=Source.modeName (P.modeOf (mode,annotations)),ordinal=ordinal})
            (units,List.tabulate (length units,fn i => i))
          val writer=Pickle.writer ()
          fun text value=Pickle.string (writer,value)
          val ()=List.app text [Config.identity,#target config,Source.modeName mode,
            getOpt (#lib config,""),Bool.toString windows,Bool.toString (#allowPrim config)]
          val ()=Pickle.list Pickle.string (writer,#libraries config)
          val ()=List.app (fn ({file,annotations,mode,...}:source) =>
            (text file;text mode;Pickle.list Pickle.string (writer,annotations))) sources
          val ()=List.app (fn ({file,text=body,mode,kind,...}:input) =>
            (text file;text mode;text kind;text body)) inputs
          val ()=Pickle.list Pickle.string (writer,#libraries plan)
          val ()=Pickle.list Pickle.string (writer,#caches plan)
        in Project {owner=token,plan=plan,sources=sources,inputs=inputs,fingerprint=Pickle.hash (Pickle.contents writer)} end
        handle CompilerProject.Invalid message => invalid message
             | Error.CompileError (span,message) => raise Failed [C.sourceError ("error",span,message)]))
  end

  structure Analysis =
  struct
    structure A=CompilerAnalysis
    datatype t=Analysis of {analysis:A.t,mode:Source.mode,owner:unit ref}
    type snapshot=A.snapshot
    type checkpoint=A.checkpoint
    type input=A.input
    type location=A.location
    type occurrence=A.occurrence
    type fact=A.fact
    type typeDefinition=A.typeDefinition
    type candidate=A.candidate
    type call=A.call
    type typeHint=A.typeHint
    type observation=A.observation
    exception Cancelled=A.Cancelled
    exception Busy=A.Busy
    fun create (Session {compiler=compiler as C.Session {token,...},mode},{context}) =
      Analysis {analysis=A.new (compiler,context),mode=mode,owner=token}
    fun close (Analysis {analysis,...})=A.close analysis
    fun observe (Analysis {analysis,...},callback)=A.observe(analysis,callback)
    fun checkpoint (Analysis {analysis,...})=A.checkpoint analysis
    fun restore (Analysis {analysis,...},checkpoint)=guard "" (fn () => A.restore (analysis,checkpoint))
    fun check (Analysis {analysis,mode,owner},{project,inputs,cancelled}) = guard "" (fn () =>
      let fun normalize (input:input):input=
            {file= #file input,text= #text input,mode=Source.modeName (CompilerProject.modeOf
              (case Source.modeNamed (#mode input) of SOME mode => mode
               | NONE => if #mode input="" then mode else invalid "unknown analysis source mode",#annotations input)),
             annotations= #annotations input,revision= #revision input}
          val inputs=List.map normalize inputs
          val (steps,fingerprint,libraries)=case project of NONE =>
              (List.map (fn input:input => CompilerProject.SUnit (#file input,#annotations input)) inputs,NONE,[])
            | SOME (Project.Project {owner=projectOwner,plan,sources,inputs=captured,fingerprint}) =>
                let val ()=if owner=projectOwner then () else invalid "project belongs to another compiler context"
                    val ()=if length inputs=length sources then () else invalid "analysis input count differs from the project"
                    val ()=ListPair.app (fn (input:input,source:Project.source) =>
                      if #file input= #file source andalso #mode input= #mode source andalso #annotations input= #annotations source
                      then () else invalid "analysis inputs differ from the project's ordered source occurrences") (inputs,sources)
                    val ()=List.app (fn captured:Project.input => if #kind captured<>"source" then () else
                      if List.exists (fn input:input => #file input= #file captured andalso #mode input= #mode captured
                        andalso #text input= #text captured) inputs then () else invalid "group discovery input changed after project resolution") captured
                in (#steps plan,SOME fingerprint,#libraries plan) end
      in A.check (analysis,{inputs=inputs,steps=steps,project=fingerprint,libraries=libraries,cancelled=cancelled}) end)
      handle Error.CompileError (span,message) => raise Failed [C.sourceError ("error",span,message)]
    fun id (snapshot:snapshot)= #id snapshot
    fun context (snapshot:snapshot)= #context snapshot
    fun project (snapshot:snapshot)= #project snapshot
    fun inputs (snapshot:snapshot)= #inputs snapshot
    val unitAt=A.unitAt
    val syntaxAt=A.syntaxAt
    fun dependencies (snapshot:snapshot)= #dependencies snapshot
    fun diagnostics (snapshot:snapshot)= #diagnostics snapshot
    fun occurrences (snapshot:snapshot)= #occurrences snapshot
    fun types (snapshot:snapshot)= #types snapshot
    fun facts (snapshot:snapshot)= #facts snapshot
    fun work (snapshot:snapshot)={checked= #checked snapshot,reused= #reused snapshot}
    val typeAt=A.typeAt
    val typeAtOccurrence=A.typeAtOccurrence
    val typeHints=A.typeHints
    val visibleAt=A.visibleAt
    val signatureAt=A.signatureAt
    val completionAt=A.completionAt
    val documentationAt=A.documentationAt
  end
end

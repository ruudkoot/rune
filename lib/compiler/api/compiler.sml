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
         | Fail message => invalid message
  fun session {lib,flags} =
    let
      fun options ([],target,allow,mode,libraries) = (target,allow,mode,List.rev libraries)
        | options ("--target=registers" :: rest,_,allow,mode,libraries) = options (rest,"registers",allow,mode,libraries)
        | options ("--target=stack" :: rest,_,allow,mode,libraries) = options (rest,"stack",allow,mode,libraries)
        | options ("--allow-prim" :: rest,target,_,mode,libraries) = options (rest,target,true,mode,libraries)
        | options ("--unicode" :: rest,target,allow,_,libraries) = options (rest,target,allow,Source.Unicode Source.Utf8,libraries)
        | options ("--unicode=utf8" :: rest,target,allow,_,libraries) = options (rest,target,allow,Source.Unicode Source.Utf8,libraries)
        | options ("--unicode=latin1" :: rest,target,allow,_,libraries) = options (rest,target,allow,Source.Unicode Source.Latin1,libraries)
        | options ("--library" :: name :: rest,target,allow,mode,libraries) = options (rest,target,allow,mode,name :: libraries)
        | options (flag :: _,_,_,_,_) = invalid ("unsupported compiler-library flag: " ^ flag)
      val (target,allow,mode,libraries)=options (flags,"registers",false,Source.Ascii,[])
    in Session {compiler=C.session ({target=target,allowPrim=allow,lib=lib,libraries=libraries},
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

  structure Project =
  struct
    structure P=CompilerProject
    type source={file:string,annotations:string list,mode:string,ordinal:int}
    type input={file:string,text:string,mode:string,kind:string,revision:string}
    datatype t=Project of {plan:P.plan,sources:source list,inputs:input list,fingerprint:string}
    fun sources (Project {sources,...})=sources
    fun inputs (Project {inputs,...})=inputs
    fun libraries (Project {plan,...})= #libraries plan
    fun cacheDirectories (Project {plan,...})= #caches plan
    fun fingerprint (Project {fingerprint,...})=fingerprint
    fun read (Session {compiler=compiler as C.Session {config,...},mode},{file,variables,overlays,windows}) =
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
            getOpt (#lib config,""),Bool.toString windows]
          val ()=Pickle.list Pickle.string (writer,#libraries config)
          val ()=List.app (fn ({file,annotations,mode,...}:source) =>
            (text file;text mode;Pickle.list Pickle.string (writer,annotations))) sources
          val ()=List.app (fn ({file,text=body,mode,kind,...}:input) =>
            (text file;text mode;text kind;text body)) inputs
          val ()=Pickle.list Pickle.string (writer,#libraries plan)
          val ()=Pickle.list Pickle.string (writer,#caches plan)
        in Project {plan=plan,sources=sources,inputs=inputs,fingerprint=Pickle.hash (Pickle.contents writer)} end
        handle CompilerProject.Invalid message => invalid message
             | Error.CompileError (span,message) => raise Failed [C.sourceError ("error",span,message)]))
  end
end

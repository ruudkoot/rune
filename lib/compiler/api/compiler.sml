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
end

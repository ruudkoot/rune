(* Derive the complete non-Basis source closure using the compiler, then use
   the existing REPL file arguments and repeated -e declarations. *)
structure GeneratedScalarReplChecks =
struct
  open Sh
  fun need(ok,message)=if ok then () else raise Fail message
  val lib=OS.FileSys.fullPath(env("RUNE_LIB","lib"))
  val sourceRoot=OS.Path.dir lib
  val rune=OS.FileSys.fullPath(env("RUNE","bin/rune"))
  val vm=OS.FileSys.fullPath(env("RUNEVM","bin/runevm"))
  val image=OS.FileSys.fullPath(env("RUNE_REPL_IMAGE","bin/rune-repl.img"))
  val generator=OS.FileSys.fullPath(env("RUNEFFI_BYTECODE","bin/runeffi.rbc"))
  val directory=let val reservation=OS.FileSys.tmpName()
      val path=run ^ "/ffi-scalar-repl/" ^ OS.Path.file reservation
      val ()=mkdirs path val ()=OS.FileSys.remove reservation
    in path end
  val commands=ref([]:Json.value list)
  fun hash path=Hex.fromBytes(Sha256.digest(read path))
  fun command environment name arguments=
    let val prefix=directory ^ "/" ^ name val started=Runtime.clock()
        val status=Children.exec Subprocess.unlimited environment {cmd=arguments,dir=SOME root,stdin="",
          stdout=prefix ^ ".out",stderr=prefix ^ ".err",timeout=600}
        val elapsed=Time.toReal(Time.-(Runtime.clock(),started))
        val row=Json.Object[("name",Json.String name),("argv",Json.Array(List.map Json.String arguments)),
          ("status",Json.int status),("wallSeconds",Json.Number(Real.toString elapsed))]
        val ()=commands:= !commands @ [row]
        val ()=write(prefix ^ ".json",Json.encodeIndented 2 row ^ "\n")
        val output=read(prefix ^ ".out") val errors=read(prefix ^ ".err")
        val ()=need(status=0,name ^ " failed: " ^ output ^ errors)
    in (output,errors) end
  fun run name arguments=command(fn e=>e)name arguments
  val (runeVersion,_)=run "compiler-version"[rune,"--version"]
  val (vmVersion,_)=run "vm-version"[vm,"--version"]
  val generated=directory ^ "/generated"
  val fixture=sourceRoot ^ "/tests/ffi/generator"
  val ()=ignore(run "generate"[vm,"--jit=off",generator,"generate","--config",fixture ^ "/scalars.ffi",
    "--target",sourceRoot ^ "/ffi/targets/linux-x86_64.json","--out",generated,
    "--layout","gen_record","--constant","GEN_HIGH","--constant","GEN_NEGATIVE"])
  val sets=entries(generated ^ "/sets")
  val ()=need(length sets=1,"expected one immutable generated scalar set")
  val selected=generated ^ "/sets/" ^ hd sets
  val sources=List.map(fn path=>selected ^ "/" ^ path)["raw_sig.sml","raw.sml","public_sig.sml","public.sml"]
  val subject=directory ^ "/scalars.so"
  val compiler=env("CC","cc")
  val (compilerVersion,_)=run "c-compiler-version"[compiler,"--version"]
  val ()=ignore(run "compile-subject"[compiler,"-std=c17","-O2","-Wall","-Wextra","-Werror","-shared","-fPIC",
    fixture ^ "/scalars.c","-o",subject])
  val (dependencies,_)=run "basis-deps"([rune,"--lib",lib,"--library","ffi/runtime","--basis-deps"] @ sources)
  (* --basis-deps prints Basis filenames and absolute non-Basis paths when
     --lib is absolute. The restored REPL image already provides the Basis. *)
  val loaded=List.filter OS.Path.isAbsolute(lines dependencies)
  val ()=need(not(null loaded) andalso List.all(fn path=>String.isPrefix(lib ^ "/")path andalso exists path)loaded,
    "compiler did not provide a complete local non-Basis source closure")
  val inputs=loaded @ sources @ [sourceRoot ^ "/tests/ffi/generator/repl-session.sml"]
  val compilerBytecode=OS.Path.dir rune ^ "/rune.rbc"
  val files=List.map(fn path=>(path,hash path))(rune::vm::image::generator::subject::inputs @
    (if exists compilerBytecode then [compilerBytecode] else []) @
    [fixture ^ "/scalars.ffi",fixture ^ "/scalars.h",fixture ^ "/transitive.h",selected ^ "/ffi-manifest.json",
     sourceRoot ^ "/lib/ffi/model/public.sml",sourceRoot ^ "/lib/ffi/model/generate.sml",sourceRoot ^ "/src/ffi/main.sml"])
  fun snapshot(index,path)=let val target=directory ^ "/source-" ^ Int.toString index ^ ".sml"
    in write(target,read path);target end
  val frozen=List.map snapshot(ListPair.zip(List.tabulate(length inputs,fn n=>n),inputs))
  val declarations=["GeneratedScalarRepl.beginSession()",
    "datatype laterScalarRepl=LaterScalarRepl of int list; val lateScalarAllocation=LaterScalarRepl(List.tabulate(7000,fn n=>n+1)); fun lateScalarIdentity x=x; val ()=Runtime.collect()",
    "GeneratedScalarRepl.finishSession()"]
  val arguments=[vm,"--jit=off","--gc-verify","--restore",image,"--","-q","--no-init"] @ frozen @
    List.concat(List.map(fn text=>["-e",text])declarations)
  val (output,errors)=command(setEnv("RUNE_SCALAR_REPL_LIBRARY",subject))"repl" arguments
  val ()=need(errors="" andalso String.isSubstring
    "PASS current generated scalar REPL: public=42 raw-status=42 native-resources=0" output,
    "generated public/raw REPL session did not complete with clean native resources")
  val ()=List.app(fn(path,digest)=>need(hash path=digest,"REPL acceptance input changed: " ^ path))files
  val report=Json.Object[("schema",Json.int 1),("generatedSet",Json.String(hd sets)),
    ("compilerVersion",Json.String runeVersion),("vmVersion",Json.String vmVersion),
    ("cCompilerVersion",Json.String compilerVersion),
    ("nonBasisLoadOrder",Json.Array(List.map Json.String loaded)),("commands",Json.Array(!commands)),
    ("sourceAndBinaryHashes",Json.Array(List.map(fn(path,digest)=>Json.Object[("path",Json.String path),
      ("sha256",Json.String digest)])files)),("stdout",Json.String output),("stderr",Json.String errors)]
  val ()=write(directory ^ "/result.json",Json.encodeIndented 2 report ^ "\n")
  val ()=say("PASS generated scalar public/raw REPL and compiler-derived dependencies: " ^ directory ^ "/result.json\n")
end

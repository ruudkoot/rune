(* Opt-in phase measurements, attributable artifacts and paired C checksums.
   No elapsed-time threshold is a correctness oracle. *)
structure FfiPerformanceChecks =
struct
  open Sh
  open FfiPerformanceModel
  val (requested,iterations,samples)=case CommandLine.arguments() of [directory,count,repetitions]=>
      (directory,valOf(Int.fromString count),valOf(Int.fromString repetitions))
    | _=>raise Fail "usage: rune-ffi-performance OUTPUT-DIRECTORY ITERATIONS SAMPLES"
  val ()=need(iterations>=100 andalso iterations<=10000000 andalso samples>=3 andalso samples<=20,"measurement range")
  val directory=OS.Path.mkAbsolute{path=requested,relativeTo=root}
  val ()=need(not(exists directory) orelse
    (isDir directory andalso not(OS.FileSys.isLink directory) andalso null(entries directory)),"measurement output must be a fresh directory")
  val ()=mkdirs directory
  fun executable path=
    if String.isSubstring "/" path then OS.FileSys.fullPath(fromRoot path) else
    let val candidates=List.map(fn directory=>OS.Path.concat(if directory="" then root else directory,path))
          (String.fields(fn c=>c= #":")(env("PATH","")))
    in case List.find(fn file=>OS.FileSys.access(file,[OS.FileSys.A_EXEC]) handle OS.SysErr _=>false)candidates of
        SOME file=>OS.FileSys.fullPath file | NONE=>raise Fail("missing executable " ^ path) end
  val compiler=executable(env("CC","cc"))
  val rune=executable(env("RUNE","bin/rune"))
  val vm=executable(env("RUNEVM","bin/runevm"))
  val lib=OS.FileSys.fullPath(env("RUNE_LIB","lib"))
  val sourceRoot=OS.Path.dir lib
  val sourceMain=sourceRoot ^ "/src/ffi/main.sml"
  val cliMain=sourceRoot ^ "/src/main/runeffi-rune-main.sml"
  val ()=need(exists sourceMain andalso exists cliMain,"RUNE_LIB must belong to a complete production checkout")
  val mode=env("FFI_PERF_MODE","off")
  val ()=need(List.exists(fn name=>name=mode)["off","baseline","opt","all"],"unknown FFI_PERF_MODE")
  val vmOptions=["--jit=" ^ mode]
  val subject=directory ^ "/libsubject.so"
  val direct=directory ^ "/direct"
  val worker=directory ^ "/worker.rbc"
  val generation=directory ^ "/generation.rbc"
  val cli=directory ^ "/runeffi.rbc"
  val flags=["-std=c17","-O2","-Wall","-Wextra","-Werror","-pedantic"]
  val index=ref 0
  fun command arguments=
    let val n= !index val ()=index:=n+1 val prefix=directory ^ "/command-" ^ Int.toString n
        val ()=write(prefix ^ ".argv.json",Json.encode(Json.Array(List.map Json.String arguments)) ^ "\n")
        val beforeTimes=Posix.ProcEnv.times() val started=Runtime.clock()
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=arguments,dir=SOME root,stdin="",
          stdout=prefix ^ ".out",stderr=prefix ^ ".err",timeout=600}
        val elapsed=Time.toReal(Time.-(Runtime.clock(),started)) val afterTimes=Posix.ProcEnv.times()
        val cpu=Time.toReal(Time.+(Time.-( #cutime afterTimes, #cutime beforeTimes),Time.-( #cstime afterTimes, #cstime beforeTimes)))
        val ()=write(prefix ^ ".json",Json.encode(Json.Object[("argv",Json.Array(List.map Json.String arguments)),
          ("cwd",Json.String root),("status",Json.int status),("childCpuSeconds",number cpu),("wallSeconds",number elapsed)]) ^ "\n")
        val ()=need(status=0,"measurement command exited " ^ Int.toString status ^ ": " ^ prefix)
    in {output=read(prefix ^ ".out"),cpu=cpu,wall=elapsed} end
  fun output args= #output(command args)
  fun hashValue path=Hex.fromBytes(Sha256.digest(read path))
  fun hashed path=Json.Object[("path",Json.String path),("sha256",Json.String(hashValue path))]
  fun sourcesUnder directory=List.concat(List.map(fn name=>
    let val path=OS.Path.concat(directory,name)
    in if isDir path then sourcesUnder path else
      if String.isSuffix ".sml" name orelse name="library.build" orelse name="MANIFEST" then [path] else [] end)(entries directory))
  val benchmarkSources=List.map fromRoot["tests/ffi/performance.c","tests/ffi/performance-direct.c","tests/ffi/performance.sml","tests/ffi/performance-model.sml",
    "tests/ffi/performance-generation.sml","tests/ffi/performance-check.sml"]
  val productionSources=sourceMain::cliMain::List.map(fn path=>sourceRoot ^ "/" ^ path)
    ["tests/ffi/generator/scalars.ffi","tests/ffi/generator/scalars.h","tests/ffi/generator/transitive.h",
     "tests/ffi/generator/safe.ffi","tests/ffi/generator/safe.h","ffi/targets/linux-x86_64.json"] @
    List.concat(List.map(fn name=>sourcesUnder(lib ^ "/" ^ name))["basis","language/c","ffi/model","ffi/marshal","ffi/runtime","digest","json","unicode"])
  val sourceHashes=List.map(fn path=>(path,hashValue path))(benchmarkSources @ productionSources)
  val vmHash=hashValue vm
  val compilerHash=hashValue compiler
  val runeHash=hashValue rune
  val compilerBytecode=OS.Path.dir rune ^ "/rune.rbc"
  val compilerBytecodeHash=if exists compilerBytecode then SOME(hashValue compilerBytecode) else NONE
  val revision=output["git","rev-parse","HEAD"]
  val libraryRevision=output["git","-C",sourceRoot,"rev-parse","HEAD"]
  val ()=ignore(command(compiler::flags @ ["-shared","-fPIC",fromRoot "tests/ffi/performance.c","-o",subject]))
  val ()=ignore(command(compiler::flags @ [fromRoot "tests/ffi/performance-direct.c","-L" ^ directory,"-lsubject",
    "-Wl,-rpath," ^ directory,"-o",direct]))
  val ()=ignore(command[rune,"--lib",lib,"--library","ffi/runtime","--library","json",fromRoot "tests/ffi/performance.sml","-o",worker])
  val ()=ignore(command[rune,"--lib",lib,"--library","ffi/model","--library","digest",sourceMain,
    fromRoot "tests/ffi/performance-generation.sml","-o",generation])
  val ()=ignore(command[rune,"--lib",lib,"--library","ffi/model","--library","digest",sourceMain,cliMain,"-o",cli])
  val safeRoot=sourceRoot ^ "/tests/ffi/generator"
  val shimRoot=directory ^ "/generated-shim"
  val ()=ignore(command(vm::vmOptions @ [cli,"generate","--config",safeRoot ^ "/safe.ffi",
    "--target",sourceRoot ^ "/ffi/targets/linux-x86_64.json","--out",shimRoot,"--include",safeRoot]))
  val sets=entries(shimRoot ^ "/sets")
  val ()=need(length sets=1,"expected one immutable shim generation")
  val shim=shimRoot ^ "/sets/" ^ hd sets ^ "/shims.c"
  val ()=need(exists shim,"safe policy must produce optional C adapters")
  val runtimePhases=["loop","load-symbol-first","load-symbol","prepare-first","prepare","scalar-first","scalar",
    "marshal-256-first","marshal-256","callback-first","callback"]
  val generationPhases=["generation-first","generation-warm","preprocess","parse","projection-generation","packaging"]
  fun rows result=List.map Json.decode(lines result)
  fun runtimeRows result=
    let val all=rows result val cleanup=List.filter(fn row=>text(field "phase" row)="cleanup")all
        val measured=List.filter(fn row=>text(field "phase" row)<>"cleanup")all
        val ()=need(length cleanup=1 andalso field "foreignResourcesAfter"(hd cleanup)=Json.String "0","worker did not release all native resources")
        val ()=expectedPhases runtimePhases measured
        val ()=List.app(fn row=>let val phase=text(field "phase" row)
          val count=if String.isSuffix "-first" phase then 1 else if phase="prepare" orelse phase="load-symbol"
            then Int.max(10,iterations div 100) else iterations
          in need(integer(field "iterations" row)=count,"worker changed iteration count") end)measured
    in measured end
  val shimBinaries=ref([]:Json.value list)
  fun one n=
    let fun c()=let val result=rows(output[direct,Int.toString iterations])
          in expectedPhases["scalar","marshal-256","callback"]result;
             List.app(fn row=>need(integer(field "iterations" row)=iterations,"C baseline changed iteration count"))result;result end
        fun sml()=runtimeRows(output(vm::vmOptions @ [worker,subject,Int.toString iterations]))
        val result=if n mod 2=0 then c() @ sml() else let val measured=sml() in c() @ measured end
        val generated=rows(output(vm::vmOptions @ [generation,sourceRoot]))
        val ()=expectedPhases generationPhases generated
        val ()=List.app(fn row=>need(integer(field "iterations" row)=(if text(field "phase" row)="generation-first" then 1 else 10),"generator changed iteration count"))generated
        fun generationChecksum phase=field "checksum"(valOf(List.find(fn row=>text(field "phase" row)=phase)generated))
        val ()=need(generationChecksum "generation-first"=generationChecksum "generation-warm","first and warm generation output sizes differ")
        val binary=directory ^ "/shim-" ^ Int.toString n ^ ".so"
        val compiled=command(compiler::flags @ ["-shared","-fPIC","-I" ^ safeRoot,shim,"-o",binary])
        val ()=shimBinaries:= !shimBinaries @ [hashed binary]
        val compileRow=Json.Object[("implementation",Json.String "c-compiler"),("phase",Json.String "shim-compile"),
          ("iterations",Json.int 1),("cpuSeconds",number(#cpu compiled)),("wallSeconds",number(#wall compiled)),
          ("cpuAccounting",Json.String "reaped child user+system CPU"),("checksum",Json.String(hashValue binary)),
          ("bufferPayloadAllocatedBytes",Json.int 0),("peakBufferPayloadBytes",Json.int 0),("nativeMetadataBytes",Json.Null)]
        val measured=result @ generated @ [compileRow]
        val ()=List.app checkRow measured
        fun sample(Json.Object fields)=Json.Object(("sample",Json.int n)::fields) | sample _=raise Fail "expected object"
    in List.map sample measured end
  fun gather n values=if n=samples then values else
    let val next=values @ one n val ()=write(directory ^ "/samples.json",Json.encodeIndented 2(Json.Array next) ^ "\n")
    in gather(n+1)next end
  val measurements=gather 0 []
  fun perOperation key row=case optional key row of NONE=>NONE | SOME value=>SOME(value/Real.fromInt(integer(field "iterations" row)))
  fun selected implementation phase=List.filter(fn row=>text(field "implementation" row)=implementation andalso text(field "phase" row)=phase)measurements
  fun summary implementation phase=
    let val values=selected implementation phase
        fun metric key scale=distribution(List.mapPartial(fn row=>Option.map(fn value=>value*scale)(perOperation key row))values)
    in if null values then NONE else SOME(Json.Object[("implementation",Json.String implementation),("phase",Json.String phase),
      ("cpuNsPerOperation",metric "cpuSeconds" 1.0E9),("wallNsPerOperation",metric "wallSeconds" 1.0E9),
      ("smlAllocatedBytesPerOperation",metric "smlAllocatedBytes" 1.0),("smlAllocatedObjectsPerOperation",metric "smlAllocatedObjects" 1.0),
      ("collectionsPerOperation",metric "collections" 1.0),("bufferPayloadAllocatedBytesPerOperation",metric "bufferPayloadAllocatedBytes" 1.0)]) end
  fun ratio phase=
    let fun pair n=
          let fun row impl=List.find(fn row=>integer(field "sample" row)=n)(selected impl phase)
          in case(row "rune",row "direct-c") of (SOME rune,SOME direct)=>
               let val c=valOf(perOperation "cpuSeconds" direct) val r=valOf(perOperation "cpuSeconds" rune)
               in if c>0.0 then SOME(r/c) else NONE end | _=>NONE end
    in Json.Object[("phase",Json.String phase),("runeToDirectCCpuRatio",distribution(List.mapPartial pair(List.tabulate(samples,fn n=>n))))] end
  val ()=List.app(fn(path,digest)=>need(hashValue path=digest,"measurement source changed during run: " ^ path))sourceHashes
  val ()=need(hashValue vm=vmHash,"measurement VM changed during run")
  val ()=need(hashValue compiler=compilerHash andalso hashValue rune=runeHash,"measurement compiler changed during run")
  val ()=case compilerBytecodeHash of NONE=>() | SOME digest=>need(hashValue compilerBytecode=digest,"compiler bytecode changed during run")
  val summaries=List.concat(List.map(fn phase=>List.mapPartial(fn implementation=>summary implementation phase)["rune","direct-c","c-compiler"])
    (runtimePhases @ generationPhases @ ["shim-compile"]))
  val report=Json.Object[("schema",Json.int 2),("date",Json.String(Date.fmt "%Y-%m-%dT%H:%M:%SZ"(Date.fromTimeUniv(Time.now())))),
    ("compiler",Json.String(output[compiler,"--version"])),("compilerBinary",hashed compiler),
    ("vm",Json.String(output[vm,"--version"])),("vmBinary",hashed vm),("compilerDriver",hashed rune),
    ("compilerBytecode",case compilerBytecodeHash of NONE=>Json.Null | SOME _=>hashed compilerBytecode),
    ("revision",Json.String revision),("libraryRevision",Json.String libraryRevision),("libraryRoot",Json.String lib),
    ("productionSourceRoot",Json.String sourceRoot),("worker",hashed worker),("generationWorker",hashed generation),("generatorCli",hashed cli),
    ("vmOptions",Json.Array(List.map Json.String vmOptions)),("cFlags",Json.Array(List.map Json.String flags)),
    ("sourceHashes",Json.Array(List.map(fn(path,digest)=>Json.Object[("path",Json.String path),("sha256",Json.String digest)])sourceHashes)),
    ("subject",hashed subject),("directExecutable",hashed direct),("shimSource",hashed shim),("shimBinaries",Json.Array(!shimBinaries)),
    ("platform",Json.Object(List.map(fn(k,v)=>(k,Json.String v))(Posix.ProcEnv.uname()))),
    ("quantiles",Json.String "nearest rank p25/p75/p95; midpoint median for even sample counts"),
    ("memoryAccounting",Json.String "SML Runtime.stats allocation deltas include constant measurement overhead; loop is a separate control baseline. Native payload counts cover only the temporary 256-byte buffer, excluding allocator/resource/libffi metadata and executable closures."),
    ("cacheAccounting",Json.String "generation-first is first use in a fresh worker VM; generation-warm repeats ten times in that VM. Filesystem/CPU caches are uncontrolled. Stage timings reuse prior stage outputs."),
    ("samples",Json.Array measurements),("summary",Json.Array summaries),
    ("pairedComparisons",Json.Array(List.map ratio["scalar","marshal-256","callback"]))]
  val ()=write(directory ^ "/results.json",Json.encodeIndented 2 report ^ "\n")
  val ()=print("PASS phase-separated FFI measurements schema2: " ^ directory ^ "/results.json\n")
end

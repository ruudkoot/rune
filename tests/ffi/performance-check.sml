(* Opt-in measurements: bounded subprocesses, retained identities/commands and
   independent direct-C checksums. No wall-time threshold is a test oracle. *)
structure FfiPerformanceChecks =
struct
  open Sh
  fun need(condition,message)=if condition then () else raise Fail message
  val (directory,iterations,samples)=case CommandLine.arguments() of [directory,count,repetitions]=>
      (directory,valOf(Int.fromString count),valOf(Int.fromString repetitions))
    | _=>raise Fail "usage: rune-ffi-performance OUTPUT-DIRECTORY ITERATIONS SAMPLES"
  val ()=need(iterations>=100 andalso iterations<=10000000 andalso samples>=3 andalso samples<=20,"measurement range")
  val ()=mkdirs directory
  val index=ref 0
  fun command arguments=
    let val n= !index val ()=index:=n+1 val prefix=directory ^ "/command-" ^ Int.toString n
        val ()=write(prefix ^ ".json",Json.encode(Json.Array(List.map Json.String arguments)) ^ "\n")
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=arguments,dir=SOME root,stdin="",
          stdout=prefix ^ ".out",stderr=prefix ^ ".err",timeout=600}
        val ()=need(status=0,"measurement command exited " ^ Int.toString status ^ ": " ^ prefix)
    in read(prefix ^ ".out") end
  val compiler=env("CC","cc")
  val rune=env("RUNE","bin/rune")
  val vm=env("RUNEVM","bin/runevm")
  val lib=env("RUNE_LIB","lib")
  val mode=env("FFI_PERF_MODE","off")
  val ()=need(List.exists(fn name=>name=mode)["off","baseline","opt","all"],"unknown FFI_PERF_MODE")
  val vmOptions=["--jit=" ^ mode]
  val subject=directory ^ "/libsubject.so"
  val direct=directory ^ "/direct"
  val worker=directory ^ "/worker.rbc"
  val generation=directory ^ "/generation.rbc"
  val flags=["-std=c17","-O2","-Wall","-Wextra","-Werror","-pedantic"]
  val ()=ignore(command(compiler::flags @ ["-shared","-fPIC","tests/ffi/performance.c","-o",subject]))
  val ()=ignore(command(compiler::flags @ ["tests/ffi/performance-direct.c","-L" ^ directory,"-lsubject",
    "-Wl,-rpath," ^ OS.FileSys.fullPath directory,"-o",direct]))
  val ()=ignore(command[rune,"--lib",lib,"--library","ffi/runtime","--library","json","tests/ffi/performance.sml","-o",worker])
  val ()=ignore(command[rune,"--lib",lib,"--library","ffi/model","--library","digest","src/ffi/main.sml",
    "tests/ffi/performance-generation.sml","-o",generation])
  fun field name value=case Json.member(name,value) of SOME v=>v | NONE=>raise Fail("missing " ^ name)
  fun text(Json.String value)=value | text _=raise Fail "expected text"
  fun integer(Json.Number value)=valOf(Int.fromString value) | integer _=raise Fail "expected count"
  fun real(Json.Number value)=valOf(Real.fromString value) | real _=raise Fail "expected seconds"
  fun rows output=List.map Json.decode(lines output)
  fun check rows=
    List.app(fn row=>let val phase=text(field "phase" row) val count=integer(field "iterations" row)
          val expected=if phase="scalar" orelse phase="callback" then SOME count
            else if phase="marshal-256" then SOME(count mod 256) else NONE
          val ()=need(count>0 andalso real(field "cpuSeconds" row)>=0.0,"invalid measurement")
      in case expected of NONE=>() | SOME value=>need(text(field "checksum" row)=Int.toString value,"independent checksum mismatch") end)rows
  fun one n=
    let fun c()=rows(command[direct,Int.toString iterations])
        fun sml()=rows(command(vm::vmOptions @ [worker,subject,Int.toString iterations]))
        val result=if n mod 2=0 then c() @ sml() else let val rune=sml() in c() @ rune end
        val generated=rows(command(vm::vmOptions @ [generation]))
        val ()=check result val ()=check generated
        fun sample(Json.Object fields)=Json.Object(("sample",Json.int n)::fields)
          | sample _=raise Fail "expected measurement object"
    in List.map sample(result @ generated) end
  val measurements=List.concat(List.tabulate(samples,one))
  fun insert x []=[x] | insert x (y::ys)=if x<y then x::y::ys else y::insert x ys
  fun median values=List.nth(List.foldl(fn(x,xs)=>insert x xs)[]values,length values div 2)
  fun perCall row=real(field "cpuSeconds" row)/Real.fromInt(integer(field "iterations" row))
  fun selected implementation phase=List.filter(fn row=>text(field "implementation" row)=implementation andalso text(field "phase" row)=phase)measurements
  fun number n=Json.Number(Real.toString n)
  fun summary phase=
    let val rune=median(List.map perCall(selected "rune" phase)) val c=selected "direct-c" phase
        val baseline=if null c then NONE else SOME(median(List.map perCall c))
    in Json.Object[("phase",Json.String phase),("runeCpuNs",number(rune*1.0E9)),
      ("directCCpuNs",case baseline of NONE=>Json.Null | SOME n=>number(n*1.0E9)),
      ("ratio",case baseline of SOME n=>if n>0.0 then number(rune/n) else Json.Null | NONE=>Json.Null)] end
  val compilerIdentity=command[compiler,"--version"]
  val vmIdentity=command[vm,"--version"]
  val revision=command["git","rev-parse","HEAD"]
  val libraryRevision=command["git","-C",OS.Path.dir(OS.FileSys.fullPath lib),"rev-parse","HEAD"]
  val sources=["tests/ffi/performance.c","tests/ffi/performance-direct.c","tests/ffi/performance.sml",
    "tests/ffi/performance-generation.sml","tests/ffi/performance-check.sml"]
  fun hash path=Json.Object[("path",Json.String path),("sha256",Json.String(Hex.fromBytes(Sha256.digest(read path))))]
  val report=Json.Object[("schema",Json.int 1),("date",Json.String(Date.fmt "%Y-%m-%dT%H:%M:%SZ"(Date.fromTimeUniv(Time.now())))),
    ("compiler",Json.String compilerIdentity),("vm",Json.String vmIdentity),("revision",Json.String revision),
    ("libraryRevision",Json.String libraryRevision),("libraryRoot",Json.String(OS.FileSys.fullPath lib)),
    ("vmSha256",Json.String(Hex.fromBytes(Sha256.digest(read vm)))),
    ("workerSha256",Json.String(Hex.fromBytes(Sha256.digest(read worker)))),
    ("generationSha256",Json.String(Hex.fromBytes(Sha256.digest(read generation)))),
    ("vmOptions",Json.Array(List.map Json.String vmOptions)),("cFlags",Json.Array(List.map Json.String flags)),
    ("sources",Json.Array(List.map hash sources)),("subjectSha256",Json.String(Hex.fromBytes(Sha256.digest(read subject)))),
    ("platform",Json.Object(List.map(fn(k,v)=>(k,Json.String v))(Posix.ProcEnv.uname()))),
    ("samples",Json.Array measurements),("summary",Json.Array(List.map summary["generation","load-symbol","prepare","scalar","marshal-256","callback"]))]
  val ()=write(directory ^ "/results.json",Json.encodeIndented 2 report ^ "\n")
  val ()=print("PASS phase-separated FFI measurements: " ^ directory ^ "/results.json\n")
end

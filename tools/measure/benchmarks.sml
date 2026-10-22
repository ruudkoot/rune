(* Benchmark measurement phases. Workload and configuration decisions are
   shared SML models; GNU time/perf/quota commands are external instruments. *)
structure MeasureBenchmarks =
struct
  open MeasureCommon
  fun main args =
    let val (action,args)=case args of [] => ("time",[]) | first::rest => if List.exists (fn x => x=first) ["time","count","stats"] then (first,rest) else ("time",args)
        val profile=ref (env ("BENCH_PROFILE","normal")) val configs=ref (env ("BENCH_CONFIGS","rune,native:mlton,native:smlnj-legacy,native:polyml"))
        val filter=ref (env ("BENCH_FILTER","")) val samples=ref (integer (env ("BENCH_SAMPLES","10"))) val rounds=ref (integer (env ("BENCH_REPETITIONS","10")))
        val mode=ref (env ("BENCH_MODE","fresh")) val level=ref (env ("BENCH_LEVEL","2")) val update=ref false
        val options=env ("RUNEVM_OPTIONS","")
        fun parse []=() | parse ("--profile"::v::rest)=(profile:=v;parse rest) | parse ("--configs"::v::rest)=(configs:=v;parse rest)
          | parse ("--filter"::v::rest)=(filter:=v;parse rest) | parse ("--samples"::v::rest)=(samples:=integer v;parse rest)
          | parse ("--mode"::v::rest)=(mode:=v;parse rest) | parse ("--repetitions"::v::rest)=(rounds:=integer v;parse rest)
          | parse ("--level"::v::rest)=(level:=v;parse rest) | parse ("--update-budgets"::rest)=(update:=true;parse rest)
          | parse _=raise Usage "benchmarks [time|count|stats] [--profile P] [--configs LIST] [--filter NAME] [--samples N] [--mode fresh|repeated] [--repetitions N] [--level 0|2] [--update-budgets]"
        val ()=parse args
        val ()=need (!level="0" orelse !level="2","level must be 0 or 2")
        val ()=need (List.exists (fn x => x= !mode) ["fresh","repeated"],"mode must be fresh or repeated")
        val ()=need (!samples>=1 andalso !samples<=100000 andalso !rounds>=1 andalso !rounds<=100000,"invalid sample/repetition count")
        val ()=if action="time" then need (not (List.exists (fn option => List.exists (fn bad => bad=option) ["--count","--stats","--jit-stats","--trace"]) (CommandWords.split options)),"instrumented VM options require a separate count/stats run") else ()
        val ()=need (action="count" orelse not (!update),"budgets apply only to count runs")
        val ()=if !mode="fresh" then rounds:=1 else ()
        val ()=if action="time" then () else (samples:=1;rounds:=1;mode:="fresh";if !configs="rune,native:mlton,native:smlnj-legacy,native:polyml" then configs:="rune,rune:jit,rune:stack,rune:opt" else ())
        val parent=fromRoot "tests/out/benchmarks" val ()=mkdirs parent
        val output=parent ^ "/measurement." ^ Date.fmt "%Y%m%d-%H%M%S" (Date.fromTimeUniv (Time.now ())) ^ "-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
        val ()=mkdirs output val ()=say ("BENCH MEASUREMENT " ^ output ^ "\n")
        val entries=BenchCatalog.selected (BenchCatalog.load (fromRoot "examples/benchmarks/manifest.tsv")) (!profile) (!filter)
        val ()=need (not (null entries),"no benchmark matches")
        val ()=write (output ^ "/jobs.tsv",String.concat (List.map (fn entry:BenchCatalog.entry => String.concatWith "\t" [#name entry,Int.toString (#seconds entry),Int.toString (#memory entry),String.concatWith " " (#sources entry),String.concatWith " " (#args entry),#expected entry,if null (#inputFiles entry) then "-" else String.concatWith " " (#inputFiles entry)] ^ "\n") entries))
        val rows=output ^ "/samples.tsv"
        val ()=write (rows,"benchmark\tprofile\tconfig\tlevel\tphase\tprocess\tround\tstatus\tseconds\tuser_seconds\tsystem_seconds\tmax_rss_kib\tinstructions\tbytes\tobjects\tartifact\n")
        val lastConfig=ref ""
        val failed=ref false
        val locale=setEnv ("LC_ALL","C") o setEnv ("TZ","NST3:30NDT,M3.2.0,M11.1.0")
        fun capture label args=successful (child {args=args,directory=root,input="",prefix=output ^ "/" ^ label,timeout=600,environment=locale})
        val metadata=[("date_utc",trim (capture "date" ["date","-u","+%FT%TZ"])),("revision",trim (capture "revision" ["git","rev-parse","HEAD"])),
             ("dirty",Int.toString (length (lines (capture "status" ["git","status","--porcelain"])))),("action",action),("mode",!mode),("samples",Int.toString (!samples)),("repetitions",Int.toString (!rounds)),
             ("level",!level),("profile",!profile),("configs",!configs),("filter",!filter),("machine",trim (capture "uname" ["uname","-a"])),
             ("time_tool",case lines (capture "time-version" ["/usr/bin/time","--version"]) of first::_ => first | [] => ""),("runtime_options",options),
             ("timezone","NST3:30NDT,M3.2.0,M11.1.0"),("locale","C"),("limit_method","AS except PolyML data quota and capped managed heap"),
             ("compile_samples","1 fresh build per workload/configuration"),("os_clock_resolution","GNU time wall seconds printed to hundredths"),
             ("in_process_clock","SML Time.now, formatted to nanoseconds; precision is host dependent"),("native_options","compiler defaults; level column refers to Rune only")]
        val ()=write (output ^ "/metadata.tsv",String.concat (List.map (fn (k,v) => k ^ "\t" ^ v ^ "\n") metadata))
        val ()=write (output ^ "/worktree.patch",capture "patch" ["git","diff","--binary","HEAD"])
        val ()=write (output ^ "/worktree-status.txt",capture "worktree" ["git","status","--porcelain"])
        val ()=List.app (fn file => copy (fromRoot ("examples/benchmarks/" ^ file)) (output ^ "/" ^ file)) ["manifest.tsv","upstreams.tsv"]
        val sourceFiles=["Makefile","tests/runner/sh.sml","tests/runner/children.sml","tests/runner/commandwords.sml","tests/runner/terminalpattern.sml"] @
             List.map (fn file => "tools/measure/" ^ file) (List.filter (String.isSuffix ".sml") (Sh.entries (fromRoot "tools/measure"))) @
             List.map (fn file => "tests/runner/" ^ file) (List.filter (fn file => String.isPrefix "matrix" file andalso String.isSuffix ".sml" file) (Sh.entries (fromRoot "tests/runner"))) @
             ["examples/benchmarks/shared/catalog.sml","examples/benchmarks/shared/report.sml","examples/benchmarks/shared/counts.sml"]
        val sourceFiles=sort sourceFiles
        val payloads=[CommandLine.name (),fromRoot "bin/runevm",fromRoot "bin/rune-matrix.rbc",fromRoot "build/bench-report.rbc",fromRoot "build/bench-counts.rbc"]
        val ()=write (output ^ "/controller-payloads.sha256",String.concat (List.map (fn file => hash file ^ "  " ^ file ^ "\n") payloads))
        val ()=List.app (fn file => copy (fromRoot file) (output ^ "/tool-sources/" ^ file)) sourceFiles
        val ()=write (output ^ "/tool-sources.sha256",String.concat (List.map (fn file => hash (output ^ "/tool-sources/" ^ file) ^ "  tool-sources/" ^ file ^ "\n") (sort sourceFiles)))
        val ()=write (output ^ "/machine.txt",capture "machine" ["uname","-a"] ^ read "/proc/cpuinfo" ^ read "/proc/meminfo" ^ read "/proc/loadavg")
        val ()=write (output ^ "/configurations.tsv","")
        fun sum file=hash file ^ "  " ^ file ^ "\n"
        fun phase (entry:BenchCatalog.entry) quota directory input args changes =
          let val ()=mkdirs directory
              val ()=write (directory ^ "/command.txt",String.concat (List.map (fn word => word ^ "\n") args))
              val ()=write (directory ^ "/settings.tsv","timeout_seconds\t" ^ Int.toString (#seconds entry) ^ "\nmemory_kib\t" ^ Int.toString (#memory entry) ^ "\nquota\t" ^ quota ^ "\nruntime_options\t" ^ options ^ "\n")
              val command=["/usr/bin/time","-f","%e\t%U\t%S\t%M","-o",directory ^ "/os.tsv","timeout",Int.toString (#seconds entry),"/bin/sh","-c",
                       "ulimit -c 0; ulimit -\"$1\" \"$2\" || exit 125; shift 2; exec \"$@\"","bench-limit",quota,Int.toString (#memory entry)] @ args
              val result=child {args=command,directory=if input="" then root else directory ^ "/work",input=if input="" then "/dev/null" else input,prefix=directory ^ "/process",timeout= #seconds entry+15,environment=changes o locale}
              val ()=(copy (directory ^ "/process.stdout") (directory ^ "/stdout");copy (directory ^ "/process.stderr") (directory ^ "/stderr"));
              val ()=write (directory ^ "/exit",Int.toString (#status result) ^ "\n")
          in result end
        fun record name id directory phase process round category seconds counters =
          let val metrics=case List.rev (lines (read (directory ^ "/os.tsv"))) of first::_ => tabs first | [] => ["0","0","0","0"]
              val metrics=if length metrics=4 then metrics else ["0","0","0","0"]
              val seconds=getOpt (seconds,hd metrics)
              val artifact=if String.isPrefix (output ^ "/") directory then String.extract (directory,size output+1,NONE) else directory
          in append (rows,String.concatWith "\t" ([name,!profile,id,"O" ^ !level,phase,Int.toString process,Int.toString round,category,seconds] @ List.drop (metrics,1) @ counters @ [artifact]) ^ "\n") end
        fun stage (entry:BenchCatalog.entry) destination=List.app (fn file => copy (fromRoot ("examples/benchmarks/" ^ #name entry ^ "/" ^ file)) (destination ^ "/" ^ file)) (#inputFiles entry)
        fun config (entry:BenchCatalog.entry) spec =
          let val name= #name entry
              val id=ref spec
              val configDir=output ^ "/" ^ name ^ "/" ^ String.translate (fn #":" => "-" | #"/" => "-" | c => str c) spec
              val ()=mkdirs configDir
              val resolve=child {args=[fromRoot "bin/rune-matrix","--timing","--configs",spec,"--resolve-out",configDir ^ "/config.tsv"],directory=root,input="",prefix=configDir ^ "/resolve",timeout=180,
                           environment=setEnv ("RUNE_MATRIX_RUN",configDir ^ "/resolve-work") o setEnv ("RUNEVM_OPTIONS",options) o locale}
              val configuration=if #status resolve<>0 then NONE else case lines (read (configDir ^ "/config.tsv")) of [line] => SOME (tabs line) | _ => raise Failed "use explicit configurations, not groups"
          in case configuration of NONE => (failed:=true;record name (!id) configDir "configuration" 0 0 "missing-configuration" (SOME "0") ["-","-","-"])
            | SOME values =>
             let val ()=need (length values>=5,"invalid resolved configuration") val ()=id:=hd values
                 val kind=List.nth (values,1) val host=List.nth (values,2) val compiler=List.nth (values,3) val runtime=List.nth (values,4)
                 val ()=lastConfig:= !id
                 val ()=append (output ^ "/configurations.tsv",String.concatWith "\t" values ^ "\n")
             in if kind="xc1" orelse (action<>"time" andalso kind<>"rune") then
                  (failed:=true;record name (!id) configDir "configuration" 0 0 "missing-configuration" (SOME "0") ["-","-","-"])
                else
                let val bundle=configDir ^ "/build" val ()=mkdirs (bundle ^ "/sources")
                    val sources=ListPair.map (fn (source,index) =>
                       let val source=if action="time" andalso source="shared/main.sml" then "shared/measure.sml" else source
                           val target=bundle ^ "/sources/" ^ Int.toString index ^ ".sml" val ()=copy (fromRoot ("examples/benchmarks/" ^ source)) target
                       in (source,target) end) (#sources entry,List.tabulate (length (#sources entry),fn i => i+1))
                    val ()=write (bundle ^ "/identities.tsv",String.concat (List.map (fn (source,target) => source ^ "\t" ^ hash target ^ "\n") sources))
                    val ()=copy (fromRoot ("examples/benchmarks/" ^ #expected entry)) (bundle ^ "/expected")
                    val input=configDir ^ "/input"
                    val ()=write (input,name ^ "\n" ^ String.concatWith " " (#args entry) ^ "\n" ^ read (bundle ^ "/expected") ^ (if action="time" then Int.toString (!rounds) ^ "\n" else ""))
                    val ()=(mkdirs (bundle ^ "/data");stage entry (bundle ^ "/data"))
                    val files=List.map (fn (_,target) => target) sources @ List.filter (fn file => not (isDir file)) (MeasureCommon.files (bundle ^ "/data"))
                    val files=sort files
                    val ()=write (bundle ^ "/sha256.tsv",String.concat (List.map (fn file => hash file ^ "  " ^ String.extract (file,size bundle+1,NONE) ^ "\n") files) ^ hash (bundle ^ "/expected") ^ "  expected\n")
                    val ()=write (bundle ^ "/compiler.sha256",sum compiler)
                    val ()=if kind<>"rune" then () else
                         (write (bundle ^ "/runtime.sha256",sum runtime);ignore (MeasureBasics.provenance "compiler" compiler bundle);ignore (MeasureBasics.provenance "runtime" runtime bundle);
                          write (bundle ^ "/rune-payloads.sha256",read (bundle ^ "/compiler-payloads.sha256") ^ read (bundle ^ "/runtime-payloads.sha256")))
                    val launch=bundle ^ "/launch.sml"
                    val ()=if action="time" then write (launch,"val _ = OS.Process.exit (BenchMeasure.main ())\n") else ()
                    val sourceList=List.map #2 sources @ (if action="time" then [launch] else [])
                    val ()=write (bundle ^ "/sources.txt",String.concat (List.map (fn file => file ^ "\n") sourceList))
                    val quota=if host="polyml" then "d" else "v"
                    val baseEnv=setEnv ("RUNEVM_OPTIONS",options)
                    val (compile,runCommand,runFile,compilePhase)=
                     if kind="rune" then
                       let val compiled=phase entry quota (bundle ^ "/compile") "" (compiler::("-O" ^ !level)::"--lint"::sourceList @ ["-o",bundle ^ "/prog.rbc"]) baseEnv
                       in if host<>"opt" orelse #status compiled<>0 then (compiled,runtime,bundle ^ "/prog.rbc","compile") else
                         let val category=MeasureCommon.category {status= #status compiled,output= #output compiled,errors= #errors compiled,failure="compile-error"}
                             val ()=record name (!id) (bundle ^ "/compile") "compile" 0 0 category NONE ["-","-","-"]
                             val opt=env ("RUNEOPT",fromRoot "bin/runeopt-mlton")
                             val ()=write (bundle ^ "/native-compiler.sha256",sum opt) val _=MeasureBasics.provenance "native-compiler" opt bundle
                             val native=phase entry quota (bundle ^ "/native-compile") "" [opt,bundle ^ "/prog.rbc","-o",bundle ^ "/prog"] baseEnv
                         in (native,bundle ^ "/prog","","native-compile") end end
                     else if host="mlton" orelse host="mlkit" then
                       let val mlb=bundle ^ "/prog.mlb" val ()=write (mlb,"$(SML_LIB)/basis/basis.mlb\n" ^ String.concat (List.map (fn file => file ^ "\n") sourceList))
                           val command=if host="mlton" then [compiler,"-output",bundle ^ "/prog",mlb] else [compiler,"--no_messages","-o",bundle ^ "/prog",mlb]
                           val env=if host="mlkit" then setEnv ("SML_LIB",runtime) o baseEnv else baseEnv
                       in (phase entry quota (bundle ^ "/compile") "" command env,bundle ^ "/prog","","compile") end
                     else if String.isPrefix "smlnj" host then
                       let val export=bundle ^ "/export.sml"
                           val ()=write (export,String.concat (List.map (fn (_,file) => "val _ = use " ^ Json.encode (Json.String file) ^ ";\n") sources)
                                  ^ "val _ = SMLofNJ.exportFn (" ^ Json.encode (Json.String (bundle ^ "/prog")) ^ ", fn _ => BenchMeasure.main ());\nval _ = OS.Process.exit OS.Process.success;\n")
                           val compiled=phase entry quota (bundle ^ "/compile") "" [compiler,export] baseEnv
                           val images=List.filter (String.isPrefix "prog.") (Sh.entries bundle)
                           val compiled=if #status compiled=0 andalso null images then
                                (append (bundle ^ "/compile/stderr","compiler exited successfully without an exported SML/NJ image\n");{status=1,output= #output compiled,errors= #errors compiled ^ "compiler exited successfully without an exported SML/NJ image\n"}) else compiled
                       in (compiled,compiler,"@SMLload=" ^ bundle ^ "/prog","compile") end
                     else if host="polyml" then
                       let val export=bundle ^ "/export.sml" val ()=write (export,String.concat (List.map (fn (_,file) => "val _ = use " ^ Json.encode (Json.String file) ^ ";\n") sources) ^ "fun main () = OS.Process.exit (BenchMeasure.main ());\n")
                       in (phase entry quota (bundle ^ "/compile") "" [OS.Path.dir compiler ^ "/polyc","-b",compiler,"-o",bundle ^ "/prog",export] baseEnv,bundle ^ "/prog","","compile") end
                     else ({status=1,output="",errors="unsupported configuration"},"","","compile")
                    val category=MeasureCommon.category {status= #status compile,output= #output compile,errors= #errors compile,failure="compile-error"}
                    val ()=record name (!id) (bundle ^ "/" ^ compilePhase) compilePhase 0 0 category NONE ["-","-","-"]
                in if category<>"pass" then failed:=true else
                  let val artifacts=List.map (fn file => bundle ^ "/" ^ file) (List.filter (String.isPrefix "prog") (Sh.entries bundle))
                      val ()=write (bundle ^ "/artifacts.sha256",String.concat (List.map sum (sort artifacts)))
                      fun process i=if i> !samples then () else
                        let val runPhase=if i=0 then "correctness" else !mode val directory=configDir ^ "/" ^ runPhase ^ "." ^ Int.toString i
                            val ()=mkdirs (directory ^ "/work") val ()=stage entry (directory ^ "/work")
                            val (command,file)=if kind="rune" andalso host<>"opt" then
                                 (copy (bundle ^ "/prog.rbc") (directory ^ "/work/prog.rbc");(runCommand,"prog.rbc"))
                              else if exists (bundle ^ "/prog") then
                                 (copy (bundle ^ "/prog") (directory ^ "/work/prog");Posix.FileSys.chmod (directory ^ "/work/prog",Posix.FileSys.ST.mode (Posix.FileSys.stat (bundle ^ "/prog")));("./prog",runFile)) else (runCommand,runFile)
                            val flags=if action="count" then ["--count"] else if action="stats" then ["--stats"] else []
                            val command=[command] @ flags @ (if file="" then [] else [file])
                            val (command,env)=if host="opt" then (["./prog"],setEnv ("RUNEVM_NAME","prog.rbc") o setEnv ("RUNEVM_OPTIONS",options ^ String.concat (List.map (fn flag => " " ^ flag) flags))) else (command,baseEnv)
                            val command=if host="polyml" then command @ ["-H","16","--maxheap",Int.toString (#memory entry div 2048),"--stackspace","64"] else command
                            val result=phase entry quota directory input command env
                            val category=MeasureCommon.validate {status= #status result,output= #output result,errors= #errors result,rounds= !rounds}
                            val category=if action="time" andalso category="pass" andalso length (prefixed "SAMPLE " (#output result))<> !rounds then "incorrect-result" else category
                            val counters=if action="count" andalso category="pass" then
                                  (case find "runevm: count:" (#errors result) of NONE => NONE | SOME line =>
                                     let val words=String.tokens (fn c => Char.isSpace c orelse c = #",") line
                                     in if length words=8 then SOME [List.nth (words,2),List.nth (words,4),List.nth (words,6)] else NONE end) else SOME ["-","-","-"]
                            val category=if not (isSome counters) then "missing-counters" else category
                            val counters=getOpt (counters,["-","-","-"])
                            val ()=if category="pass" then () else failed:=true
                            val ()=if i=0 then record name (!id) directory "correctness" 0 0 category NONE counters
                                  else if action<>"time" then record name (!id) directory action i 1 category NONE counters
                                  else if !mode="fresh" orelse category<>"pass" then record name (!id) directory (!mode) i 1 category NONE counters
                                  else List.app (fn line => case String.tokens Char.isSpace line of [_,round,seconds] => record name (!id) directory "repeated" i (integer round) "pass" (SOME seconds) counters | _ => raise Failed "malformed in-process timing sample") (prefixed "SAMPLE " (#output result))
                        in if category="pass" then process (i+1) else () end
                  in process 0 end end end end
        val ()=List.app (fn entry:BenchCatalog.entry => (say ("BENCH MEASURE " ^ #name entry ^ " " ^ !profile ^ " " ^ action ^ "\n");List.app (config entry) (fields #"," (!configs)))) entries
        val ()=if action<>"count" orelse !failed then () else
             let val directory=output ^ "/count-check" val ()=mkdirs directory
                 val result=execute root (directory ^ "/process") [fromRoot "bin/runevm-stack",fromRoot "build/bench-counts.rbc",rows,fromRoot "examples/benchmarks/count-budgets.tsv",if !update then "update" else "check"]
                 val ()=(write (directory ^ "/stdout",#output result);write (directory ^ "/stderr",#errors result))
                 val category=if #status result=0 then "pass" else if String.isSubstring "disagree" (#errors result) then "count-mismatch" else if String.isSubstring "budget exceeded" (#errors result) then "count-budget" else "count-check-failure"
                 val ()=if #status result=0 then () else failed:=true
             in record "" (!lastConfig) directory "count-check" 0 0 category (SOME "0") ["-","-","-"];say (#output result ^ #errors result) end
        val report=execute root (output ^ "/report-process") [fromRoot "bin/runevm-stack",fromRoot "build/bench-report.rbc",rows]
        val ()=need (#status report=0,"benchmark reporter failed") val ()=write (output ^ "/report.md",#output report)
    in say ("BENCH REPORT " ^ output ^ "/report.md\n");if !failed then 1 else 0 end
end

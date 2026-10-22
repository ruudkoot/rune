(* Optional IntInf measurements reuse bounded SML process measurement. Fixed
   sources and answers were calculated by the independent Python oracle;
   timing samples never contribute expected arithmetic answers. *)
structure IntInfMeasurements =
struct
  open IntInfChecks
  fun one (c : context) {samples,pairedOracle,pairedSML,compilerWorkloads} () =
    let val ()=rmTree (path c "report.json")
        val ()=need (samples>=2,"at least two IntInf samples are required")
        val ()=need (not (pairedOracle andalso pairedSML),"choose one paired reference")
        val _=semantic c (#vm c) []
        fun measured label args =
          let val ()= #sequence c := !(#sequence c)+1
              val prefix=path c (StringCvt.padLeft #"0" 3 (Int.toString (!(#sequence c))) ^ "-" ^ label)
              val ()=write (prefix ^ ".command.json",Json.encode (Json.Array (List.map Json.String args)) ^ "\n")
              val result=Measured.execute {args=args,environment=environment [] (Posix.ProcEnv.environ ()),directory=root,prefix=prefix,
                    timeout=180,limits={addressSpace=SOME (4*1024*1024*1024),cpuTime=NONE,fileSize=SOME (64*1024*1024),core=SOME 0}}
          in need (#status result=0,"IntInf measurement failed: " ^ label ^ ": " ^ #errors result);result end
        fun compile name text extra =
          let val file=path c (name ^ ".sml")
              val program=path c (name ^ ".rbc")
              val ()=(write (file,text);rmTree program)
              val result=measured (name ^ "-compile") ([#compiler c,"--lib","lib","--target=" ^ #target c,"-o",program] @ extra @ [file])
          in need (exists program,"measurement compiler produced no bytecode");(program,Measured.usage result) end
        fun meta label args = #output (measured ("metadata-" ^ label) args)
        fun hash file=Hex.fromBytes (Sha256.digest (CachePlant.binary file))
        val fixtureRoot=fromRoot "tests/intinf/fixtures"
        val manifest=Json.decode (read (fixtureRoot ^ "/manifest.json"))
        val definitions=array (field "workloads" manifest)
        val sourceFiles=["tests/runner/intinf-main.sml","tests/runner/intinfchecks.sml","tests/runner/intinfbackends.sml","tests/runner/intinfhardening.sml","tests/runner/intinfstorage.sml","tests/runner/commandwords.sml","tests/runner/sh.sml","tests/runner/children.sml","tests/runner/intinfmeasurements.sml","tests/runner/measured.sml","tests/intinf/checks.sml","tests/intinf/oracle.sml",
             "tests/intinf/workloads.json","tests/intinf/fixtures/manifest.json","tests/intinf/fixtures/vectors.sml","lib/basis/intinf.sml","lib/basis/MANIFEST",
             "Makefile","runtime/prims.c","runtime/value.h","runtime/vm.h","runtime/image.c","src/isa/prims.sml","tests/basis/host/rune-prim.sml",
             "lib/basis/library.build","rune.build","runtime/intinf.c"]
        val sourceFiles=List.filter (exists o fromRoot) sourceFiles
        val sourceHashes=Json.Object (List.map (fn file => (file,Json.String (hash (fromRoot file)))) sourceFiles)
        val tools=[#compiler c,#vm c,fromRoot "bin/rune.rbc"]
        val toolHashes=Json.Object (List.map (fn file => (file,Json.String (hash file))) tools)
        val revision=Hosts.trim (meta "revision" ["git","rev-parse","HEAD"])
        val status=meta "status" ["git","status","--porcelain"]
        val patch=meta "patch" ["git","diff","--binary","HEAD"]
        val ()=write (path c "worktree.patch",patch)
        val ()=List.app (fn file => Incremental.copy (fromRoot file) (path c ("sources/" ^ file))) sourceFiles
        val versions=Json.Object (List.map (fn tool => (tool,Json.String (Hosts.trim (meta "version" [tool,"--version"])))) [#compiler c,#vm c])
        val cc=case lines (meta "cc" [env ("CC","cc"),"--version"]) of line :: _ => line | [] => "unknown"
        val machine=Json.Object (List.map (fn (key,value) => ((if key="sysname" then "system" else if key="nodename" then "node" else key),Json.String value)) (Posix.ProcEnv.uname ()))
        val libcResult=IntInfChecks.run c "metadata-libc" ["getconf","GNU_LIBC_VERSION"]
        val libc=Json.Array (List.map Json.String (if #status libcResult=0 then String.tokens Char.isSpace (Hosts.trim (#output libcResult)) else ["unknown",""]))
        val affinityText=case List.find (String.isPrefix "Cpus_allowed_list:") (lines (read "/proc/self/status")) of
               SOME line => getOpt (after ":" line,"") | NONE => ""
        fun range text=case String.fields (fn ch => ch = #"-") (Hosts.trim text) of
               [one] => (case Int.fromString one of SOME n => [n] | NONE => [])
             | [low,high] => (case (Int.fromString low,Int.fromString high) of (SOME low,SOME high) =>
                  if low>=0 andalso high>=low andalso high-low<1048576 then List.tabulate (high-low+1,fn i => low+i) else [] | _ => [])
             | _ => []
        val affinity=Json.Array (List.map (Json.Number o Int.toString) (List.concat (List.map range (String.fields (fn ch => ch = #",") affinityText))))
        val cpu=case List.find (String.isPrefix "model name") (lines (read "/proc/cpuinfo")) of
             SOME line => (case after ":" line of SOME value => Hosts.trim value | NONE => "unknown") | NONE => "unknown"
        val load=List.take (String.tokens Char.isSpace (read "/proc/loadavg"),3) handle Subscript => []
        val load=Json.Array (List.map (fn text => case Real.fromString text of SOME n => Measured.number n | NONE => Json.Null) load)
        val entries=ref [] : (string * Json.value) list ref
        val compilerEntries=ref [] : (string * Json.value) list ref
        fun report ()=Json.Object [("schema",Json.Number "2"),("seed",field "seed" manifest),("target",Json.String (#target c)),
          ("vm_options",Json.String (String.concatWith " " (#vmOptions c))),("revision",Json.String revision),("machine",machine),
          ("clock",Json.String "Time.now microseconds for kernel; Runtime.clock monotonic process wall time"),
          ("warmups",Json.Number "1"),("samples",Json.Number (Int.toString samples)),("source_hashes",sourceHashes),("tool_hashes",toolHashes),
          ("versions",versions),("cpu",Json.String cpu),("loadavg",load),("source_status",Json.String status),("c_compiler",Json.String cc),
          ("affinity",affinity),("libc",libc),("controller",Json.String "Standard ML / Rune"),("paired_oracle",Json.Bool pairedOracle),("paired_sml",Json.Bool pairedSML),
          ("workloads",Json.Object (List.rev (!entries))),("compiler_workloads",Json.Object (List.rev (!compilerEntries)))]
        fun save ()=write (path c "report.json",Json.encode (report ()) ^ "\n")
        fun workload row=
          let val name=string (field "name" row)
              val text=read (fixtureRoot ^ "/" ^ name ^ ".sml")
              val expected=read (fixtureRoot ^ "/" ^ name ^ ".expected")
              val ()=need (hash (fixtureRoot ^ "/" ^ name ^ ".sml")=string (field "source_sha256" row)
                          andalso hash (fixtureRoot ^ "/" ^ name ^ ".expected")=string (field "expected_sha256" row),"IntInf frozen workload drift: " ^ name)
              val ()=write (path c (name ^ ".expected"),expected)
              val (program,compileUsage)=compile name text []
              val oracle=if pairedOracle then SOME (#1 (compile (name ^ "-oracle")
                      (Incremental.replace text "structure I = IntInf\n" "structure I = IntInfOracle\n") [fromRoot "tests/intinf/oracle.sml"])) else NONE
              val current=ref [] : (real * Json.value) list ref
              val reference=ref [] : (real * Json.value) list ref
              fun sample program backend destination i=
                let val flags=if backend="sml" then ["--intinf=sml"] else []
                    val result=measured (name ^ "-" ^ backend ^ "-" ^ Int.toString i) (#vm c :: #vmOptions c @ flags @ [program])
                    val (first,answer)=case Substring.position "\n" (Substring.full (#output result)) of (first,rest) =>
                       if Substring.isEmpty rest then raise Failed "IntInf sample has no answer line" else (Substring.string first,Substring.string (Substring.triml 1 rest))
                    val ()=need (String.isPrefix "TIMING " first andalso answer=expected,"IntInf measurement answer differs: " ^ name)
                    val seconds=case Real.fromString (String.extract (first,7,NONE)) of SOME n => n | NONE => raise Failed "invalid kernel duration"
                    val ()=need (seconds>=0.0 andalso Real.isFinite seconds,"invalid kernel measurement")
                    val usage=case Measured.usage result of Json.Object fields => Json.Object (fields @ [("kernel_seconds",Measured.number seconds)]) | _ => raise Failed "invalid usage object"
                in if i=0 then () else destination := !destination @ [(seconds,usage)] end
              fun round i=
                let val runs=[fn () => sample program "current" current i]
                    val runs=runs @ (if pairedSML then [fn () => sample program "sml" reference i] else [])
                    val runs=runs @ (case oracle of SOME oracle => [fn () => sample oracle "oracle" reference i] | NONE => [])
                in List.app (fn run => run ()) (if i mod 2=0 then List.rev runs else runs) end
              val ()=List.app round (List.tabulate (samples+1,fn i => i))
              val instrumented=measured (name ^ "-instrumented") (#vm c :: #vmOptions c @ ["--count","--stats"]
                    @ (if pairedSML then ["--intinf-stats"] else []) @ [program])
              val ()=need ((case after "\n" (#output instrumented) of SOME answer => answer=expected | NONE => false),"instrumented IntInf answer differs")
              val median=Measured.median (List.map #1 (!current))
              val base=object row @ [("compile",compileUsage),("runs",Json.Array (List.map #2 (!current))),
                 ("expected",Json.String expected),("instrumented",Json.String (#errors instrumented)),("median_seconds",Measured.number median)]
              fun paired prefix=
                let val ratios=ListPair.mapEq (fn ((reference,_),(current,_)) =>
                           (need (current>0.0,"zero-duration current sample");reference/current)) (!reference,!current)
                in [(prefix ^ "_runs",Json.Array (List.map #2 (!reference))),
                    (if prefix="sml" then "paired_sml_speedup" else "paired_speedup",Measured.number (Measured.median ratios))]
                   @ (if prefix="oracle" then [("oracle_median_seconds",Measured.number (Measured.median (List.map #1 (!reference))))] else []) end
              val extra=if pairedSML then
                   let val result=measured (name ^ "-sml-instrumented") (#vm c :: #vmOptions c @ ["--intinf=sml","--count","--stats","--intinf-stats",program])
                       val ()=need ((case after "\n" (#output result) of SOME answer => answer=expected | NONE => false),"SML instrumented answer differs")
                   in paired "sml" @ [("sml_instrumented",Json.String (#errors result))] end
                   else if pairedOracle then paired "oracle" else []
              val ()=entries := (name,Json.Object (base @ extra)) :: !entries
          in save ();say (name ^ " " ^ Real.fmt (StringCvt.GEN NONE) median ^ "\n") end
        val ()=List.app workload definitions
        val ()=if not compilerWorkloads then () else
          let val listed=meta "compiler-sources" ["sh","scripts/build-files.sh","rune.build"]
              val inputs=String.tokens Char.isSpace listed
              fun one (name,inputs)=
                let val target=path c (name ^ ".rbc")
                    val runs=List.tabulate (samples+1,fn i =>
                         (rmTree target;measured (name ^ "-" ^ Int.toString i)
                          ([#compiler c,"--lib","lib","--target=" ^ #target c,"-o",target] @ inputs)))
                    val runs=tl runs
                    val entry=Json.Object [("inputs",Json.Array (List.map Json.String inputs)),("runs",Json.Array (List.map Measured.usage runs)),
                         ("median_seconds",Measured.number (Measured.median (List.map (Time.toReal o #wall) runs))),("output_sha256",Json.String (hash target))]
                in compilerEntries := (name,entry) :: !compilerEntries end
          in List.app one [("compile-hello",["examples/hello.sml"]),("compile-sigs",["tests/perf/compile-sigs.sml"]),
               ("bootstrap",["build/config.sml"] @ inputs @ ["src/main/rune-main.sml"])] end
    in save ();say "PASS IntInf measurement answers and separate samples\n" end
end

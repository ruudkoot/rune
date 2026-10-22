(* Retained-artifact comparisons: a recorded hash is required before a
   baseline enters any timing pair; each revision keeps its own oracle. *)
structure MeasureIntInfCompare =
struct
  open MeasureIntInfCommon
  fun kernels args =
    let val opts=options args val ()=checkedOptions ["--baseline-vm","--baseline-run","--current-run","--vm","--vm-options","--baseline-options","--group","--workload","--samples","--out"] opts
        val samples=samples opts "25" val output=fromRoot (required opts "--out") val ()=mkdirs output val run=runner output
        val base=fromRoot (option opts "--baseline-run" "tests/out/intinf/m2-final4") val current=fromRoot (required opts "--current-run")
        val b=readJson (base ^ "/report.json") val c=readJson (current ^ "/report.json")
        val vm=executable (option opts "--vm" "bin/runevm") val old=executable (option opts "--baseline-vm" "tests/out/intinf/m2-tree/bin/runevm")
        val ()=verifiedVM old b val oldOptions=option opts "--baseline-options" "" val newOptions=option opts "--vm-options" "--intinf=gmp"
        val report=MeasureIntInfCommon.base samples 2
        val ()=List.app (fn (k,v) => set report k (str v)) [("baseline_record_sha256",hash (base ^ "/report.json")),("current_record_sha256",hash (current ^ "/report.json")),("baseline_options",oldOptions),("vm_options",newOptions),("vm_sha256",hash vm),("baseline_vm_sha256",hash old)]
        val group=option opts "--group" "small"
        fun one (name,w)=if not (selected opts name) orelse (group<>"all" andalso text (field "group" w)<>group) then () else
          let val currentW=field name (field "workloads" c) val ()=need (field "source_sha256" w=field "source_sha256" currentW,"baseline/current sources differ: " ^ name)
              val a=ref [] val b=ref []
              fun sample side measured=
                let val (dir,command,dest)=if side="baseline" then (base,old::CommandWords.split oldOptions,a) else (current,vm::CommandWords.split newOptions,b)
                    val n=kernel (text (field "expected" w)) (#output (run root (command @ [dir ^ "/" ^ name ^ ".rbc"])))
                in if measured then dest:= !dest @ [n] else () end
              val ()=pairs samples 2 ["baseline","current"] sample val ratios=ratios (!b) (!a) val m=median ratios
          in add report "workloads" name (obj [("runs",obj [("baseline",values (!a)),("current",values (!b))]),("ratios",values ratios),("median_ratio",real m)]);save output report;say (name ^ " " ^ general m ^ "\n") end
    in List.app one (object (field "workloads" b));0 end
  fun paths args =
    let val opts=options args val ()=checkedOptions ["--baseline-run","--baseline-vm","--samples","--workload","--mode","--out"] opts
        val samples=samples opts "25" val output=fromRoot (required opts "--out") val ()=fresh output val run=runner output
        val base=fromRoot (required opts "--baseline-run") val old=executable (required opts "--baseline-vm") val reference=readJson (base ^ "/report.json")
        val ()=verifiedVM old reference val report=MeasureIntInfCommon.base samples 2 val ()=current report
        val ()=List.app (fn (k,v) => set report k (str v)) [("description","Compare changed arithmetic paths against retained bytecodes of the same sources."),("driver_sha256",driver ()),("baseline_record_sha256",hash (base ^ "/report.json")),("baseline_vm_sha256",hash old),("intinf_sha256",hash (fromRoot "lib/basis/intinf.sml"))]
        val modes=if null (many opts "--mode") then ["gmp","sml"] else many opts "--mode"
        val ()=List.app (fn mode => need (mode="gmp" orelse mode="sml","invalid backend mode")) modes
        val rows=object (field "workloads" reference)
        val ()=List.app (fn name => need (List.exists (fn (n,_) => n=name) rows,"unknown workload " ^ name)) (many opts "--workload")
        fun one (name,w)=if not (selected opts name) then () else
          let val source=base ^ "/" ^ name ^ ".sml" val program=output ^ "/" ^ name ^ ".rbc"
              val ()=need (hash source=text (field "source_sha256" w),"retained source differs: " ^ name)
              val _=run root [fromRoot "bin/rune","--lib","lib","-o",program,source]
              val modesReport=ref [] : (string*Json.value) list ref
              fun mode mode =
                let val a=ref [] val b=ref [] val stats=ref [] : (string*Json.value) list ref
                    fun command "baseline"=[old,"--intinf=" ^ mode,base ^ "/" ^ name ^ ".rbc"] | command _=[fromRoot "bin/runevm","--intinf=" ^ mode,program]
                    fun sample side measured=let val n=kernel (text (field "expected" w)) (#output (run root (command side)))
                         in if measured then (if side="baseline" then a else b):= !(if side="baseline" then a else b) @ [n] else () end
                    val ()=pairs samples 2 ["baseline","current"] sample
                    val ()=List.app (fn side => let val cmd=command side val result=run root (hd cmd::["--count","--stats","--intinf-stats"] @ tl cmd)
                                  val _=kernel (text (field "expected" w)) (#output result)
                              in stats:= !stats @ [(side,str (#errors result))] end) ["baseline","current"]
                    val ratios=ratios (!b) (!a) val m=median ratios
                in modesReport:= !modesReport @ [(mode,obj [("runs",obj [("baseline",values (!a)),("current",values (!b))]),("ratios",values ratios),("median_ratio",real m),("stats",obj (!stats))])];
                   add report "workloads" name (obj [("source_sha256",str (hash source)),("bytecode_sha256",obj [("baseline",str (hash (base ^ "/" ^ name ^ ".rbc"))),("current",str (hash program))]),("modes",obj (!modesReport))]);save output report;say (name ^ " " ^ mode ^ " " ^ general m ^ "\n") end
          in List.app mode modes end
    in List.app one rows;0 end
  fun compilers args =
    let val opts=options args val ()=checkedOptions ["--baseline-root","--baseline-record","--vm-options","--baseline-options","--samples","--current-record","--reference-compiler","--out","--workload"] opts
        val samples=samples opts "15" val output=fromRoot (option opts "--out" "tests/out/intinf/paired-compilers") val ()=mkdirs output val run=runner output
        val base=fromRoot (option opts "--baseline-root" "tests/out/intinf/baseline-tree") val recordPath=fromRoot (option opts "--baseline-record" "tests/intinf/baseline.json") val record=readJson recordPath
        val currentPath=option opts "--current-record" "" val currentRecord=if currentPath="" then NONE else SOME (readJson (fromRoot currentPath))
        val oldOptions=option opts "--baseline-options" "" val newOptions=option opts "--vm-options" "" val refCompiler=option opts "--reference-compiler" "bin/rune-mlton"
        fun recorded name=case List.find (fn (f,_) => String.isSuffix ("/" ^ name) f) (object (field "tool_hashes" record)) of SOME (_,v) => text v | _ => raise Failed ("missing baseline tool hash: " ^ name)
        val ()=List.app (fn name => need (hash (base ^ "/bin/" ^ name)=recorded name,"baseline " ^ name ^ " differs from recorded artifact")) ["runevm","rune.rbc"]
        val report=MeasureIntInfCommon.base samples 2
        val machine=obj (List.map (fn (key,value) => ((case key of "sysname" => "system" | "nodename" => "node" | "release" => "release" | "version" => "version" | "machine" => "machine" | _ => key),str value)) (Posix.ProcEnv.uname ()) @ [("processor",str "")])
        val ()=List.app (fn (key,value) => set report key value) [("baseline_options",str oldOptions),("vm_options",str newOptions),("machine",machine),("baseline_record_sha256",str (hash recordPath)),
             ("current_record_sha256",if currentPath="" then Json.Null else str (hash (fromRoot currentPath))),("reference_compiler",str refCompiler),("baseline_revision",field "revision" record),
             ("current_revision",str (trim (#output (run root ["git","rev-parse","HEAD"])))),("compiler_hashes",obj (List.map (fn (side,dir) => (side,obj (List.map (fn name => (name,str (hash (dir ^ "/bin/" ^ name)))) ["runevm","rune.rbc"]))) [("baseline",base),("current",root)]))]
        fun one (name,w)=if not (selected opts name) then () else
          let val inputs=array (field "inputs" w) val currentW=case currentRecord of NONE => w | SOME c => field name (field "compiler_workloads" c)
              val expectedNew=case currentRecord of SOME _ => text (field "output_sha256" currentW) | NONE =>
                 let val target=output ^ "/" ^ name ^ "-reference.rbc" val _=run root ([executable refCompiler,"--lib","lib","--target=registers","-o",target] @ List.map text inputs) in hash target end
              val a=ref [] val b=ref [] val ac=ref [] val bc=ref []
              fun sample side measured=
                let val dir=if side="baseline" then base else root val target=output ^ "/" ^ name ^ "-" ^ side ^ ".rbc" val ()=rmTree target
                    val result=run dir ([dir ^ "/bin/runevm"] @ CommandWords.split (if side="baseline" then oldOptions else newOptions) @ ["--heap-size","67108864",dir ^ "/bin/rune.rbc","--lib","lib","--target=registers","-o",target] @ List.map text (if side="baseline" then inputs else array (field "inputs" currentW)))
                    val ()=need (hash target=(if side="baseline" then text (field "output_sha256" w) else expectedNew),name ^ " " ^ side ^ ": output hash differs from its reference")
                    val wall=Time.toReal (#wall result) val cpu=Time.toReal (Time.+ (#user result,#system result))
                in if measured then let val wallDest=if side="baseline" then a else b val cpuDest=if side="baseline" then ac else bc in wallDest:= !wallDest @ [wall];cpuDest:= !cpuDest @ [cpu] end else () end
              val ()=pairs samples 2 ["baseline","current"] sample val ratios=ratios (!b) (!a) val m=median ratios
              val value=obj [("runs",obj [("baseline",values (!a)),("current",values (!b))]),("cpu_runs",obj [("baseline",values (!ac)),("current",values (!bc))]),("ratios",values ratios),("median_cpu_ratio",real (median (MeasureIntInfCommon.ratios (!bc) (!ac)))),("median_ratio",real m),
                    ("output_hashes",obj [("baseline",field "output_sha256" w),("current",str expectedNew)]),("baseline_median",real (median (!a))),("current_median",real (median (!b))),("inputs",obj [("baseline",arr inputs),("current",field "inputs" currentW)])]
          in add report "workloads" name value;save output report;say (name ^ " " ^ general m ^ "\n") end
    in List.app one (object (field "compiler_workloads" record));0 end
end

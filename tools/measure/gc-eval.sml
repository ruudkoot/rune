(* Collector evaluation orchestration. The set, weights and file schemas
   remain versioned data; SML owns planning, preparation, pairing and scoring. *)
structure MeasureGCEval =
struct
  open MeasureCommon
  type job={fields:string list,group:string,name:string,kind:string,args:string,expected:string,rounds:int option,memory:int,timeout:int}
  fun row line : job =
    case tabs line of values as group::wt::wm::wp::name::kind::args::expected::rounds::memory::timeout::_ =>
      {fields=values,group=group,name=name,kind=kind,args=args,expected=expected,rounds=if rounds="-" then NONE else SOME (integer rounds),memory=integer memory,timeout=integer timeout}
    | _ => raise Failed "malformed GC evaluation plan"
  fun replace source key value =
    let fun loop text=let val (first,rest)=Substring.position key (Substring.full text)
                      in if Substring.isEmpty rest then text else Substring.string first ^ value ^ loop (Substring.string (Substring.triml (size key) rest)) end
    in loop source end
  fun available ()=case List.find (String.isPrefix "MemAvailable:") (lines (read "/proc/meminfo")) of
       SOME line => (case String.tokens Char.isSpace line of _::kb::_ => integer kb | _ => 0) | NONE => 0
  fun benchmark name =case List.find (fn (entry:BenchCatalog.entry) => #name entry=name andalso #profile entry="normal")
                    (BenchCatalog.load (fromRoot "examples/benchmarks/manifest.tsv")) of SOME entry => entry | NONE => raise Failed ("unknown benchmark " ^ name)
  fun prepare output jobs plan =
    let val benches=sort (List.foldl (fn (job:job,names) => if #kind job<>"bench" then names else
               let val name=hd (String.tokens Char.isSpace (#args job)) in if List.exists (fn old => name=old) names then names else name::names end) [] plan)
        val pending=List.mapPartial (fn name =>
          let val entry=benchmark name val dir=output ^ "/bench/" ^ name
              val sources=List.map (fn file => "examples/benchmarks/" ^ file) (#sources entry)
              val ()=mkdirs dir
              val ()=List.app (fn file => copy (fromRoot ("examples/benchmarks/" ^ name ^ "/" ^ file)) (dir ^ "/" ^ file)) (#inputFiles entry)
              val target=dir ^ "/prog.rbc"
              val fresh=exists target andalso List.all (fn source => not (Time.> (OS.FileSys.modTime (fromRoot source),OS.FileSys.modTime target))) ("bin/rune.rbc"::sources)
              val args=[fromRoot "bin/rune","-O2","--lint"] @ sources @ ["-o",target ^ ".new"]
              val command : Supervisor.command =
                {program="/bin/sh",args=["sh","-c","ulimit -v \"$1\" || exit 125; shift; exec \"$@\"","measure-quota","6291456"] @ args,
                 env=Posix.ProcEnv.environ (),dir=root,stdin="/dev/null",stdout=dir ^ "/compile.stdout",stderr=dir ^ "/compile.stderr",
                 timeout=Time.fromSeconds 900,cap=8*1024*1024,cost=1.0,cpus=1,memory=6144,pools=[],exclusive=false,failedLast=false,deps=[]}
          in if fresh then NONE else SOME (name,dir,command) end) benches
        val failed=ref false
        val commands=Vector.fromList (List.map #3 pending)
        fun finished (index,result:Supervisor.result)=
          let val (name,dir,_)=List.nth (pending,index)
              val log=read (dir ^ "/compile.stdout") ^ read (dir ^ "/compile.stderr")
              val ()=write (dir ^ "/compile.log",log)
          in case #outcome result of Supervisor.Exited 0 => if not (#leaked result) then
                (OS.FileSys.rename {old=dir ^ "/prog.rbc.new",new=dir ^ "/prog.rbc"};Supervisor.Passed)
                 else (failed:=true;Supervisor.NotPassed)
           | _ => (failed:=true;say ("gc-eval: " ^ name ^ " does not compile: " ^ String.concatWith " " (let val ls=lines log in List.take (ls,Int.min (3,length ls)) end) ^ "\n");Supervisor.NotPassed) end
        val ()=if null benches then () else say ("gc-eval: compiling " ^ Int.toString (length benches) ^ " programs of examples/benchmarks into " ^ output ^ "/bench\n")
        val ()=Supervisor.run {commands=commands,cpus=jobs,memory=Int.max (6144,available () div 1024*4 div 5),finished=finished,tick=fn _ => ()}
        val ()=List.app (fn job:job => if #kind job<>"bench" then () else
            let val args=String.tokens Char.isSpace (#args job) val program=hd args
                val entry=benchmark program
                val normal=List.drop (args,1)=["@normal"]
                val arguments=if normal then #args entry else List.drop (args,1)
                val expected=if normal then trim (read (fromRoot ("examples/benchmarks/" ^ #expected entry))) else #expected job
                val ()=mkdirs (output ^ "/inputs")
            in write (output ^ "/inputs/" ^ #name job,program ^ "\n" ^ String.concatWith " " arguments ^ "\n" ^ expected ^ "\n") end) plan
        val mltons=List.filter (fn job:job => #kind job="mlton") plan
        val stale=List.filter (fn job:job => let val file=fromRoot ("tests/out/mlton-bench/" ^ #args job ^ ".rbc")
                     in not (exists file) orelse Time.> (OS.FileSys.modTime (fromRoot "bin/rune.rbc"),OS.FileSys.modTime file) end) mltons
        val ()=if null stale then () else
          let val result=execute root (output ^ "/mlton-prepare") ([fromRoot "bin/rune-external","benchmark","--prepare","--all","-j",Int.toString jobs] @ List.map #args stale)
          in if #status result=0 then () else (failed:=true;say (#output result ^ #errors result)) end
    in not (!failed) end
  fun pair output candidate baseline candidateOptions baselineOptions perf round (job:job) =
    let val directory=output ^ "/runs/" ^ #name job
        val ()=mkdirs directory
        val target=directory ^ "/output"
        val args= #args job
        val kind= #kind job
        val benchArgs=String.tokens Char.isSpace args
        val cwd=if kind="bench" then output ^ "/bench/" ^ hd benchArgs else if kind="mlton" then fromRoot "tests/out/mlton-bench"
                else if kind="mlton-compile" then env ("MLTON_SOURCES","") else root
        val args=if kind="bench" then "prog.rbc" else if kind="mlton" then args ^ ".rbc " ^ read (cwd ^ "/" ^ args ^ ".args") else args
        val boot=if String.isSubstring "@boot" args then String.concatWith " " (MeasureCensus.boot directory) else ""
        val mlton=if kind="mlton-compile" then String.concatWith " " (lines (read (cwd ^ "/mlton-rune.txt"))) else ""
        val args=replace (replace (replace (replace args "@root" root) "@out" target) "@boot" boot) "@mlton" mlton
        val args=MeasureCensus.globWords (CommandWords.split args)
        val input=if kind="bench" then output ^ "/inputs/" ^ #name job else "/dev/null"
        fun one who vm options =
          let val base=directory ^ "/" ^ who ^ "-" ^ Int.toString round
              val ()=List.app rmTree (List.filter (fn file => String.isPrefix (OS.Path.file base ^ ".") (OS.Path.file file)) (List.map (fn file => directory ^ "/" ^ file) (entries directory)))
              val ()=rmTree target
              val margin=integer (env ("GC_EVAL_MARGIN","8388608"))
              fun memory waited=if margin<=0 orelse not (exists "/proc/meminfo") orelse available ()>= #memory job+margin orelse waited>=3600 then () else
                    (if waited=0 then say ("gc-eval: " ^ #name job ^ " waits for " ^ Int.toString (#memory job+margin) ^ " kB of free memory\n") else ();
                     OS.Process.sleep (Time.fromSeconds 30);memory (waited+30))
              val ()=memory 0
              val load=case String.tokens Char.isSpace (read "/proc/loadavg") of first::_ => first | [] => ""
              val ()=write (base ^ ".load",load ^ "\n")
              val ()=write (base ^ ".cmd","cd " ^ cwd ^ " && ulimit -v " ^ Int.toString (#memory job) ^ " && timeout " ^ Int.toString (#timeout job) ^ " " ^ vm ^ " --gc-log " ^ base ^ ".gclog " ^ options ^ " " ^ String.concatWith " " args ^ " < " ^ input ^ "\n")
              val command=["/usr/bin/time","-f","%U %S %e %M","-o",base ^ ".time","timeout",Int.toString (#timeout job),vm,"--gc-log",base ^ ".gclog"] @ CommandWords.split options @ args
              val command=if perf then ["perf","stat","-x,","-e","task-clock,instructions:u,page-faults","-o",base ^ ".perf","--"] @ command else command
              val command=["/bin/sh","-c","ulimit -v \"$1\" || exit 125; shift; exec \"$@\"","measure-quota",Int.toString (#memory job)] @ command
              val result=child {args=command,directory=cwd,input=input,prefix=base,timeout= #timeout job+15,environment=fn e => e}
              val ()=write (base ^ ".exit",Int.toString (#status result) ^ "\n")
              val ()=if exists target then OS.FileSys.rename {old=target,new=base ^ ".output"} else ()
              val usage=case List.rev (lines (read (base ^ ".time"))) of last::_ =>
                       (case String.tokens Char.isSpace last of u::s::_::rss::_ => fixed 2 (decimal u+decimal s) ^ " s user+sys, " ^ fixed 0 (decimal rss/1024.0) ^ " MiB" | _ => "") | [] => ""
          in say ("  " ^ who ^ " exit " ^ Int.toString (#status result) ^ ", " ^ usage ^ "\n") end
        val ()=say ("gc-eval: round " ^ Int.toString round ^ ", " ^ #name job ^ "\n")
    in if round mod 2=1 then (one "candidate" candidate candidateOptions;one "baseline" baseline baselineOptions)
       else (one "baseline" baseline baselineOptions;one "candidate" candidate candidateOptions) end
  fun configured output index name =
    let val settings=readJson (output ^ "/driver.json")
        val plan=List.map row (lines (read (output ^ "/plan.tsv")))
        val resume=field "resume" settings=Json.Bool true
        val plan=case name of NONE => plan | SOME name => List.filter (fn job:job => #name job=name) plan
        val ()=need (not (null plan),"locked GC evaluation selected no workload")
    in List.app (fn job:job =>
          if (case #rounds job of SOME maximum => index>maximum | NONE => false) orelse
             (resume andalso exists (output ^ "/runs/" ^ #name job ^ "/candidate-" ^ Int.toString index ^ ".exit") andalso
                             exists (output ^ "/runs/" ^ #name job ^ "/baseline-" ^ Int.toString index ^ ".exit")) then ()
          else pair output (text (field "candidate" settings)) (text (field "baseline" settings))
                    (text (field "candidate_options" settings)) (text (field "baseline_options" settings))
                    (field "perf" settings=Json.Bool true) index job) plan;0 end
  fun main ["--round",index]=configured (env ("GC_EVAL_OUT","")) (integer index) NONE
    | main ["--pair",name,index]=configured (env ("GC_EVAL_OUT","")) (integer index) (SOME name)
    | main args =
    let val rounds=ref 3 val only=ref [] val extras=ref false val mltonCompile=ref false val candidateOptions=ref "" val baselineOptions=ref ""
        val output=ref "tests/out/gc-eval" val mode=ref "all" val jobs=ref 4 val resume=ref false
        fun parse ("--rounds"::v::rest)=(rounds:=integer v;parse rest) | parse ("--only"::v::rest)=(only:=fields #"," v;parse rest)
          | parse ("--extras"::rest)=(extras:=true;parse rest) | parse ("--mlton-compile"::rest)=(mltonCompile:=true;parse rest)
          | parse ("--candidate-opts"::v::rest)=(candidateOptions:=v;parse rest) | parse ("--baseline-opts"::v::rest)=(baselineOptions:=v;parse rest)
          | parse ("--out"::v::rest)=(output:=v;parse rest) | parse ("--resume"::rest)=(resume:=true;parse rest)
          | parse ("--prepare"::rest)=(mode:="prepare";parse rest) | parse ("--score"::rest)=(mode:="score";parse rest)
          | parse ("-j"::v::rest)=(jobs:=integer v;parse rest)
          | parse (arg::rest)=if String.isPrefix "-" arg then raise Usage ("unknown gc-eval option " ^ arg) else arg::rest | parse []=[]
        val rest=parse args
        val output=fromRoot (!output)
        val ()=mkdirs output
    in if !mode="score" then MeasureGCScore.main [output] else
       let val (candidate,baseline)=case rest of [candidate,baseline] => (executable candidate,executable baseline) | _ => raise Usage "gc-eval [OPTIONS] CANDIDATE BASELINE"
           val ()=need (!rounds>0 andalso !jobs>0,"rounds and jobs must be positive")
           val ()=List.app (fn file => need (OS.FileSys.access (file,[OS.FileSys.A_EXEC]),"VM is not executable: " ^ file)) [candidate,baseline]
           val ()=List.app (fn file => need (exists (fromRoot file),"missing " ^ file ^ ": run make first")) ["bin/rune","bin/rune.rbc","bin/runedoc.rbc"]
           val ()=if !mltonCompile then need (exists (env ("MLTON_SOURCES","") ^ "/mlton-rune.txt"),"--mlton-compile needs MLTON_SOURCES with mlton-rune.txt") else ()
           val all=List.map row (List.filter (fn line => trim line<>"" andalso not (String.isPrefix "#" line)) (lines (read (fromRoot "scripts/gc-eval.tsv"))))
           fun selected (job:job)=
             (!extras orelse List.exists (fn value => integer value<>0) (List.take (List.drop (#fields job,1),3))) andalso
             (#kind job<>"mlton-compile" orelse !mltonCompile) andalso
             (null (!only) orelse List.exists (fn filter => filter= #name job orelse filter= #group job) (!only))
           val plan=List.filter selected all
           val plan=List.filter (fn job:job => if #kind job<>"mlton" orelse isDir (env ("MLTON_BENCH","/home/ruud/reference/mlton/benchmark/tests")) then true
                       else (say ("gc-eval: no MLTON_BENCH: " ^ #name job ^ " is not run\n");false)) plan
           val ()=need (not (null plan),"gc-eval: no run selected")
           val planText=String.concat (List.map (fn (job:job) => String.concatWith "\t" (#fields job) ^ "\n") plan)
           val identity=Json.Object [("schema",Json.Number "2"),("candidate_sha256",Json.String (hash candidate)),("baseline_sha256",Json.String (hash baseline)),
                    ("compiler_sha256",Json.String (hash (fromRoot "bin/rune.rbc"))),("candidate_options",Json.String (!candidateOptions)),
                    ("baseline_options",Json.String (!baselineOptions)),("plan_sha256",Json.String (Hex.fromBytes (Sha256.digest planText)))]
           val spec=output ^ "/run-spec.json"
           val ()=if !resume andalso exists (output ^ "/runs") then
                     need (exists spec andalso readJson spec=identity,"resume identities/options differ or were not recorded; use a fresh output directory") else ()
           val ()=json spec identity
           val ()=write (output ^ "/plan.tsv",planText)
           val ()=copy (fromRoot "scripts/gc-eval.tsv") (output ^ "/set.tsv")
           val prepared=prepare output (!jobs) plan
       in if !mode="prepare" then (if prepared then 0 else 1) else
          let val perf= #status (execute root (output ^ "/perf-probe") ["perf","stat","-x,","-e","task-clock","-o","/dev/null","--","true"])=0
              val ()=if !resume then () else rmTree (output ^ "/runs")
              val date=successful (execute root (output ^ "/date") ["date","-u","+%FT%TZ"])
              val revision=trim (successful (execute root (output ^ "/revision") ["git","rev-parse","--short","HEAD"]))
              val changed=length (lines (successful (execute root (output ^ "/dirty") ["git","status","--porcelain"])))
              val machine=trim (successful (execute root (output ^ "/machine") ["uname","-srm"]))
              val ()=write (output ^ "/meta","candidate " ^ candidate ^ " " ^ !candidateOptions ^ "\nbaseline " ^ baseline ^ " " ^ !baselineOptions ^ "\nrounds " ^ Int.toString (!rounds)
                     ^ "\nperf " ^ (if perf then "1" else "0") ^ "\ndate " ^ trim date ^ "\nrevision " ^ revision ^ " " ^ Int.toString changed ^ " changed\nmachine " ^ machine ^ "\n")
              val ()=say ("gc-eval: " ^ Int.toString (length plan) ^ " runs, " ^ Int.toString (!rounds) ^ " rounds, " ^ candidate ^ " against " ^ baseline ^ "; in " ^ output ^ "\n")
              val ()=json (output ^ "/driver.json") (Json.Object [("candidate",Json.String candidate),("baseline",Json.String baseline),
                    ("candidate_options",Json.String (!candidateOptions)),("baseline_options",Json.String (!baselineOptions)),("perf",Json.Bool perf),("resume",Json.Bool (!resume))])
              val lock=CommandWords.split (env ("GC_EVAL_LOCK",""))
              val payload=CommandLine.name ()
              fun round i=if i> !rounds then () else
                (if null lock then ignore (configured output i NONE) else
                   let val limit=Int.max (7200,List.foldl (fn (job:job,total) => total+2*(#timeout job+3600)) 0 plan)
                       val result=child {args=lock @ [fromRoot "bin/runevm",payload,"gc-eval","--round",Int.toString i],directory=root,input="",prefix=output ^ "/round-" ^ Int.toString i,
                             timeout=limit,environment=setEnv ("GC_EVAL_OUT",output) o setEnv ("RUNE_TEST_RUN",output) o setEnv ("RUNE_TEST_CPUS","1")}
                   in say (#output result ^ #errors result);need (#status result=0,"locked GC evaluation round failed") end;
                 if null lock orelse i= !rounds then () else OS.Process.sleep (Time.fromSeconds (LargeInt.fromInt (integer (env ("GC_EVAL_GAP","60")))));
                 round (i+1))
              val ()=round 1
              val report=ref [] : string list ref
              val code=MeasureGCScore.report output (fn text => (say text;report:=text :: !report))
              val ()=write (output ^ "/report.md",String.concat (List.rev (!report)))
          in if prepared then code else 1 end end end
end

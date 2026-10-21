(* Declarative simulator matrices and supervised parallel runs. Rows are
   published in plan order; worker output cannot interleave TSV records. *)
structure MeasureSimSweeps =
struct
  open MeasureCommon
  fun product xs ys f=List.concat (List.map (fn x => List.map (fn y => f x y) ys) xs)
  fun words text=String.tokens Char.isSpace text
  val nurseries=["256K","512K","1M","2M","4M","8M","16M","32M"]
  val layouts=[("L0","-"),("L1","-"),("L1","REALIMM"),("L2","-"),("L3","-"),("L3","NAN51"),("L4","-"),("L4","L4UNIFORM"),("L1","PAIRS"),("L4","PAIRS")]
               @ product ["L1","L2","L3","L4"] ["HDR4","ALIGN16","COMPACT"] (fn l => fn v => (l,v))
  fun sweepOne reduced extra =
    let fun row (layout,variant) args=[layout,variant] @ args
        val short=[("L0","-"),("L1","-"),("L1","PAIRS"),("L1","REALIMM"),("L2","-"),("L4","-"),("L4","L4UNIFORM")]
        fun copier heap band=["--collector","copier","--heap-size",heap,"--band",band]
    in if reduced then List.concat (List.map (fn lv => List.map (row lv)
          ([copier "64M" "lo",copier "4M" "lo"] @ List.map (fn n => ["--collector","nursery","--nursery",n,"--promote","1","--heap-size","4M","--band","lo"]) ["1M","4M"])) short)
       else List.concat (List.map (fn lv => List.concat (List.map (fn band =>
           List.map (row lv) (List.map (fn h => copier h band) ["4M","16M","64M","256M","1G"] @
              List.concat (List.map (fn n => List.map (fn p => ["--collector","nursery","--nursery",n,"--promote",p,"--heap-size","4M","--band",band]) ["1","2"]
                  @ [["--collector","sticky","--nursery",n,"--heap-size","4M","--band",band],["--collector","mutseg","--nursery",n,"--promote","1","--heap-size","4M","--band",band]]) nurseries)
              @ List.map (fn t => ["--collector","los","--los",t,"--heap-size","64M","--band",band]) ["2K","8K","32K"])) ["lo","hi"])) layouts)
          @ List.concat (List.map (fn lv => product ["lo","hi"] ["call","result"] (fn b => fn r => row lv (copier "64M" b @ ["--real-level",r])))
                [("L1","-"),("L1","REALIMM"),("L2","-"),("L3","-"),("L4","-"),("L4","L4UNIFORM")]) end
  fun sweepTwo reduced question =
    case question of
      "nursery" => List.concat (List.map (fn b => List.concat (List.map (fn n => List.map (fn p => words ("--old copy --nursery " ^ n ^ " --promote " ^ p ^ " --band " ^ b)) ["1","2"]) ["128K","256K","512K","1M","2M","4M","8M","16M","32M"])) ["lo","hi","near"])
    | "old" => List.concat (List.map (fn limit => List.map (fn old => words ("--nursery 1M --old " ^ old) @ (if limit="0" then [] else ["--limit-x",limit])) ["copy","mc","mc --jonkers","mlton","immix","segfit","bestfit","nextfit","firstfit","chez"]) (if reduced then ["0","2"] else ["0","1.25","1.5","2","3","4"]))
    | "old-n" => List.concat (List.map (fn n => List.concat (List.map (fn limit => List.map (fn old => words ("--nursery " ^ n ^ " --old " ^ old) @ (if limit="0" then [] else ["--limit-x",limit])) ["copy","immix","segfit","bestfit","chez"]) ["0","2"])) ["256K","4M"])
    | "frag" => List.concat (List.map (fn line => List.concat (List.map (fn block => List.concat (List.map (fn defrag =>
         let val args=words ("--nursery 1M --old immix --line " ^ line ^ " --block " ^ block) @ defrag
         in [args,args @ ["--limit-x","1.5"]] end) [[],["--no-defrag"]])) ["16K","32K","64K"])) ["64","128","256"])
       @ [words "--nursery 1M --old immix --exact-lines"]
       @ List.map (fn t => words ("--nursery 1M --old immix --los " ^ t)) ["2K","4K","8K"]
       @ List.map (fn t => words ("--nursery 1M --old segfit --los " ^ t)) ["512","1025"]
       @ List.concat (List.map (fn t => [words ("--nursery 1M --old bestfit --los " ^ t),words ("--nursery 1M --old copy --los " ^ t)]) ["2K","8K","32K"])
    | "mut" => List.concat (List.map (fn n => let val args=words ("--nursery " ^ n ^ " --old immix") in [args,args @ ["--mutable-space"]] end) ["256K","1M","4M"])
    | "satb" => List.concat (List.map (fn old => let val args=words ("--nursery 1M --old " ^ old)
         in args :: product ["0.5","1","2","4","8"] ["0.5","0.75"] (fn k => fn threshold => args @ ["--satb",k,"--satb-start",threshold]) end) ["immix --no-defrag","segfit","bestfit"])
    | "order" => List.concat (List.map (fn old => let val args=words ("--nursery 1M --old " ^ old)
         in [args,args @ ["--order","bfs"],args @ ["--order","dfs"]] @ List.map (fn s => args @ ["--shuffle",s]) ["1","2","3"] end) ["immix","segfit","bestfit","chez"])
    | "bits32" => List.concat (List.map (fn old => let val args=words ("--nursery 1M --old " ^ old)
         in [args,args @ words "--ptr 4",args @ words "--size W4 --ptr 4",args @ words "--size W4 --ptr 4 --limit-x 2"] end) ["copy","immix","segfit","bestfit"])
    | "events" => List.map words ["--nursery 0 --old copy --heap-size 64M","--nursery 0 --old copy --heap-size 4M","--nursery 1M --old copy","--nursery 256K --old copy","--nursery 4M --old copy", "--nursery 1M --old immix","--nursery 1M --old segfit","--nursery 1M --old bestfit","--nursery 1M --old mc","--nursery 1M --old segfit --satb 2","--nursery 1M --old immix --no-defrag --satb 2","--nursery 1M --old segfit --satb 2 --slice 64K"]
    | _ => raise Usage ("unknown simulator question: " ^ question)
  fun run sim quota jobs output commands =
    let val temporary=output ^ ".jobs" val ()=mkdirs temporary
        val failed=ref false
        val commands=Vector.fromList (List.map (fn (args,index) =>
              {program="/bin/sh",args=["sh","-c","ulimit -v \"$1\" || exit 125; shift; exec \"$@\"","sim-quota",Int.toString quota,sim] @ args,
               env=Posix.ProcEnv.environ (),dir=OS.FileSys.getDir (),stdin="/dev/null",stdout=temporary ^ "/" ^ Int.toString index ^ ".row",stderr=temporary ^ "/" ^ Int.toString index ^ ".err",
               timeout=Time.fromSeconds 7200,cap=8*1024*1024,cost=1.0,cpus=1,memory=quota div 1024,pools=[],exclusive=false,failedLast=false,deps=[]}:Supervisor.command)
                (ListPair.zip (commands,List.tabulate (length commands,fn i => i))))
        fun finished (_,r:Supervisor.result)=case #outcome r of Supervisor.Exited 0 => if #leaked r then (failed:=true;Supervisor.NotPassed) else Supervisor.Passed
                           | _ => (failed:=true;Supervisor.NotPassed)
        val ()=Supervisor.run {commands=commands,cpus=jobs,memory=Int.max (quota div 1024,MeasureGCEval.available () div 1024*4 div 5),finished=finished,tick=fn _ => ()}
        val ()=Vector.appi (fn (i,_) => (append (output,read (temporary ^ "/" ^ Int.toString i ^ ".row"));append (output ^ ".err",read (temporary ^ "/" ^ Int.toString i ^ ".err")))) commands
    in not (!failed) end
  fun header sim output=write (output,successful (execute (OS.FileSys.getDir ()) (output ^ ".header") [sim,"--header"]))
  fun main first args =
    let val jobs=ref (if first then 8 else 2) val reduced=ref false val only=ref "" val output=ref (if first then fromRoot "tests/out/heapsim" else "tests/out/gcsim")
        fun parse ("-P"::v::rest)=(jobs:=integer v;parse rest) | parse ("--reduced"::rest)=(reduced:=true;parse rest)
          | parse ("--plan"::v::rest)=if v="full" orelse v="reduced" then (reduced:=v="reduced";parse rest) else raise Usage "simulator plan must be full or reduced"
          | parse ("--only"::v::rest)=(only:=v;parse rest) | parse ("--out"::v::rest)=(output:=v;parse rest)
          | parse (arg::rest)=if String.isPrefix "-" arg then raise Usage ("unknown sweep option " ^ arg) else arg::rest | parse []=[]
        val traces=parse args val ()=need (!jobs>0,"parallel jobs must be positive")
        val output=OS.Path.mkAbsolute {path= !output,relativeTo=OS.FileSys.getDir ()} val ()=mkdirs output
        val sim=fromRoot (if first then "bin/heapsim" else "bin/gcsim") val failed=ref false
        val questions=if !only<>"" then words (!only) else if !reduced then ["nursery","old","events"] else ["nursery","old","old-n","frag","mut","satb","order","bits32","events"]
        fun one trace =
          let val name=OS.Path.file trace val directory=if first then fromRoot ("tests/out/census/" ^ trace) else trace
          in if not (exists (directory ^ (if first then "/DONE" else "/meta.txt"))) then (failed:=true;say ("SKIP " ^ name ^ ": no valid census trace\n")) else
             List.app (fn question =>
               let val output=if first then output ^ "/sweep-" ^ trace ^ ".tsv" else output ^ "/sweep/" ^ question ^ "/" ^ name ^ ".tsv"
                   val ()=mkdirs (OS.Path.dir output)
                   val events=if first then "" else OS.Path.dir (OS.Path.dir (OS.Path.dir output)) ^ "/events"
                   val ()=if first then () else mkdirs events
                   val size=if exists (directory ^ "/stores.bin") then OS.FileSys.fileSize (directory ^ "/stores.bin") else 0
                   val noStores=if first then size>1073741824 else List.exists (fn name => name=question) ["old","old-n","frag","order","bits32"] orelse (size>4294967296 andalso question<>"nursery")
                   val extra=if noStores then ["--no-stores"] else []
                   val configurations=if first then sweepOne (!reduced) extra else sweepTwo (!reduced) question
                   val commands=List.map (fn config =>
                      if first then case config of layout::variant::args => ["--trace",directory,"--workload",trace,"--layout",layout] @ (if variant="-" then [] else ["--variant",variant]) @ args @ (if !reduced then extra else [])
                          | _ => raise Failed "invalid layout sweep row"
                      else ["--max-mb","5000","--trace",directory,"--workload",name] @ config @
                           (if question="events" then ["--events",events ^ "/" ^ name ^ "." ^ String.translate (fn #"-" => "" | #" " => "_" | c => str c) (String.concatWith " " config) ^ ".ev"] else []) @ extra) configurations
                   val started=Time.toSeconds (Runtime.clock ())
                   val ()=header sim output val ok=run sim (if first then 4194304 else 6291456) (!jobs) output commands
                   val rows=length (lines (read output))-1 val wanted=length configurations
                   val ()=if ok andalso rows=wanted then () else failed:=true
               in say ("sweep " ^ name ^ (if first then "" else " " ^ question) ^ ": " ^ Int.toString rows ^ "/" ^ Int.toString wanted ^ " rows in " ^ LargeInt.toString (Time.toSeconds (Runtime.clock ())-started) ^ " s"
                       ^ (if read (output ^ ".err")="" then "" else " (" ^ (if first then "errors" else "stderr") ^ " in " ^ output ^ ".err)") ^ "\n") end) (if first then [""] else questions) end
    in List.app one traces;if !failed then 1 else 0 end
end

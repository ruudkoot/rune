(* The production census recipe, with identical stock/instrumented streams,
   arguments and output state. DONE is published only after validation. *)
structure MeasureCensus =
struct
  open MeasureCommon
  type recipe={rbc:string,args:string list,cwd:string,output:string}
  fun globWords words=List.concat (List.map (fn word =>
       if String.isSubstring "*" word orelse String.isSubstring "?" word then
         let val dir=case OS.Path.dir word of "" => "." | dir => dir
             val names=List.filter (fn name => Expectations.glob (OS.Path.file word,name)) (sort (entries dir))
         in if null names then [word] else List.map (fn name => if dir="." then name else dir ^ "/" ^ name) names end
       else [word]) words)
  fun budget name key=case List.find (String.isPrefix (key ^ " ")) (lines (read (fromRoot ("tests/perf/" ^ name ^ ".budget")))) of
        NONE => [] | SOME line => globWords (CommandWords.split (String.extract (line,size key+1,NONE)))
  fun boot directory =
    "build/config.sml" :: String.tokens Char.isSpace (successful (execute root (directory ^ "/boot-sources") ["sh","scripts/build-files.sh","rune.build"])) @ ["src/main/rune-main.sml"]
  fun main args =
    let val output=ref "tests/out/census" val every=ref "32768" val summary=ref false val graph=ref false val named=ref ""
        val heap=ref "1073741824" val timeout=ref 3600 val input=ref "/dev/null" val cwd=ref ""
        fun parse ("--out"::v::rest)=(output:=v;parse rest) | parse ("--every"::v::rest)=(every:=v;parse rest)
          | parse ("--summary"::rest)=(summary:=true;parse rest) | parse ("--graph"::rest)=(graph:=true;parse rest)
          | parse ("--name"::v::rest)=(named:=v;parse rest) | parse ("--heap"::v::rest)=(heap:=v;parse rest)
          | parse ("--timeout"::v::rest)=(timeout:=integer v;parse rest) | parse ("--stdin"::v::rest)=(input:=v;parse rest)
          | parse ("--cwd"::v::rest)=(cwd:=fromRoot v;parse rest)
          | parse (arg::rest)=if String.isPrefix "-" arg then raise Usage ("unknown census option " ^ arg) else arg::rest
          | parse []=[]
        val workloads=parse args
        val ()=if null workloads then raise Usage "census [OPTIONS] WORKLOAD..." else ()
        val ()=need (!named="" orelse length workloads=1,"--name selects exactly one census workload")
        val output=if !cwd<>"" then fromRoot (!output) else !output
        val compiler=tool "RUNE_NEW" "bin/rune"
        val stock=tool "RUNEVM_NEW" (fromRoot "bin/runevm")
        val census=tool "RUNEVM_CENSUS" (fromRoot "bin/runevm-census")
        val flags=(if !summary then ["--census-summary"] else []) @ (if !graph then ["--census-graph"] else [])
        val failed=ref false
        fun one workload =
          let val name=if !named<>"" then !named else OS.Path.file (if String.isSuffix ".rbc" workload then String.substring (workload,0,size workload-4) else workload)
              val directory=output ^ "/" ^ name
              val absolute=fromRoot directory
              val ()=(mkdirs directory;rmTree (directory ^ "/DONE"))
              fun compile source target=ignore (successful (execute root (directory ^ "/compile") (compiler @ [source,"-o",target])))
              val recipe : recipe =
                if workload="bootstrap" then {rbc="bin/rune.rbc",args=["--lib","lib","-o",directory ^ "/boot.rbc"] @ boot directory,cwd=root,output=directory ^ "/boot.rbc"}
                else if workload="compile-sigs" orelse workload="compile-hello" then
                    {rbc="bin/rune.rbc",args=["--lib","lib","-o",directory ^ "/out.rbc"] @ budget workload "compile",cwd=root,output=directory ^ "/out.rbc"}
                else if workload="runedoc-ir" orelse workload="runedoc-page" then
                    {rbc="bin/runedoc.rbc",args=["--lib","lib"] @ budget workload "runedoc",cwd=root,output=""}
                else if String.isPrefix "mlton-" workload then
                    let val name=String.extract (workload,6,NONE)
                        val cwd=fromRoot "tests/out/mlton-bench"
                        val rbc=cwd ^ "/" ^ name ^ ".rbc"
                        val ()=if env ("CENSUS_NO_PREPARE","0")="1" andalso exists rbc then write (directory ^ "/prepare.out","prepared before\n") else
                             write (directory ^ "/prepare.out",successful (execute root (directory ^ "/prepare") ([fromRoot "bin/rune-external","benchmark","--prepare","--rune",hd compiler,name])))
                    in {rbc=rbc,args=words (cwd ^ "/" ^ name ^ ".args"),cwd=cwd,output=""} end
                else if String.isSuffix ".rbc" workload then {rbc=workload,args=[],cwd=if !cwd="" then root else !cwd,output=""}
                else let val source="tests/perf/" ^ workload ^ ".sml"
                         val target=directory ^ "/" ^ workload ^ ".rbc"
                         val ()=need (exists (fromRoot source),workload ^ ": not a workload")
                         val ()=compile source target
                     in {rbc=target,args=budget workload "args",cwd=root,output=""} end
              val rbc=fromRoot (#rbc recipe)
              val stdin=if !input="" orelse String.isPrefix "/" (!input) then !input else #cwd recipe ^ "/" ^ !input
              fun reset ()=if #output recipe="" then () else rmTree (#output recipe)
              fun run label args =child {args=args,directory= #cwd recipe,input=stdin,prefix=directory ^ "/" ^ label,timeout= !timeout,environment=fn e => e}
              val ()=reset ()
              val reference=run "stock" (stock @ ["--jit=off","--count","--heap-size","67108864",rbc] @ #args recipe)
              val ()=reset ()
              val started=Time.toSeconds (Runtime.clock ())
              val actual=run "census" (census @ ["--jit=off","--count","--stats","--heap-size",!heap,"--heap-fill","50","--census-dir",absolute,"--census-every",!every] @ flags @ [rbc] @ #args recipe)
              val wall=Time.toSeconds (Runtime.clock ())-started
              val ()=need (#status reference=0,workload ^ ": stock VM exit " ^ Int.toString (#status reference) ^ ": " ^ #errors reference)
              val ()=need (#status actual=0,workload ^ ": census VM exit " ^ Int.toString (#status actual) ^ ": " ^ #errors actual)
              val count=find "runevm: count:" (#errors reference)
              val ()=need (isSome count andalso count=find "runevm: count:" (#errors actual),workload ^ ": counts differ")
              val ()=need (#output reference= #output actual,workload ^ ": the outputs differ")
              val static=run "static" (census @ ["--census-static",rbc])
              val ()=need (#status static=0,"census static query failed")
              val ()=write (directory ^ "/static.tsv",#output static)
              val stats=List.filter (fn line => String.isPrefix "runevm: " line andalso String.isSubstring " collections," line) (lines (#errors actual))
              val done="count " ^ valOf count ^ "\nwall " ^ LargeInt.toString wall ^ " s\nevery " ^ !every ^ "\nlayout W8\nversion 2\ncensus-heap " ^ !heap
                    ^ "\nflags --census-every " ^ !every ^ " " ^ (if !summary then "--census-summary" else "") ^ " " ^ (if !graph then "--census-graph" else "") ^ "\n"
                    ^ (if !summary then "mode summary\n" else "") ^ "cwd " ^ #cwd recipe ^ "\ncmd " ^ quote rbc ^ " " ^ String.concatWith " " (List.map quote (#args recipe)) ^ "\n"
                    ^ (if #output recipe="" then "" else "out " ^ fromRoot (#output recipe) ^ "\n")
                    ^ (if stdin="/dev/null" then "" else "stdin " ^ stdin ^ "\n") ^ String.concat (List.map (fn line => line ^ "\n") stats)
              val ()=write (directory ^ "/DONE.pending",done)
              val ()=OS.FileSys.rename {old=directory ^ "/DONE.pending",new=directory ^ "/DONE"}
          in say ("ok   " ^ workload ^ ": " ^ LargeInt.toString wall ^ " s; " ^ valOf count ^ "\n") end
        val ()=List.app (fn workload => one workload handle Failed why => (failed:=true;say ("FAIL " ^ why ^ "\n"))) workloads
    in if !failed then 1 else 0 end
end

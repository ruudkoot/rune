(* Phase, Mid roundtrip and global-root cost experiments. Every sample's
   compiler status and output are checked before it can be selected. *)
structure MeasurePerfUnits =
struct
  open MeasureCommon
  val output=fromRoot "tests/out/perf-units"
  val stages=String.tokens Char.isSpace "startup lex select parse elaborate translate mid midcanon shake lift workers simplify lower registers emit total"
  fun stats text =
    let val times=ref [] : (string*real) list ref
        fun add key value=case List.find (fn (name,_) => name=key) (!times) of NONE => times:=(key,value):: !times
               | SOME (_,old) => times:=List.map (fn (name,n) => (name,if name=key then n+value else n)) (!times)
        fun line line=case String.tokens Char.isSpace line of
             "pass"::name::rest => if length rest>=2 then add (String.substring (name,0,size name-1)) (decimal (List.nth (rest,length rest-2))) else ()
           | "total:"::value::_ => add "total" (decimal value) | _ => ()
        val ()=List.app line (lines text)
    in fn key => case List.find (fn (name,_) => key=name) (!times) of SOME (_,n) => n | NONE => 0.0 end
  fun main args =
    let val runs=ref 5 val configs=ref "tier2,interp,baseline,stack,mlton" val corpus=ref (env ("RUNE_CORPUS","")) val mlton=ref (env ("MLTON_SOURCES","")) val selected=ref []
        fun parse []=() | parse ("--runs"::v::rest)=(runs:=integer v;parse rest) | parse ("--configs"::v::rest)=(configs:=v;parse rest)
          | parse ("--corpus"::v::rest)=(corpus:=fromRoot v;parse rest) | parse ("--mlton"::v::rest)=(mlton:=fromRoot v;parse rest)
          | parse (part::rest)=if List.exists (fn x => x=part) ["phases","mid","globals"] then (selected:= !selected @ [part];parse rest) else raise Usage "perf-units [--runs N] [--configs LIST] [--corpus DIR] [--mlton DIR] [phases|mid|globals]..."
        val ()=parse args val ()=need (!runs>0 andalso !runs<=10000,"invalid phase sample count") val ()=mkdirs output
        val configs=fields #"," (!configs) val parts=if null (!selected) then ["phases"] else !selected
        val boot=MeasureCensus.boot output
        val ()=write (output ^ "/two.sml","val xs = List.map Int.toString [1, 2, 3]\nval () = TextIO.output (TextIO.stdOut, String.concatWith \" \" xs ^ \"\\n\")\n")
        fun compiler config huge =case config of "tier2" => vm "bin/runevm" [] "bin/rune.rbc" huge
            | "interp" => vm "bin/runevm" ["--jit=off"] "bin/rune.rbc" huge
            | "baseline" => vm "bin/runevm" ["--jit=baseline"] "bin/rune.rbc" huge
            | "stack" => vm "bin/runevm-stack" [] "bin/rune.stack.rbc" huge
            | _ => if List.exists (fn x => x=config) ["mlton","polyml","mlkit","smlnj-legacy","smlnj32","smlnj-dev"] then [fromRoot ("bin/rune-" ^ config)] else raise Usage ("no compiler configuration " ^ config)
        and vm binary flags program huge=[fromRoot binary] @ flags @ ["--heap-size","67108864"] @ (if huge then ["--heap-limit","5368709120"] else []) @ [fromRoot program,"--lib",fromRoot "lib"]
        fun run label config huge args =
          let val command=compiler config huge @ args
              val command=if huge then ["/bin/sh","-c","ulimit -v 12582912 || exit 125; exec \"$@\"","phase-quota"] @ command else command
              val result=measuredChild {args=command,directory=root,input="",prefix=output ^ "/" ^ label,timeout=if huge then 3600 else 600,environment=fn e => e}
              val ()=need (#status result=0,"compiler failed: " ^ config ^ ": " ^ #errors result)
          in result end
        fun program name=case name of "hello" => ["examples/hello.sml"] | "two" => [output ^ "/two.sml"] | "basis" => ["--basis","all","examples/hello.sml"]
             | "compiler" => boot | "corpus" => List.map (fn f => !corpus ^ "/" ^ f) (words (!corpus ^ "/sources.txt")) @ [!corpus ^ "/src/main.sml"]
             | "mlton" => "--type-work=1000000000"::List.map (fn f => !mlton ^ "/mlton/" ^ f) (lines (read (!mlton ^ "/mlton/mlton-rune.txt"))) | _ => raise Failed "unknown phase workload"
        fun linesRead args =
          let val deps=successful (execute root (output ^ "/basis-deps") ([fromRoot "bin/rune-mlton","--basis-deps"] @ args))
              val deps=List.map (fn f => if OS.Path.isAbsolute f then f else fromRoot ("lib/basis/" ^ f)) (lines deps)
              val sources=List.filter (fn a => not (String.isPrefix "-" a) andalso exists a andalso not (isDir a)) args
              fun count file=let val stream=BinIO.openIn file
                   fun loop n=let val bytes=BinIO.inputN (stream,65536) in if Word8Vector.length bytes=0 then n else loop (Word8Vector.foldl (fn (b,n) => if b=0w10 then n+1 else n) n bytes) end
                   in loop 0 before BinIO.closeIn stream end
          in List.foldl (fn (file,n) => n+count file) 0 (deps @ sources) end
        fun phases ()=
          let val programs=["hello","two","basis","compiler"] @ (if !corpus<>"" andalso exists (!corpus ^ "/sources.txt") then ["corpus"] else []) @
                 (if !mlton="" orelse not (exists (!mlton ^ "/mlton/mlton-rune.txt")) then [] else if MeasureGCEval.available ()>=20*1024*1024 then ["mlton"] else (say "perf-units: less than 20 GB available; mlton left out\n";[]))
              val ()=write (output ^ "/phases.txt","")
              val ()=say "| Compiler | Program | wall | startup | lex | select | parse | elaborate | translate | mid | midcanon | shake | lift | workers | simplify | lower | registers | emit | total | lines read | lines/s, front end |\n|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
              fun one name config =
                let val args=program name val count=linesRead args val best=ref (NONE:(int*string) option)
                    val samples=if name="mlton" then 1 else !runs
                    val target=output ^ "/" ^ name ^ "." ^ config ^ ".rbc"
                    fun sample i=
                      let val ()=rmTree target val result=run (name ^ "." ^ config ^ ".sample." ^ Int.toString i) config (name="mlton") (["--pass-stats"] @ args @ ["-o",target])
                          val ()=need (exists target,"phase compiler produced no bytecode") val ms=LargeInt.toInt (Time.toMilliseconds (#wall result))
                          val file=output ^ "/" ^ name ^ "." ^ config ^ ".stats." ^ Int.toString i val ()=write (file,#errors result)
                      in case !best of NONE => best:=SOME (ms,#errors result) | SOME (old,_) => if ms<old then best:=SOME (ms,#errors result) else () end
                    val ()=List.app sample (List.tabulate (samples,fn i => i)) val (wall,text)=valOf (!best) val times=stats text
                    val ()=write (output ^ "/" ^ name ^ "." ^ config ^ ".stats",text)
                    val ()=append (output ^ "/phases.txt",config ^ " " ^ name ^ " wall " ^ Int.toString wall ^ "\n" ^ String.concat (List.map (fn line => config ^ " " ^ name ^ " " ^ line ^ "\n") (lines text)))
                    val front=times "lex"+times "parse"+times "elaborate"
                in say ("| " ^ String.concatWith " | " ([config,name,fixed 3 (Real.fromInt wall/1000.0)] @ List.map (fixed 3 o times) stages @ [Int.toString count,if front>0.0 then fixed 0 (Real.fromInt count/front) else "-"]) ^ " |\n") end
          in List.app (fn name => List.app (one name) (if name="mlton" then List.filter (fn c => c="tier2" orelse c="mlton") configs else configs)) programs end
        fun mid ()=
          let val target=output ^ "/compiler.rbc" val result=run "mid-build" "mlton" false (["--dump-after=mid"] @ boot @ ["-o",target])
              val text= #output result val text=if String.isPrefix "(* after mid *)\n" text then String.extract (text,15,NONE) else text
              val file=output ^ "/compiler.mid" val ()=write (file,text)
              val ()=say ("| Compiler | lex + select + parse + elaborate + translate + mid of the sources | --read-mid of their Mid (" ^ Int.toString (size text) ^ " bytes) |\n|---|---:|---:|\n")
              fun one config=
                let val a=stats (#errors (run ("mid-source-" ^ config) config false (["--pass-stats"] @ boot @ ["-o",output ^ "/compiler." ^ config ^ ".rbc"])))
                    val b=stats (#errors (run ("mid-read-" ^ config) config false ["--pass-stats","--read-mid",file]))
                in say ("| " ^ config ^ " | " ^ fixed 3 (List.foldl (fn (name,n) => n+a name) 0.0 ["lex","select","parse","elaborate","translate","mid"]) ^ " | " ^ fixed 3 (b "mid") ^ " |\n") end
          in List.app one configs end
        fun globals ()=
          let val ()=say "| globals | minor collections | their processor time, ms | per minor collection, us | its roots besides the stack |\n|---:|---:|---:|---:|---:|\n"
              fun one n=
                let val base=output ^ "/globals" ^ Int.toString n val ()=write (base ^ ".sml",String.concat (List.tabulate (n,fn i => "val g" ^ Int.toString i ^ " = ref " ^ Int.toString i ^ "\n")) ^
                       "fun build (0, acc) = acc | build (k, acc) = build (k - 1, k :: acc)\nfun loop (0, s) = s | loop (k, s) = loop (k - 1, s + List.length (build (1000, [])))\nval () = print (Int.toString (loop (16000, 0)) ^ \"\\n\")\n")
                    val _=run ("globals-compile-" ^ Int.toString n) "mlton" false ["-O0",base ^ ".sml","-o",base ^ ".rbc"]
                    val best=ref (NONE:(IntInf.int*Json.value list) option)
                    fun sample _=
                      let val result=execute root (base ^ ".sample") [fromRoot "bin/runevm","--gc-log",base ^ ".log",base ^ ".rbc"] val ()=need (#status result=0 andalso #output result="16000000\n","global-root sample failed")
                          val rows=List.filter (fn row => MeasureMMU.kind row="minor") (#4 (MeasureMMU.parse (base ^ ".log")))
                          val ns=List.foldl (fn (row,n) => n+MeasureMMU.get "cpu_ns" row) 0 rows
                      in case !best of NONE => (best:=SOME (ns,rows);copy (base ^ ".log") (base ^ ".best")) | SOME (old,_) => if ns<old then (best:=SOME (ns,rows);copy (base ^ ".log") (base ^ ".best")) else () end
                    val ()=List.app sample (List.tabulate (!runs,fn i => i)) val (ns,rows)=valOf (!best)
                    val roots=case List.rev rows of [] => 0 | row::_ => MeasureMMU.get "other_roots" row
                in say ("| " ^ String.concatWith " | " [Int.toString n,Int.toString (length rows),fixed 1 (MeasureMMU.float ns/1e6),fixed 1 (if null rows then 0.0 else MeasureMMU.float ns/Real.fromInt (length rows)/1000.0),intText roots] ^ " |\n") end
          in List.app one [0,1000,10000,50000,100000] end
    in List.app (fn part => (say ("\n### " ^ part ^ "\n\n");case part of "phases" => phases () | "mid" => mid () | _ => globals ())) parts;0 end
end

structure MeasureMMUCli =
struct
  open MeasureCommon
  fun value (Json.Number text)=decimal text | value _=raise Failed "expected GC report number"
  fun member key result=MeasureMMU.member key result
  fun numeric key result=value (field key result)
  fun integer key result=intText (MeasureMMU.get key result)
  fun ms n=fixed 3 (n/1e6)
  fun share Json.Null="-" | share number=fixed 3 (value number)
  fun maybe Json.Null="None" | maybe (Json.Number text)=text | maybe _="None"
  val columns=["workload","pauses","copied MB","max live MB","heap MB","GC ms","longest ms","p50 ms","p90 ms","p99 ms",
               "MMU 1","MMU 10","MMU 50","MMU 100","MMU 10 (instr)","MMU 50 (instr)"]
  val header="| " ^ String.concatWith " | " columns ^ " |\n|---|" ^ String.concat (List.tabulate (length columns-1,fn _ => "---:|")) ^ "\n"
  fun textReport result windows =
    let val kinds="{" ^ String.concatWith ", " (List.map (fn (key,n) => "'" ^ key ^ "': " ^ maybe n) (object (member "kinds" result))) ^ "}"
        val allocation=case member "bytes_allocated" result of Json.Null => "no '# end' line: the run did not exit normally"
              | bytes => "allocated " ^ maybe bytes ^ " bytes, " ^ maybe (member "objects_allocated" result) ^ " objects, " ^ integer "instructions" result ^ " instructions"
        val run=case member "run_ns" result of Json.Null => "" | number => " (" ^ fixed 1 (100.0*numeric "gc_share" result) ^ "% of a run of " ^ fixed 3 (value number/1e9) ^ " s)"
        val histogram=List.mapPartial (fn Json.Array [Json.String label,count] => if value count>0.0 then SOME ("  " ^ StringCvt.padRight #" " 16 label ^ " " ^ maybe count) else NONE
                                   | _ => raise Failed "invalid histogram") (array (member "histogram" result))
        val rows=["log: " ^ MeasureCommon.text (field "log" result),
             "passes " ^ integer "passes" result ^ ", pauses (vm_gc calls) " ^ integer "pauses" result ^ ", kinds " ^ kinds,
             allocation,"copied " ^ integer "copied" result ^ " bytes, promoted " ^ integer "promoted" result ^ "; live after a collection at most " ^ integer "max_live_after" result
                    ^ "; heap at most " ^ integer "max_heap_size" result ^ ", at the end " ^ integer "final_heap_size" result,
             "resident at a collection at most " ^ integer "max_rss_at_gc" result ^ " bytes; VmPeak " ^ maybe (member "vmpeak_kb" result) ^ " kB, VmHWM " ^ maybe (member "vmhwm_kb" result) ^ " kB",
             "collector: " ^ ms (numeric "gc_ns" result) ^ " ms in pauses" ^ run ^ "; " ^ ms (numeric "cpu_ns" result) ^ " ms of processor time",
             "pauses: longest " ^ ms (numeric "longest_ns" result) ^ " ms, mean " ^ ms (numeric "mean_ns" result) ^ ", p50 " ^ ms (numeric "p50_ns" result)
                    ^ ", p90 " ^ ms (numeric "p90_ns" result) ^ ", p99 " ^ ms (numeric "p99_ns" result) ^ ", p99.9 " ^ ms (numeric "p999_ns" result) ^ " ms",
             "histogram:"] @ histogram @ ["MMU (window: wall | instr); the wall clock is " ^ MeasureCommon.text (field "wall_clock" result)]
             @ List.map (fn (key,w) => "  " ^ StringCvt.padLeft #" " 5 (general w) ^ " ms: " ^ share (member key (member "mmu_wall" result)) ^ " | " ^ share (member key (member "mmu_instr" result))) windows
    in String.concatWith "\n" rows end
  fun row result label =
    let fun mb key=fixed 1 (numeric key result/1e6)
        val wall=member "mmu_wall" result val instr=member "mmu_instr" result
        val cells=[label,integer "pauses" result,mb "copied",mb "max_live_after",mb "max_heap_size",fixed 1 (numeric "gc_ns" result/1e6),
                   ms (numeric "longest_ns" result),ms (numeric "p50_ns" result),ms (numeric "p90_ns" result),ms (numeric "p99_ns" result)]
                  @ List.map (fn key => share (member key wall)) ["1","10","50","100"] @ List.map (fn key => share (member key instr)) ["10","50"]
    in "| " ^ String.concatWith " | " cells ^ " |" end
  fun selfTest () =
    let val fixture=readJson (fromRoot "tools/measure/fixtures/mmu-v1.json")
        val cases=array (field "cases" fixture)
        fun one data=
          let val intervals=List.map (fn Json.Array [a,b] => (value a,value b) | _ => raise Failed "bad MMU interval") (array (field "intervals" data))
              val got=MeasureMMU.mmu intervals (value (field "total" data)) (value (field "window" data))
          in need (case got of SOME n => Real.abs (n-value (field "expected" data))<0.000000001 | NONE => false,"MMU closed form or brute-force vector differs") end
        val ()=List.app one cases
        val ()=need (not (isSome (MeasureMMU.mmu [(4.0,5.0)] 10.0 11.0)),"MMU accepted a window longer than the run")
    in say "rune-measure mmu: self-test OK (9 closed forms, 300 frozen random cases against a scan)\n";0 end
  fun main ["--row-header"]=(say header;0)
    | main ["--self-test"]=selfTest ()
    | main args =
    let val wall=ref NONE val windows=ref (List.map (fn n => (general n,n)) MeasureMMU.windows)
        val mode=ref "text" val separate=ref false val label=ref NONE val files=ref []
        fun parse []=()
          | parse ("--wall"::value::rest)=(wall:=SOME (decimal value);parse rest)
          | parse ("--windows"::value::rest)=(windows:=List.map (fn s => (if String.isSubstring "." s then minus (Real.toString (decimal s)) else s,decimal s)) (fields #"," value);parse rest)
          | parse ("--label"::value::rest)=(label:=SOME value;parse rest)
          | parse ("--json"::rest)=(mode:="json";parse rest)
          | parse ("--row"::rest)=(mode:="row";parse rest)
          | parse ("--passes"::rest)=(separate:=true;parse rest)
          | parse (arg::rest)=if String.isPrefix "-" arg then raise Usage ("unknown MMU option " ^ arg) else (files:= !files @ [arg];parse rest)
        val ()=parse args
        val ()=if null (!files) then raise Usage "mmu [--wall S] [--windows LIST] [--passes] [--json|--row] LOG..." else ()
        fun one (file,index)=
          let val result=MeasureMMU.analyse file (!wall) (!windows) (!separate)
              val text=case !mode of "json" => Json.encode result | "row" => row result (getOpt (!label,OS.Path.file file))
                    | _ => (if index=0 then "" else "\n") ^ textReport result (!windows)
          in say (text ^ "\n") end
    in List.app one (ListPair.zip (!files,List.tabulate (length (!files),fn i => i)));0 end
end

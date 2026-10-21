structure MeasureLayoutTables =
struct
  open MeasureCommon
  structure T=MeasureTabular structure D=MeasureLayoutText
  fun ratio NONE="-" | ratio (SOME n)=fixed 2 n ^ (if 1.0/1.15<n andalso n<1.15 then "~" else "")
  fun table header rows ="| " ^ String.concatWith " | " header ^ " |\n|" ^ String.concat (List.tabulate (length header,fn _ => "---|")) ^ "\n"
                      ^ String.concat (List.map (fn row => "| " ^ String.concatWith " | " row ^ " |\n") rows)
  fun main args =
    let val directory=case args of [] => fromRoot "tests/out/layouts" | [path] => path | _ => raise Usage "layout-tables [DIRECTORY]"
        val rows=T.readTable (directory ^ "/harness-raw.tsv")
        val indexed=List.foldl (fn (row,rows) => let val key=(T.get "cc" row,T.get "config" row,T.get "kernel" row)
                   in (key,row)::List.filter (fn (old,_) => key<>old) rows end) [] rows
        fun find cc config kernel=Option.map #2 (List.find (fn (key,_) => key=(cc,config,kernel)) indexed)
        fun value column cc config kernel=case (find cc config kernel,find cc "L0" kernel) of (SOME row,SOME base) =>
                   if T.number column base>0.0 then SOME (T.number column row/T.number column base) else NONE | _ => NONE
        fun ratioCell column config kernel =
          case (value column "gcc-13" config kernel,value column "clang-18" config kernel) of
             (NONE,NONE) => "-" | (NONE,SOME c) => "(clang " ^ ratio (SOME c) ^ ")"
           | (SOME g,SOME c) => if Real.abs (g-c)/Real.max (g,c)>0.10 then ratio (SOME g) ^ " (" ^ ratio (SOME c) ^ ")" else ratio (SOME g)
           | (SOME g,NONE) => ratio (SOME g)
        fun intro title note="# " ^ title ^ "\n\nCommand: `" ^ D.cmd ^ "`\n\n" ^ note ^ "\n\n"
        fun ratioTable column title note =intro title note ^ D.ratio_note ^ "\n\n" ^ table ("config"::D.kernels)
                 (List.map (fn config => config::List.map (ratioCell column config) D.kernels) D.configs)
        val ()=write (directory ^ "/harness-cycles.md",ratioTable "cycles" "Cycles (cycles:u) relative to L0" D.cycles_note)
        val ()=write (directory ^ "/harness-instructions.md",ratioTable "instructions" "Instructions (instructions:u) relative to L0" D.instructions_note)
        val ()=write (directory ^ "/harness-l1d.md",ratioTable "l1d_misses" "L1d load misses (L1-dcache-load-misses) relative to L0" D.l1d_note)
        fun gcCell config kernel=case find "gcc-13" config kernel of NONE => "-" | SOME row =>
             let val base=case find "gcc-13" "L0" kernel of NONE => 0.0 | SOME base => T.number "gc_cycles" base
             in fixed 1 (100.0*T.number "gc_share" row) ^ "% (" ^ (if base>0.0 then fixed 2 (T.number "gc_cycles" row/base) else "-") ^ ")" end
        val ()=write (directory ^ "/harness-gc.md",intro "Collector share and collector cycles" D.gc_note ^ table ("config"::D.kernels) (List.map (fn config => config::List.map (gcCell config) D.kernels) D.configs))
        val rawHeader=["cc","config","kernel","n","Gcycles","Ginstr","IPC","L1d miss (M)","dTLB miss (K)","branch miss (M)","sfb (K)","cache miss (M)","ms","gc%","spread","runs"]
        fun raw cc config kernel=Option.map (fn row =>
             [cc,config,kernel,T.get "n" row,fixed 3 (T.number "cycles" row/1e9),fixed 3 (T.number "instructions" row/1e9),fixed 2 (T.number "instructions" row/T.number "cycles" row),
              fixed 1 (T.number "l1d_misses" row/1e6),fixed 0 (T.number "dtlb_misses" row/1e3),fixed 2 (T.number "branch_misses" row/1e6),fixed 0 (T.number "store_fwd_blocks" row/1e3),
              fixed 2 (T.number "cache_misses" row/1e6),fixed 0 (T.number "task_clock_ms" row),fixed 1 (100.0*T.number "gc_share" row),T.get "spread" row,T.get "runs" row]) (find cc config kernel)
        val rawRows=List.concat (List.map (fn cc => List.concat (List.map (fn config => List.mapPartial (raw cc config) D.kernels) D.configs)) D.ccs)
        val ()=write (directory ^ "/harness-counters.md",intro "Raw counters (least-of-5 run)" D.counter_note ^ table rawHeader rawRows)
        val micro=directory ^ "/harness-micro.tsv"
        val ()=if not (exists micro) then () else
          let val rows=T.readTable micro
              val ops=List.foldl (fn (row,ops) => let val opName=T.get "op" row in if List.exists (fn old => old=opName) ops then ops else ops @ [opName] end) [] rows
              val indexed=List.foldl (fn (row,all) => let val key=(T.get "cc" row,T.get "config" row,T.get "semispace_mib" row,T.get "op" row)
                         in (key,row)::List.filter (fn (old,_) => key<>old) all end) [] rows
              fun cell cc config semispace opName=case List.find (fn (key,_) => key=(cc,config,semispace,opName)) indexed of NONE => "nan" | SOME (_,row) => fixed 1 (T.number "cycles_per_op" row)
              fun row semispace config cc=if not (List.exists (fn ((c,cfg,s,_),_) => c=cc andalso cfg=config andalso s=semispace) indexed) then NONE
                           else SOME (config::cc::List.map (cell cc config semispace) ops)
              val sections=List.map (fn semispace => "## semispace " ^ semispace ^ " MiB\n\n" ^ table (["config","cc"] @ ops)
                          (List.concat (List.map (fn config => List.mapPartial (row semispace config) D.ccs) D.configs)) ^ "\n") ["8","64"]
              val title="# The primitive operations alone\n\nCommand: `" ^ D.cmd ^ "` (micro.sh: `harness micro -s 8` and `-s 64`, least of 3)\n\n" ^ D.micro_note ^ "\n\n"
          in write (directory ^ "/harness-micro.md",title ^ String.concat sections) end
    in say ("tables written to " ^ directory ^ "/\n");0 end
end

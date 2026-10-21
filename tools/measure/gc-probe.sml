(* Bounded 32-bit address-space probes and GC-log reports. *)
structure MeasureGCProbe =
struct
  open MeasureCommon
  fun report output vm =
    let val labels=List.map (fn f => String.substring (OS.Path.file f,0,size (OS.Path.file f)-5)) (glob (output,".exit"))
        fun contents label ext=read (output ^ "/" ^ label ^ "." ^ ext)
        fun timing label=case List.rev (lines (contents label "time")) of line::_ =>
               (case String.tokens Char.isSpace line of wall::rss::_ => (wall,decimal rss) | _ => ("-",0.0)) | [] => ("-",0.0)
        fun mib n=intText (IntInf.div (n,1048576))
        fun probe label =case fields #"-" label of [kind,limit,fill] =>
          if (kind<>"bytes" andalso kind<>"tuples") orelse not (String.isSuffix "g" limit andalso String.isPrefix "fill" fill) then "" else
           let val held=List.mapPartial (fn line => case String.tokens Char.isSpace line of ["live",n,"MiB"] => SOME n | _ => NONE) (lines (contents label "stdout"))
               val rows=if contents label "gclog"="" then [] else #4 (MeasureMMU.parse (output ^ "/" ^ label ^ ".gclog"))
               val most=List.foldl (fn (row,NONE) => SOME row | (row,SOME old) =>
                  if MeasureMMU.get "live_after" row>MeasureMMU.get "live_after" old orelse (MeasureMMU.get "live_after" row=MeasureMMU.get "live_after" old andalso MeasureMMU.get "seq" row>MeasureMMU.get "seq" old) then SOME row else SOME old) NONE rows
               val (wall,rss)=timing label val status=trim (contents label "exit") val why=List.rev (lines (trim (contents label "stderr")))
               val reason=if status="0" orelse null why then "" else " (" ^ String.substring (hd why,0,Int.min (40,size (hd why))) ^ ")"
           in "| " ^ String.concatWith " | " [kind,if limit="2g" then "2 GiB" else "4.5 GiB (no limit)",String.extract (fill,4,NONE),status ^ reason,getOpt (last held,"0"),
                 case most of NONE => "-" | SOME row => mib (MeasureMMU.get "live_after" row),case most of NONE => "-" | SOME row => mib (MeasureMMU.get "heap_size" row),Int.toString (length rows),fixed 0 (rss/1024.0),wall] ^ " |\n" end | _ => ""
        fun latency label =
          let val (_,rss)=timing label val result=if null (prefixed "PASS " (contents label "stdout")) then "FAIL (exit " ^ trim (contents label "exit") ^ ")" else "PASS"
              val base=[label,result,fixed 0 (rss/1024.0)]
              val extra=if contents label "gclog"="" then ["-","-","-","-","-","-"] else
                let val g=MeasureMMU.analyse (output ^ "/" ^ label ^ ".gclog") NONE [] false
                    fun ms key=fixed 1 (MeasureMMU.float (MeasureMMU.get key g)/1e6)
                in [if MeasureMMU.member "vmpeak_kb" g=Json.Null orelse MeasureMMU.get "vmpeak_kb" g=0 then "-" else fixed 0 (MeasureMMU.float (MeasureMMU.get "vmpeak_kb" g)/1024.0),mib (MeasureMMU.get "max_live_after" g),mib (MeasureMMU.get "max_heap_size" g),intText (MeasureMMU.get "pauses" g),ms "longest_ns",ms "p99_ns"] end
          in "| " ^ String.concatWith " | " (base @ extra) ^ " |\n" end
        val lat=List.filter (String.isPrefix "latency-") labels
        val result="The address space of " ^ vm ^ " (scripts/gc-probe32.sh)\n\n| Probe | ulimit -v | --heap-fill | Exit | Held MiB | Most live after a collection, MiB | Its semispace, MiB | Collections | Peak RSS MiB | Wall s |\n|---|---|---:|---:|---:|---:|---:|---:|---:|---:|\n" ^ String.concat (List.map probe labels) ^
             (if null lat then "" else "\n| Run | Result | Peak RSS MiB | VmPeak MiB | Most live MiB | Semispace MiB | Pauses | Longest ms | p99 ms |\n|---|---|---:|---:|---:|---:|---:|---:|---:|\n" ^ String.concat (List.map latency lat))
    in write (output ^ "/report.md",result);say result end
  fun main args =
    let val vm=ref "bin/runevm32" val fill=ref [] val lat=ref false val output=ref "tests/out/gc-probe32" val reportOnly=ref false
        fun parse []=() | parse ("--vm"::v::rest)=(vm:=v;parse rest) | parse ("--fill"::v::rest)=(ignore (integer v);fill:=[v];parse rest)
          | parse ("--out"::v::rest)=(output:=v;parse rest) | parse ("--latency"::rest)=(lat:=true;parse rest)
          | parse ("--report"::rest)=(reportOnly:=true;parse rest) | parse _=raise Usage "gc-probe32 [--vm VM] [--fill P] [--latency] [--out DIR] [--report]"
        val ()=parse args val output=fromRoot (!output) val vm=fromRoot (!vm) val ()=mkdirs output
        fun compile label sources =
          let val result=child {args=["/bin/sh","-c","ulimit -v 6291456 || exit 125; exec \"$@\"","probe-compile"] @ tool "RUNE" (fromRoot "bin/rune") @ sources @ ["-o",output ^ "/" ^ label ^ ".rbc"],directory=root,input="",prefix=output ^ "/" ^ label ^ ".compile",timeout=600,environment=fn e => e}
          in ignore (successful result) end
        fun run label limit input args =
          let val ()=say ("gc-probe32: " ^ label ^ "\n")
              val result=child {args=["/bin/sh","-c","ulimit -v \"$1\" || exit 125; shift; exec \"$@\"","probe-quota",limit,"/usr/bin/time","-f","%e %M","-o",output ^ "/" ^ label ^ ".time",vm,"--gc-log",output ^ "/" ^ label ^ ".gclog"] @ args,directory=output,input=input,prefix=output ^ "/" ^ label,timeout=1800,environment=fn e => e}
          in write (output ^ "/" ^ label ^ ".exit",Int.toString (#status result) ^ "\n") end
        val ()=if !reportOnly then () else
          (need (OS.FileSys.access (vm,[OS.FileSys.A_EXEC]),"no executable 32-bit VM: " ^ vm);
           List.app rmTree (glob (output,".exit"));compile "probe32" ["scripts/gc-probe32.sml"];
           List.app (fn kind => List.app (fn fill => List.app (fn limit => run (kind ^ "-" ^ Int.toString (limit div 1048576) ^ "g-fill" ^ fill) (Int.toString limit) "" ["--heap-fill",fill,"probe32.rbc","16",kind,"4096"]) [2097152,4718592]) ("50":: !fill)) ["bytes","tuples"];
           if not (!lat) then () else List.app (fn name =>
             let val ()=compile name ["-O2","--lint","examples/benchmarks/shared/input.sml","examples/benchmarks/shared/latency.sml","examples/benchmarks/" ^ name ^ "/benchmark.sml","examples/benchmarks/shared/main.sml"]
                 val expected=successful (execute root (output ^ "/" ^ name ^ ".oracle") ["python3",fromRoot "tests/benchmarks/latency-oracle.py",name,"50000","1000000","1024","1"])
                 val input=output ^ "/" ^ name ^ ".input" val ()=write (input,name ^ "\n50000 1000000 1024 1\n" ^ expected)
             in run (name ^ "-50000") "4194304" input [name ^ ".rbc"] end) ["latency-ring","latency-map"])
    in report output vm;0 end
end

(* Native layout instruments: CPU affinity, idle admission and raw sample
   selection live here. perf/taskset expose hardware and scheduling only. *)
structure MeasureLayoutMeasure =
struct
  open MeasureCommon
  val directory=fromRoot "tests/layouts"
  val output=fromRoot "tests/out/layouts"
  fun idle limit waited =
    if MeasureGCMeasure.load ()<=limit then ()
    else if waited>=3600 then raise Failed "layout measurement idle wait exceeded one hour"
    else (OS.Process.sleep (Time.fromSeconds 30);idle limit (waited+30))
  fun busy prefix =
    let val result=execute root prefix ["pgrep","-af","make (check|test|matrix|windows|portability)"]
    in #status result=0 andalso not (null (lines (#output result))) end
  fun admitted waited =
    if waited>=3600 then raise Failed "layout measurement competing-build wait exceeded one hour"
    else if busy (output ^ "/admission") then (OS.Process.sleep (Time.fromSeconds 30);admitted (waited+30)) else idle (decimal (env ("LAYOUT_LOADMAX","1.5"))) 0
  fun invoke label command =child {args=command,directory=directory,input="",prefix=output ^ "/" ^ label,timeout=135,environment=fn e => e}
  val defaults=String.tokens Char.isSpace "L0 L1 L2 L3 L4MONO L4UNI L1+PAIRS L4MONO+PAIRS L4UNI+PAIRS L1+HDR4 L1+ALIGN16 L3+NAN51 L1+REALIMM L2+REALIMM L1+UNBOXED L1+FLATREAL L4UNI+FLATREAL L1+COMPACT L4MONO+COMPACT L1+BARRIER"
  fun kernels name=String.tokens Char.isSpace (case name of "L1+REALIMM" => "real_regs real_array intmap" | "L2+REALIMM" => "real_regs real_array intmap"
      | "L1+UNBOXED" => "real_regs word_loop" | "L1+FLATREAL" => "real_array" | "L4UNI+FLATREAL" => "real_array"
      | "L1+COMPACT" => "strings" | "L4MONO+COMPACT" => "strings" | "L1+BARRIER" => "inttable real_array"
      | _ => "list_ops intmap strmap inttable closures int_loop word_loop real_regs real_array strings poly_eq_tree gc_churn8 gc_churn64")
  val events="cycles:u,instructions:u,task-clock,page-faults,cache-misses,L1-dcache-load-misses,dTLB-load-misses,branch-misses,r0203:u"
  fun counters text =List.mapPartial (fn line => case fields #"," line of value::_::event::_ =>
         (case Real.fromString value of SOME n => if Real.isFinite n andalso n>=0.0 then SOME (event,value) else NONE | NONE => NONE) | _ => NONE) (lines text)
  fun lookup name values=case List.find (fn (key,_) => key=name orelse key=name ^ ":u" orelse key=name ^ ":uD") values of SOME (_,v) => v | NONE => raise Failed ("perf counter unavailable: " ^ name)
  fun main args =
    let val ccs=ref (String.tokens Char.isSpace (env ("CCS","cc"))) val selected=ref []
        fun parse ("-c"::v::rest)=(ccs:=String.tokens Char.isSpace v;parse rest)
          | parse ("-k"::v::rest)=(selected:=String.tokens Char.isSpace v;parse rest) | parse rest=rest
        val configs=case parse args of [] => defaults | rest => rest
        val raw=output ^ "/harness-raw.tsv" val ()=mkdirs output
        val ()=if exists raw then () else write (raw,"cc\tconfig\tkernel\tn\tchecksum\tcycles\tinstructions\ttask_clock_ms\tpage_faults\tcache_misses\tl1d_misses\tdtlb_misses\tbranch_misses\tstore_fwd_blocks\trdtsc_total\tgc_cycles\tgc_share\tspread\truns\n")
        fun measure cfg cc kernel =
          let val binary=output ^ "/" ^ cc ^ "/harness-" ^ cfg
          in if not (OS.FileSys.access (binary,[OS.FileSys.A_EXEC]) handle OS.SysErr _ => false) then say ("no ../out/layouts/" ^ cc ^ "/harness-" ^ cfg ^ "\n") else
            let fun attempt retries =
              let val ()=need (retries<100,"layout measurement load kept invalidating samples") val ()=admitted 0
                  val minimum=ref (NONE:IntInf.int option) val maximum=ref (0:IntInf.int) val best=ref ([],[]) : (string list*string list) ref val count=ref 0
                  fun one ()=
                    let val perfFile=output ^ "/layout.perf"
                        val result=invoke "layout-sample" (tool "PERF" "perf" @ ["stat","-x,","-e",events,"-o",perfFile,"--","taskset","-c",env ("LAYOUT_CPU","5"),"timeout","120",binary,kernel])
                        val ()=need (#status result=0,"layout kernel failed: " ^ cc ^ " " ^ cfg ^ " " ^ kernel ^ ": " ^ #errors result)
                        val values=counters (read perfFile) val cycles=MeasureMMU.natural (lookup "cycles:u" values)
                        val ()=need (cycles>0,"invalid layout cycle count")
                        val row=List.map (fn name => if name="task-clock" then fixed 1 (decimal (lookup name values)/1000000.0) else lookup name values)
                           ["cycles:u","instructions:u","task-clock","page-faults","cache-misses","L1-dcache-load-misses","dTLB-load-misses","branch-misses","r0203:u"]
                        val answer=String.tokens Char.isSpace (#output result) val ()=need (length answer=6 andalso hd answer=kernel,"malformed layout kernel answer")
                    in count:= !count+1;maximum:=IntInf.max (!maximum,cycles);
                       if not (isSome (!minimum)) orelse cycles<valOf (!minimum) then (minimum:=SOME cycles;best:=(row,answer)) else () end
                  fun five ()=List.app (fn _ => one ()) (List.tabulate (5,fn i => i))
                  fun spread ()=MeasureMMU.float (!maximum)/MeasureMMU.float (valOf (!minimum))-1.0
                  val ()=five () val ()=if spread ()>0.05 then five () else ()
              in if MeasureGCMeasure.load ()>decimal (env ("LAYOUT_RERUNMAX","3.0")) then (say ("load " ^ general (MeasureGCMeasure.load ()) ^ " after " ^ cc ^ " " ^ cfg ^ " " ^ kernel ^ ": waiting, rerunning\n");attempt (retries+1)) else
                   let val (values,answer)= !best
                   in append (raw,String.concatWith "\t" ([cc,cfg] @ List.take (answer,3) @ values @ List.drop (answer,3) @ [fixed 3 (spread ()),Int.toString (!count)]) ^ "\n");
                      say (cc ^ " " ^ cfg ^ " " ^ kernel ^ ": cycles " ^ hd values ^ " spread " ^ fixed 3 (spread ()) ^ " runs " ^ Int.toString (!count) ^ "\n") end end
            in attempt 0 end end
        val ()=List.app (fn cfg => List.app (fn cc => List.app (measure cfg cc) (if null (!selected) then kernels cfg else !selected)) (!ccs)) configs
    in say "measure.sh done: ../out/layouts/harness-raw.tsv\n";0 end
  fun micro configs =
    let val configs=if null configs then String.tokens Char.isSpace "L0 L1 L1+REALIMM L1+PAIRS L2 L3 L3+NAN51 L4MONO L4UNI L4MONO+PAIRS L1+HDR4 L1+ALIGN16" else configs
        val ccs=String.tokens Char.isSpace (env ("CCS","cc")) val out=output ^ "/harness-micro.tsv" val ()=mkdirs output
        val ()=write (out,"cc\tconfig\tsemispace_mib\top\tcycles_per_op\n")
        fun one cfg cc space =
          let val binary=output ^ "/" ^ cc ^ "/harness-" ^ cfg
          in if not (OS.FileSys.access (binary,[OS.FileSys.A_EXEC]) handle OS.SysErr _ => false) then () else
            let val ()=idle (decimal (env ("LAYOUT_LOADMAX","1.5"))) 0 val best=ref [] : (string*real*string) list ref
                fun sample _=
                  let val result=invoke "micro-sample" ["taskset","-c",env ("LAYOUT_CPU","5"),"timeout","120",binary,"micro","-s",space]
                      val ()=need (#status result=0,"layout micro sample failed")
                      fun row line=case String.tokens Char.isSpace line of ["micro",opname,value,"cycles/op"] =>
                        let val n=decimal value val ()=need (Real.isFinite n andalso n>=0.0,"invalid micro sample")
                        in case List.find (fn (old,_,_) => old=opname) (!best) of NONE => best:=(opname,n,value):: !best
                         | SOME (_,old,_) => if n<old then best:=List.map (fn entry as (key,_,_) => if key=opname then (key,n,value) else entry) (!best) else () end | _ => ()
                  in List.app row (lines (#output result)) end
                val ()=List.app sample [1,2,3] val ()=need (not (null (!best)),"micro sample omitted all operation counters")
            in List.app (fn (key,_,value) => append (out,String.concatWith "\t" [cc,cfg,space,key,value] ^ "\n")) (sorted (fn ((a,_,_),(b,_,_)) => a<b) (!best)) end end
    in List.app (fn cfg => List.app (fn cc => List.app (one cfg cc) ["8","64"]) ccs) configs;say "micro.sh done: ../out/layouts/harness-micro.tsv\n";0 end
end

(* Collector evaluation scores and correctness checks over captured runs. *)
structure MeasureGCScore =
struct
  open MeasureCommon
  structure F=MeasureFormat
  type sample={base:string,status:string,time:(real*real*real*IntInf.int) option,task:real option,instructions:IntInf.int option,gc:Json.value option}
  type metrics={task:real option,rss:real option,longest:real option,p99:real option,fraction:real option,
                pauses:IntInf.int option,copied:real option,clock:string option}
  type group={weights:int list,ratios:real option list list ref,runs:int ref}
  type row={group:string,name:string,ratios:real option list option,baseline:metrics option,candidate:metrics option,rounds:string}
  fun float n=Real.fromLargeInt (IntInf.toLarge n)
  fun number (Json.Number n)=decimal n | number _=raise Failed "numeric score field expected"
  fun optional key value=case MeasureMMU.member key value of Json.Null => NONE | value => SOME (number value)
  fun readSample base : sample option =
    if not (exists (base ^ ".exit")) then NONE else
    let val time=case List.rev (lines (read (base ^ ".time"))) of [] => NONE | last::_ =>
                  (case String.tokens Char.isSpace last of u::s::e::rss::_ => SOME (decimal u,decimal s,decimal e,MeasureMMU.natural rss) | _ => raise Failed "malformed process time record")
        val task=ref (Option.map (fn (u,s,_,_) => u+s) time)
        val instructions=ref NONE
        fun perf line=case fields #"," line of value::unit::event::_ =>
             if value="" orelse not (Char.isDigit (String.sub (value,0))) then () else
             let val event=hd (fields #":" event)
             in if event="task-clock" then task:=SOME (decimal value/(if unit="msec" then 1e3 else 1e9))
                else if event="instructions" then instructions:=SOME (MeasureMMU.natural value) else () end
           | _ => ()
        val ()=List.app perf (lines (read (base ^ ".perf")))
        val log=base ^ ".gclog"
        val gc=if exists log andalso OS.FileSys.fileSize log>0 then SOME (MeasureMMU.analyse log (Option.map (fn (_,_,e,_) => e) time)
                    (List.map (fn w => (general w,w)) MeasureMMU.windows) false) else NONE
    in SOME {base=base,status=trim (read (base ^ ".exit")),time=time,task= !task,instructions= !instructions,gc=gc} end
  fun best samples =
    let val good=List.filter (fn (r:sample) => #status r="0" andalso isSome (#task r)) samples
    in case good of [] => NONE | first::rest => SOME (List.foldl (fn (r,best:sample) => if valOf (#task r)<valOf (#task best) then r else best) first rest) end
  fun metrics (r:sample) : metrics =
    let val base={task= #task r,rss=Option.map (fn (_,_,_,rss) => float rss/1024.0) (#time r)}
    in case #gc r of NONE => {task= #task base,rss= #rss base,longest=NONE,p99=NONE,fraction=NONE,pauses=NONE,copied=NONE,clock=NONE}
       | SOME gc => {task= #task base,rss= #rss base,longest=Option.map (fn n => n/1e6) (optional "longest_ns" gc),
                     p99=Option.map (fn n => n/1e6) (optional "p99_ns" gc),
                     fraction=Option.map (fn n => 1.0-n) (optional "10" (field "mmu_wall" gc)),
                     pauses=SOME (MeasureMMU.get "pauses" gc),copied=Option.map (fn n => n/1e6) (optional "copied" gc),clock=SOME (text (field "wall_clock" gc))} end
  fun ratio (SOME a,SOME b) floor=SOME (Real.max (a,floor)/Real.max (b,floor)) | ratio _ _=NONE
  fun ratios (c:metrics,b:metrics) =
    let val parts=List.mapPartial (fn x => x) [ratio (#longest c,#longest b) 1.0,ratio (#p99 c,#p99 b) 1.0,ratio (#fraction c,#fraction b) 0.01]
    in [ratio (#task c,#task b) 0.001,ratio (#rss c,#rss b) 0.001,
        if null parts then NONE else SOME (List.foldl (op +) 0.0 parts/Real.fromInt (length parts))] end
  fun geomean options=
    let val xs=List.filter (fn n => not (Real.== (n,0.0))) (List.mapPartial (fn x => x) options)
    in if null xs then NONE else SOME (Math.exp (List.foldl (fn (n,sum) => sum+Math.ln n) 0.0 xs/Real.fromInt (length xs))) end
  fun f3 NONE="-" | f3 (SOME n)=fixed 3 n
  fun pair digits (SOME a,SOME b)=fixed digits a ^ " -> " ^ fixed digits b | pair _ _="-"
  fun pairCount (SOME a,SOME b)=intText a ^ " -> " ^ intText b | pairCount _="-"
  fun runs directory name who =
    let val prefix=who ^ "-"
        val dir=directory ^ "/runs/" ^ name
        val files=List.filter (fn file => String.isPrefix prefix file andalso String.isSuffix ".exit" file) (entries dir)
        fun round file=MeasureMMU.natural (String.substring (file,size prefix,size file-size prefix-size ".exit"))
    in List.mapPartial (fn file => readSample (dir ^ "/" ^ String.substring (file,0,size file-5))) (sorted (fn (a,b) => round a<round b) files) end
  fun checks name kind candidate baseline problems =
    let val every=List.map (fn r => ("candidate",r)) candidate @ List.map (fn r => ("baseline",r)) baseline
        fun problem text=problems:= !problems @ [text]
        val ()=List.app (fn (who,r:sample) =>
          if #status r<>"0" then
            let val errors=trim (read (#base r ^ ".stderr"))
                val tail=if size errors>200 then String.extract (errors,size errors-200,NONE) else errors
            in problem (name ^ ": the " ^ who ^ "'s run " ^ OS.Path.file (#base r) ^ " exited " ^ #status r ^ " (" ^ tail ^ ")") end
          else if kind="bench" andalso null (prefixed "PASS " (read (#base r ^ ".stdout"))) then
            problem (name ^ ": the " ^ who ^ "'s run " ^ OS.Path.file (#base r) ^ " did not print PASS: " ^
                String.concatWith " " (let val ws=String.tokens Char.isSpace (read (#base r ^ ".stdout")) in List.take (ws,Int.min (12,length ws)) end)) else ()) every
        val good=List.filter (fn (_,r:sample) => #status r="0") every
        val reference=case List.find (fn (who,_) => who="baseline") good of SOME r => SOME r | NONE => (case good of [] => NONE | r::_ => SOME r)
    in case reference of NONE => () | SOME (_,reference:sample) =>
      let val output=read (#base reference ^ ".stdout")
          val file= #base reference ^ ".output"
          val counts=case #gc reference of SOME g => if MeasureMMU.member "bytes_allocated" g<>Json.Null then SOME (MeasureMMU.get "bytes_allocated" g,MeasureMMU.get "objects_allocated" g) else NONE | NONE => NONE
      in List.app (fn (who,r:sample) =>
           let val label=who ^ " " ^ OS.Path.file (#base r)
               val ()=if read (#base r ^ ".stdout")=output then () else problem (name ^ ": the standard output of " ^ label ^ " is not that of " ^ OS.Path.file (#base reference))
               val mine= #base r ^ ".output"
               val ()=if not (exists file) orelse (exists mine andalso binary mine=binary file) then () else
                         problem (name ^ ": the output file of " ^ label ^ " is not that of " ^ OS.Path.file (#base reference))
           in case (counts,#gc r) of (SOME (bytes,objects),SOME g) =>
                if MeasureMMU.member "bytes_allocated" g=Json.Null orelse (MeasureMMU.get "bytes_allocated" g=bytes andalso MeasureMMU.get "objects_allocated" g=objects) then () else
                  problem (name ^ ": " ^ label ^ " allocated " ^ intText (MeasureMMU.get "bytes_allocated" g) ^ " bytes and " ^ intText (MeasureMMU.get "objects_allocated" g)
                       ^ " objects, where " ^ OS.Path.file (#base reference) ^ " allocated " ^ intText bytes ^ " and " ^ intText objects)
              | _ => () end) good end end
  fun report directory emit =
    let val set=if exists (directory ^ "/set.tsv") then directory ^ "/set.tsv" else fromRoot "scripts/gc-eval.tsv"
        val meta=List.mapPartial (fn line => let val (key,rest)=Substring.position " " (Substring.full line)
               in if Substring.isEmpty rest then NONE else SOME (Substring.string key,Substring.string (Substring.triml 1 rest)) end) (lines (read (directory ^ "/meta")))
        fun metadata name fallback=getOpt (Option.map #2 (List.find (fn (key,_) => key=name) meta),fallback)
        val problems=ref [] : string list ref
        val clocks=ref [] : string list ref
        val groups=ref [] : (string*group) list ref
        val rows=ref [] : row list ref
        fun group name weights=case List.find (fn (key,_) => key=name) (!groups) of SOME (_,g) => g
             | NONE => let val g={weights=weights,ratios=ref [],runs=ref 0} in groups:= !groups @ [(name,g)];g end
        fun line source=if String.isPrefix "#" source orelse trim source="" then () else
          case tabs source of groupName::wt::wm::wp::name::kind::_::_::_ =>
            let val c=runs directory name "candidate" val b=runs directory name "baseline"
            in if null c andalso null b then () else
              let val g=group groupName [integer wt,integer wm,integer wp]
                  val ()= #runs g:= !(#runs g)+1
                  val ()=checks name kind c b problems
                  val candidate=best c val baseline=best b
                  val longest=List.mapPartial (fn (r:sample) => if #status r<>"0" then NONE else Option.map (fn g => number (field "longest_ns" g)/1e6) (#gc r)) (c @ b)
                  val range=if null longest then "-" else fixed 1 (List.foldl Real.min (hd longest) longest) ^ "-" ^ fixed 1 (List.foldl Real.max (hd longest) longest)
                  val rounds=range ^ " | " ^ Int.toString (length c) ^ "/" ^ Int.toString (length b)
                  val row=case (candidate,baseline) of (SOME candidate,SOME baseline) =>
                    let val mc=metrics candidate val mb=metrics baseline val rs=ratios (mc,mb)
                        val ()=List.app (fn clock => case clock of SOME clock => if List.exists (fn old => old=clock) (!clocks) then () else clocks:=clock:: !clocks | NONE => ()) [#clock mc,#clock mb]
                    in #ratios g:= !(#ratios g) @ [rs];{group=groupName,name=name,ratios=SOME rs,baseline=SOME mb,candidate=SOME mc,rounds=rounds} end
                    | _ => {group=groupName,name=name,ratios=NONE,baseline=NONE,candidate=NONE,rounds=rounds}
              in rows:= !rows @ [row] end end
          | _ => raise Failed "malformed GC evaluation set"
        val ()=List.app line (lines (read set))
        fun output text=emit (text ^ "\n")
        val ()=output ("# gc-eval: " ^ metadata "candidate" "the candidate" ^ " against " ^ metadata "baseline" "the baseline")
        val ()=output ""
        val ()=output (metadata "rounds" "?" ^ " rounds, " ^ metadata "date" "?" ^ "; revision " ^ metadata "revision" "?" ^ "; " ^ metadata "machine" "?" ^ "; task-clock from "
              ^ (if metadata "perf" ""="1" then "perf" else "user + system time") ^ ". The wall clock of the pauses: " ^ (if null (!clocks) then "-" else String.concatWith "; " (sort (!clocks))) ^ ".")
        val ()=output "" val ()=output MeasureScoreText.ratios val ()=output ""
        val ()=output "| Run | T | M | P | Task-clock s | Peak RSS MiB | Longest ms | p99 ms | 1-MMU(10) | Pauses | Copied MB | Longest ms, every round | Rounds |"
        val ()=output "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
        val shown=ref ""
        fun g name= #2 (valOf (List.find (fn (key,_) => key=name) (!groups)))
        fun weights ns=String.concatWith "/" (List.map Int.toString ns)
        fun weighted ns=List.exists (fn n => n<>0) ns
        val ()=List.app (fn (r:row) =>
          (if #group r= !shown then () else
              (output ("| **" ^ #group r ^ "** (" ^ (if weighted (#weights (g (#group r))) then "weights " ^ weights (#weights (g (#group r))) else "not weighted") ^ ") | | | | | | | | | | | | |");shown:= #group r);
           case (#ratios r,#baseline r,#candidate r) of (SOME rs,SOME mb,SOME mc) =>
              output ("| " ^ #name r ^ " | " ^ String.concatWith " | " (List.map f3 rs @ [pair 2 (#task mb,#task mc),pair 1 (#rss mb,#rss mc),pair 1 (#longest mb,#longest mc),
                pair 2 (#p99 mb,#p99 mc),pair 3 (#fraction mb,#fraction mc),pairCount (#pauses mb,#pauses mc),pair 0 (#copied mb,#copied mc),#rounds r]) ^ " |")
           | _ => output ("| " ^ #name r ^ " | - | - | - | (no successful run on both VMs) | | | | | | | " ^ #rounds r ^ " |"))) (!rows)
        val ()=output "" val ()=output "## The worst cases" val ()=output ""
        val scored=List.mapPartial (fn (r:row) => case #ratios r of SOME rs => if weighted (#weights (g (#group r))) then SOME (#name r,rs) else NONE | NONE => NONE) (!rows)
        val ()=List.app (fn (index,label) =>
             let val items=List.mapPartial (fn (name,rs) => Option.map (fn n => (n,name)) (List.nth (rs,index))) scored
                 val worst=List.rev (sorted (fn ((x,a),(y,b)) => x<y orelse (Real.== (x,y) andalso a<b)) items)
                 val worst=List.take (worst,Int.min (5,length worst))
             in output ("* " ^ label ^ ": " ^ (if null worst then "-" else String.concatWith ", " (List.map (fn (n,name) => name ^ " " ^ fixed 3 n) worst))) end) [(0,"T"),(1,"M"),(2,"P")]
        val over=List.concat (List.map (fn (name,rs) => List.mapPartial (fn (index,label) => case List.nth (rs,index) of SOME n => if n>1.10 then SOME (name ^ " (" ^ label ^ " " ^ fixed 3 n ^ ")") else NONE | NONE => NONE) [(0,"T"),(1,"M")]) scored)
        val ()=output ("* More than 1.10 in T or M (D1 holds every run of the set to 1.10): " ^ (if null over then "none" else String.concatWith ", " over))
        val ()=output "" val ()=output "## The scores" val ()=output ""
        val ()=output "| Group | T | M | P | Weights T/M/P | Runs scored |"
        val ()=output "|---|---:|---:|---:|---|---:|"
        val totals=Array.array (3,(0.0,0))
        val ()=List.app (fn (name,g:group) =>
          let val rs=List.tabulate (3,fn i => geomean (List.map (fn rs => List.nth (rs,i)) (!(#ratios g))))
              val ()=output ("| " ^ name ^ " | " ^ String.concatWith " | " (List.map f3 rs) ^ " | " ^ weights (#weights g) ^ " | " ^ Int.toString (length (!(#ratios g))) ^ " of " ^ Int.toString (!(#runs g)) ^ " |")
          in List.app (fn i => case List.nth (rs,i) of NONE => () | SOME ratio =>
               let val weight=List.nth (#weights g,i) val (sum,old)=Array.sub (totals,i)
               in if weight=0 orelse Real.== (ratio,0.0) then () else Array.update (totals,i,(sum+Real.fromInt weight*Math.ln ratio,old+weight)) end) [0,1,2] end) (!groups)
        val scores=List.tabulate (3,fn i => let val (sum,weight)=Array.sub (totals,i) in if weight=0 then NONE else SOME (Math.exp (sum/Real.fromInt weight)) end)
        val present=List.tabulate (3,fn i => #2 (Array.sub (totals,i)))
        val ()=output ("| **score** | **" ^ String.concatWith "** | **" (List.map f3 scores) ^ "** | present: " ^ weights present ^ " | |")
        val ()=output ""
        val ()=output (F.format MeasureScoreText.weight_note (List.map (F.Integer o IntInf.fromInt) present))
        val ()=output "" val ()=output "## Problems" val ()=output ""
        val ()=if null (!problems) then output MeasureScoreText.none else List.app (fn problem => output ("* " ^ problem)) (!problems)
    in if null (!problems) then 0 else 1 end
  fun main [directory]=report directory say
    | main _=raise Usage "gc-eval-score DIR"
end

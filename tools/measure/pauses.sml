structure MeasurePauses =
struct
  open MeasureCommon
  structure F=MeasureFormat
  type stats={count:int,gc:real,total:real,maximum:real,p99:real,mmu:real list}
  fun stats (model:MeasureTimeline.model) : stats =
    let val (intervals,total)=MeasureTimeline.intervals model
        val lengths=List.map #2 (#pauses model)
    in {count=length lengths,gc=List.foldl (op +) 0.0 lengths/1e6,total=total/1e6,maximum=List.foldl Real.max 0.0 lengths/1e6,
        p99=MeasureTimeline.percentile lengths 99.0/1e6,mmu=List.map (fn w => MeasureTimeline.mmu intervals total (w*1e6)) [1.0,10.0,50.0,100.0]} end
  fun row name (s:stats)=F.format "| %s | %d | %.1f | %.1f%% | %.2f | %.2f | %.3f | %.3f | %.3f | %.3f |"
       ([F.Text name,F.Integer (IntInf.fromInt (#count s)),F.Decimal (#gc s),F.Decimal (if Real.== (#total s,0.0) then 0.0 else 100.0* #gc s/ #total s),
         F.Decimal (#maximum s),F.Decimal (#p99 s)] @ List.map F.Decimal (#mmu s))
  fun main (events::validation::output::traces) =
    let val files=List.filter (String.isSuffix ".ev") (entries events)
        val invocation=String.concatWith " " (events::validation::output::traces)
        val traces=if null traces then
              sorted (fn (a,b) => if String.isPrefix "bootstrap" a=String.isPrefix "bootstrap" b then a<b else String.isPrefix "bootstrap" a)
                  (List.foldl (fn (file,names) => let val name=hd (fields #"." file) in if List.exists (fn old => name=old) names then names else name::names end) [] files)
             else traces
        val coefficients=MeasureTimeline.readCoefficients NONE
        val options={lazy=false,watermark=false,series=NONE,instructions=0}:MeasureTimeline.options
        val parts=ref ["# Pauses and MMU (modelled)\n",
              F.format MeasurePauseText.intro [F.Text invocation,F.Text (String.concatWith ", " MeasureTimelineData.placeholders),F.Decimal 3.5,F.Decimal 6.9]]
        fun add text=parts:= !parts @ [text]
        val ()=List.app (fn trace =>
          let val selected=sort (List.filter (fn file => String.isPrefix (trace ^ ".") file) files)
          in if null selected then () else
             (add ("\n## " ^ trace ^ "\n\n" ^ MeasurePauseText.head);
              List.app (fn (tier,rate) => List.app (fn file =>
                  let val config=String.substring (file,size trace+1,size file-size trace-4)
                      val config=MeasureGCEval.replace (MeasureGCEval.replace (MeasureGCEval.replace config "_" " ") "nursery" "n") "old " ""
                      val model=MeasureTimeline.fromEvents (events ^ "/" ^ file) options coefficients rate
                  in add (row (config ^ " (" ^ tier ^ ")") (stats model)) end) selected) [("default",3.5),("interp",6.9)];
              let val measured=List.mapPartial (fn (heap,tag) =>
                    let val log=validation ^ "/" ^ trace ^ "." ^ heap ^ ".50.gclog"
                        val event=events ^ "/" ^ trace ^ "." ^ tag ^ ".ev"
                    in if not (exists log andalso exists event) then NONE else SOME (heap,stats (MeasureTimeline.fromGCLog log 6.9),stats (MeasureTimeline.fromEvents event options coefficients 6.9)) end)
                    [("67108864","nursery_0_old_copy_heapsize_64M"),("4194304","nursery_0_old_copy_heapsize_4M")]
              in if null measured then () else
                 (add (F.format MeasurePauseText.calibration [F.Decimal 6.9,F.Text MeasurePauseText.head]);
                  List.app (fn (heap,sm:stats,se:stats) =>
                    let val size=Int.toString (integer heap div 1048576)
                    in add (row ("copier " ^ size ^ "M measured") sm);add (row ("copier " ^ size ^ "M model") se);
                       add ("\nGC time measured / modelled at " ^ size ^ "M: " ^ fixed 2 (if Real.== (#gc se,0.0) then 0.0 else #gc sm/ #gc se) ^ ".\n") end) measured) end) end) traces
    in write (output,String.concatWith "\n" (!parts) ^ "\n");0 end
    | main _=raise Usage "pauses EVENTSDIR VALIDATEDIR OUT.md [TRACE...]"
end

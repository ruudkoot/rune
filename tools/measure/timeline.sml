(* Simulator pause model, retaining the original coefficients, grouping,
   percentile convention and short-run MMU convention. *)
structure MeasureTimeline =
struct
  open MeasureCommon
  type options={lazy:bool,watermark:bool,series:string option,instructions:IntInf.int}
  type model={pauses:(real*real) list,mutator:real,footprint:(string*IntInf.int) list}
  fun realValue (Json.Number n)=decimal n | realValue _=raise Failed "numeric simulator event expected"
  fun get key event=MeasureMMU.get key event
  fun num key event=realValue (field key event)
  fun readCoefficients path =
    let val result=ref MeasureTimelineData.coefficients
        fun line line=let val line=trim (hd (fields #"#" line))
                          val (key,value)=Substring.position "=" (Substring.full line)
                      in if line="" orelse Substring.isEmpty value then () else
                         let val key=trim (Substring.string key) val value=decimal (trim (Substring.string (Substring.triml 1 value)))
                         in need (List.exists (fn (name,_) => name=key) (!result),"timeline: unknown coefficient " ^ key);
                            result:=(key,value)::List.filter (fn (name,_) => name<>key) (!result) end end
        val ()=case path of NONE => () | SOME path => List.app line (lines (read path))
    in !result end
  fun events path =
    let val lines=List.filter (fn line => not (String.isPrefix "#" line)) (lines (read path))
    in case lines of [] => [] | header::body =>
       List.map (fn line => Json.Object (ListPair.map (fn (key,value) => (key,
          if key="kind" orelse key="how" then Json.String value else
          case IntInf.fromString value of SOME n => if String.isSubstring "." value then Json.Number value else big n | NONE => Json.String value))
          (tabs header,tabs line))) body end
  fun cost event coefficients (options:options) =
    let fun c key= #2 (valOf (List.find (fn (name,_) => name=key) coefficients))
        fun e key=num key event
        val kind=text (field "kind" event)
        val minor=kind="minor" orelse kind="sticky-minor"
        val slots=e "slots"-(if #watermark options andalso minor then e "low" else 0.0)
        val stack=slots*c "slot"+(if Real.== (e "slots",0.0) then 0.0 else e "frames"*c "frame"+e "stack_ptrs"*c "stack_ptr")
        val roots=e "cards"*(c "card"+512.0*c "card_byte")+e "remset"*c "remset"+e "born_rem_fields"*c "born_rem_field"+e "mut_scan_bytes"*c "mut_scan_byte"
        val copy=e "copied_objs"*c "copy_obj"+e "copied_bytes"*c "copy_byte"
        val mark=if String.isPrefix "satb" kind then 0.0 else e "marked_objs"*c "mark_obj"+e "marked_fields"*c "mark_field"
        val sweep=(e "sweep_scan_bytes"+e "lazy_sweep_bytes")*c "sweep_byte"
        val move=e "moved_objs"*c "move_obj"+e "moved_bytes"*c "move_byte"+e "evac_objs"*c "evac_obj"+e "evac_bytes"*c "evac_byte"
        val how=case MeasureMMU.member "how" event of Json.String value => value | _ => "-"
        val scan=if how="lisp2" then 3.0*(e "heap_scan_objs"*c "scan_obj_lisp2"+e "heap_scan_bytes"*c "scan_byte_lisp2")
                 else if how="jonkers" then 2.0*(e "heap_scan_objs"*c "scan_obj_jonkers"+e "heap_scan_bytes"*c "scan_byte_jonkers")+2.0*e "marked_ptrs"*c "ptr_jonkers" else 0.0
        val fixed=if minor then c "fixed_minor" else if String.isPrefix "satb" kind then c "fixed_satb" else c "fixed_major"
        val lazySweep=(kind="satb-end" andalso how="lazy") orelse #lazy options
    in (fixed+stack+roots+copy+mark+(if lazySweep then 0.0 else sweep)+move+scan+e "satb_work"*c "satb_byte",if lazySweep then sweep else 0.0) end
  fun fromEvents path (options:options) coefficients rate : model =
    let val rows=events path
        val debt=ref 0.0 val pauses=ref [] : (IntInf.int*real*real) list ref
        val footprint=ref [("committed",0),("reserved",0),("metadata",0)] : (string*IntInf.int) list ref
        val instructions=ref (0:IntInf.int)
        fun one event =
          let val (pause,lazy)=cost event coefficients options
              val ()=debt:= !debt+lazy
              val instr=get "instr" event val clock=get "clock" event
              val ()=instructions:=IntInf.max (!instructions,instr)
              val mutator=MeasureMMU.float instr*rate
              val ()=case !pauses of (last,time,old)::rest => if last=clock then pauses:=(last,time,old+pause)::rest else pauses:=(clock,mutator+ !debt,pause):: !pauses
                      | [] => pauses:=[(clock,mutator+ !debt,pause)]
          in footprint:=List.map (fn (key,n) => (key,IntInf.max (n,get key event))) (!footprint) end
        val ()=List.app one rows
        val ()=case #series options of NONE => () | SOME path =>
              write (path,"clock\tcommitted\treserved\tmetadata\tlive_old\n" ^ String.concat (List.map (fn event => String.concatWith "\t" (List.map (fn key => intText (get key event)) ["clock","committed","reserved","metadata","live_old"]) ^ "\n") rows))
    in {pauses=List.map (fn (_,m,p) => (m,p)) (List.rev (!pauses)),mutator=MeasureMMU.float (if #instructions options=0 then !instructions else #instructions options)*rate+ !debt,footprint= !footprint} end
  fun fromGCLog path rate : model =
    let val (_,ending,_,rows)=MeasureMMU.parse path
        val pauses=MeasureMMU.pauses rows false
    in {pauses=List.map (fn (p:MeasureMMU.pause) => (MeasureMMU.float (#instructions p)*rate,MeasureMMU.float (#length p))) pauses,
        mutator=MeasureMMU.float (get "instrs" ending)*rate,
        footprint=[("committed",List.foldl (fn (row,n) => IntInf.max (n,get "rss_bytes" row)) 0 rows),("reserved",0),("metadata",0)]} end
  fun intervals (model:model) =
    let fun loop [] last clock acc=(List.rev acc,clock+ #mutator model-last)
          | loop ((mut,pause)::rest) last clock acc=let val time=clock+mut-last in loop rest mut (time+pause) ((time,time+pause)::acc) end
    in loop (#pauses model) 0.0 0.0 [] end
  fun mmu iv total window=if total<=window then if Real.== (total,0.0) then 1.0 else
            Real.max (0.0,1.0-List.foldl (fn ((a,b),sum) => sum+b-a) 0.0 iv/total)
          else getOpt (MeasureMMU.mmu iv total window,1.0)
  fun percentile values percent =
    let val values=sorted (op <) values val n=length values
    in if n=0 then 0.0 else List.nth (values,Int.min (n-1,Real.trunc (percent/100.0*Real.fromInt n))) end
  val header=["name","pauses","gc_ms","total_ms","gc_share","max_ms","p50_ms","p90_ms","p99_ms","p999_ms"]
          @ List.map (fn w => "mmu_" ^ general w ^ "ms") MeasureMMU.windows @ ["peak_committed","peak_reserved","peak_metadata"]
  fun report name (model:model) tsv =
    let val (iv,total)=intervals model val lengths=List.map #2 (#pauses model)
        val gc=List.foldl (op +) 0.0 lengths val maximum=List.foldl Real.max 0.0 lengths
        fun ratio ()=if Real.== (total,0.0) then 0.0 else gc/total
        val mmus=List.map (fn w => mmu iv total (w*1e6)) MeasureMMU.windows
        fun footprint key=MeasureProfile.weight key (#footprint model)
    in if tsv then say (String.concatWith "\t" ([name,Int.toString (length lengths),fixed 3 (gc/1e6),fixed 3 (total/1e6),fixed 4 (ratio ()),fixed 3 (maximum/1e6)]
              @ List.map (fn p => fixed 3 (percentile lengths p/1e6)) [50.0,90.0,99.0,99.9] @ List.map (fixed 4) mmus
              @ List.map (intText o footprint) ["committed","reserved","metadata"]) ^ "\n")
       else
        let val hist=ref [] : (int*int) list ref
            fun bin duration b=if duration>=100000.0*Math.pow (2.0,Real.fromInt b) then bin duration (b+1) else b
            val ()=List.app (fn duration => let val key=bin duration 0 val old=getOpt (Option.map #2 (List.find (fn (k,_) => k=key) (!hist)),0)
                                          in hist:=(key,old+1)::List.filter (fn (k,_) => k<>key) (!hist) end) lengths
        in say (name ^ ": " ^ Int.toString (length lengths) ^ " pauses, GC " ^ fixed 1 (gc/1e6) ^ " ms of " ^ fixed 1 (total/1e6) ^ " ms (" ^ fixed 1 (100.0*ratio ()) ^ "%), longest " ^ fixed 3 (maximum/1e6) ^ " ms\n");
           say ("  percentiles (ms): " ^ String.concatWith "  " (List.map (fn (p,label) => label ^ " " ^ fixed 3 (percentile lengths p/1e6)) [(50.0,"p50"),(90.0,"p90"),(99.0,"p99"),(99.9,"p99.9")]) ^ "\n");
           say ("  MMU: " ^ String.concatWith "  " (ListPair.map (fn (w,m) => general w ^ "ms " ^ fixed 3 m) (MeasureMMU.windows,mmus)) ^ "\n");
           say ("  histogram (ms): " ^ String.concatWith "  " (List.map (fn (b,n) => "<" ^ general (0.1*Math.pow (2.0,Real.fromInt b)) ^ ": " ^ Int.toString n) (sorted (fn ((a,_),(b,_)) => a<b) (!hist))) ^ "\n");
           say ("  footprint peak: committed " ^ intText (footprint "committed") ^ ", reserved " ^ intText (footprint "reserved") ^ ", metadata " ^ intText (footprint "metadata") ^ " bytes\n") end end
  fun main args =
    let val coefficients=ref NONE val tier=ref "default" val rate=ref NONE val instructions=ref (0:IntInf.int)
        val lazy=ref false val watermark=ref false val series=ref NONE val tsv=ref false val head=ref false val gclog=ref false val paths=ref []
        fun parse []=() | parse ("--coef"::v::rest)=(coefficients:=SOME v;parse rest) | parse ("--tier"::v::rest)=(tier:=v;parse rest)
          | parse ("--ns-per-instr"::v::rest)=(rate:=SOME (decimal v);parse rest) | parse ("--instructions"::v::rest)=(instructions:=MeasureMMU.natural v;parse rest)
          | parse ("--lazy-sweep"::rest)=(lazy:=true;parse rest) | parse ("--watermark"::rest)=(watermark:=true;parse rest)
          | parse ("--series"::v::rest)=(series:=SOME v;parse rest) | parse ("--tsv"::rest)=(tsv:=true;parse rest)
          | parse ("--header"::rest)=(head:=true;parse rest) | parse ("--gclog"::rest)=(gclog:=true;parse rest)
          | parse (arg::rest)=if String.isPrefix "-" arg then raise Usage ("unknown timeline option " ^ arg) else (paths:= !paths @ [arg];parse rest)
        val ()=parse args val ()=need (not (null (!paths)),"timeline needs an event or GC log")
        val rates=MeasureTimelineData.rates
        val rate=case !rate of SOME n => n | NONE => (case List.find (fn (name,_) => name= !tier) rates of SOME (_,n) => n | NONE => raise Usage "unknown timeline tier")
        val coefficients=readCoefficients (!coefficients)
        val options={lazy= !lazy,watermark= !watermark,series= !series,instructions= !instructions}:options
        val ()=if !tsv andalso !head then say (String.concatWith "\t" header ^ "\n") else ()
    in List.app (fn path => report path (if !gclog then fromGCLog path rate else fromEvents path options coefficients rate) (!tsv)) (!paths);0 end
end

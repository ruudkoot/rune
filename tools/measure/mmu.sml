(* GC log analysis. Counts and recorded nanoseconds remain exact integers;
   real arithmetic is used only for clocks, utilisation and displayed ratios. *)
structure MeasureMMU =
struct
  open MeasureCommon
  val windows=[1.0,2.0,5.0,10.0,20.0,50.0,100.0,200.0]
  val histogram=[0.1,0.2,0.5,1.0,2.0,5.0,10.0,20.0,50.0,100.0,200.0,500.0,1000.0,2000.0,5000.0]
  fun member key value=getOpt (Json.member (key,value),Json.Null)
  fun natural text=case IntInf.scan StringCvt.DEC Substring.getc (Substring.full text) of
       SOME (n,rest) => if Substring.isEmpty rest then n else raise Failed ("invalid GC integer: " ^ text)
     | NONE => raise Failed ("invalid GC integer: " ^ text)
  fun exact (Json.Number value)=natural value | exact _=raise Failed "expected integer GC field"
  fun get key value=case member key value of Json.Null => 0 | number => exact number
  fun float n=Real.fromLargeInt (IntInf.toLarge n)
  fun kind value=text (field "kind" value)
  fun parse file =
    let val header=ref [] : (string*Json.value) list ref
        val ending=ref [] : (string*Json.value) list ref
        val wall=ref NONE : IntInf.int option ref
        val columns=ref NONE : string list option ref
        val passes=ref [] : Json.value list ref
        fun atom value=if value<>"" andalso CharVector.all Char.isDigit value then big (natural value) else Json.String value
        fun set target key value=target:=(key,value) :: List.filter (fn (name,_) => name<>key) (!target)
        fun pairs []=[] | pairs (key::value::rest)=(key,atom value)::pairs rest | pairs _=[]
        fun line raw =
          case String.tokens Char.isSpace raw of [] => () | first::rest =>
           if String.isPrefix "#" first then
             let val words=(if first="#" then [] else String.tokens Char.isSpace (String.extract (first,1,NONE))) @ rest
             in case words of
                  "rune-gc-log"::version::options => (set header "version" (Json.String version);
                      List.app (fn option => let val (key,value)=Substring.position "=" (Substring.full option)
                           in set header (Substring.string key) (atom (if Substring.isEmpty value then "" else Substring.string (Substring.triml 1 value))) end) options)
                | "seq"::_ => columns:=SOME words
                | "end"::values => ending:=pairs values
                | "wall_ns"::value::_ => wall:=SOME (natural value)
                | _ => () end
           else case !columns of NONE => raise Failed (file ^ ": a collection before column names") | SOME cols =>
             let fun zip ([],_) = [] | zip (_,[]) = []
                   | zip (key::keys,value::values)=(key,if key="kind" then Json.String value else big (natural value))::zip (keys,values)
             in passes:=Json.Object (zip (cols,first::rest)) :: !passes end
        val stream=TextIO.openIn file
        fun loop ()=case TextIO.inputLine stream of NONE => () | SOME row => (line row;loop ())
        val ()=(loop () handle e => (TextIO.closeIn stream;raise e))
    in TextIO.closeIn stream;(Json.Object (List.rev (!header)),Json.Object (!ending),!wall,List.rev (!passes)) end
  type pause={start:IntInf.int option,finish:IntInf.int option,kinds:string,passes:int,length:IntInf.int,instructions:IntInf.int}
  fun pauses rows separate =
    let fun group [] acc=List.rev acc
          | group (row::rest) []=group rest [[row]]
          | group (row::rest) (current::done)=
               if not separate andalso get "vmgc" row=get "vmgc" (hd current) then group rest ((row::current)::done)
               else group rest ([row]::current::done)
        fun pause reversed : pause =
          let val rows=List.rev reversed val first=hd rows val last=List.last rows
              val kinds=sort (List.foldl (fn (row,ks) => if List.exists (fn k => k=kind row) ks then ks else kind row::ks) [] rows)
              val start=case member "t_ns" first of Json.Null => NONE | value => SOME (exact value)
          in {start=start,finish=Option.map (fn _ => get "t_ns" last+get "pause_ns" last) start,kinds=String.concatWith "+" kinds,passes=length rows,
              length=List.foldl (fn (row,total) => total+get "pause_ns" row) 0 rows,instructions=get "instrs" first} end
    in List.map pause (group rows []) end
  fun instructionTimeline (pauses:pause list) instructions mutator =
    let val rate=if mutator>0.0 then float instructions/mutator else 1.0
        fun loop [] accumulated acc=(List.rev acc,float instructions/rate+accumulated)
          | loop ((p:pause)::rest) accumulated acc=let val start=float (#instructions p)/rate+accumulated
                                                 val duration=float (#length p)
                                            in loop rest (accumulated+duration) ((start,start+duration)::acc) end
    in loop pauses 0.0 [] end
  fun mmu intervals total window =
    if window<=0.0 orelse window>total then NONE else if null intervals then SOME 1.0 else
    let val starts=Vector.fromList (List.map #1 intervals)
        val ends=Vector.fromList (List.map #2 intervals)
        val n=length intervals
        val prefix=Array.array (n+1,0.0)
        val _=List.foldl (fn ((a,b),i) => (Array.update (prefix,i+1,Array.sub (prefix,i)+(b-a));i+1)) 0 intervals
        fun search vector predicate =
          let fun loop lo hi=if lo=hi then lo else let val mid=(lo+hi) div 2
                         in if predicate (Vector.sub (vector,mid)) then loop (mid+1) hi else loop lo mid end
          in loop 0 n end
        fun collector lo hi =
          let val i=search ends (fn x => x<=lo)
              val j=search starts (fn x => x<hi)-1
          in if j<i then 0.0 else Array.sub (prefix,j+1)-Array.sub (prefix,i)
               - Real.max (0.0,lo-Vector.sub (starts,i))-Real.max (0.0,Vector.sub (ends,j)-hi) end
        val last=total-window
        fun clamp point=Real.min (Real.max (point,0.0),last)
        fun at point=1.0-collector point (point+window)/window
        val best=List.foldl (fn ((a,b),best) => Real.min (best,Real.min (at (clamp a),at (clamp (b-window)))))
                    (Real.min (at 0.0,at last)) intervals
    in SOME (Real.max (0.0,best)) end
  fun percentile (values:IntInf.int list) q =if null values then 0 else
       List.nth (values,Int.max (0,Int.min (length values-1,Real.ceil (q*Real.fromInt (length values))-1)))
  fun analyse file wallSeconds windows perPass =
    let val (header,ending,recordedWall,rows)=parse file
        val pauses=pauses rows perPass
        val lengths=List.map #length pauses
        val gc=List.foldl (op +) 0 lengths
        val instructions=if get "instrs" ending<>0 then get "instrs" ending else if null rows then 0 else get "instrs" (List.last rows)
        val exactTime=not (null rows) andalso member "t_ns" (hd rows)<>Json.Null
        val wall=case recordedWall of SOME _ => recordedWall | NONE => Option.map (fn seconds => IntInf.fromLarge (Real.toLargeInt IEEEReal.TO_ZERO (seconds*1e9))) wallSeconds
        val (wallIntervals,wallTotal,clock)=
             if null rows then (SOME [],Option.map float wall,"no collections")
             else if exactTime then
               let val intervals=List.map (fn (p:pause) => (float (valOf (#start p)),float (valOf (#finish p)))) pauses
                   val total=List.foldl (fn ((_,b),n) => Real.max (b,n)) (float (getOpt (wall,0))) intervals
               in (SOME intervals,SOME total,"exact (t_ns)") end
             else case wall of SOME elapsed => if elapsed>0 then
                  let val (intervals,total)=instructionTimeline pauses instructions (float (IntInf.max (elapsed-gc,1)))
                  in (SOME intervals,SOME total,"estimated (no t_ns: the mutator's time shared out by instructions)") end
                    else (NONE,NONE,"unknown (no t_ns, no wall_ns, no --wall)")
                | NONE => (NONE,NONE,"unknown (no t_ns, no wall_ns, no --wall)")
        val run=case wallTotal of SOME n => if n>0.0 then SOME n else NONE | NONE => NONE
        val (instrIntervals,instrTotal)=case run of SOME run => if instructions<>0 then
                let val (intervals,total)=instructionTimeline pauses instructions (Real.max (run-float gc,1.0))
                in (SOME intervals,SOME total) end else (NONE,NONE) | NONE => (NONE,NONE)
        val ordered=sorted (op <) lengths
        fun sum key=List.foldl (fn (row,total) => total+get key row) 0 rows
        fun maximum key=List.foldl (fn (row,value) => IntInf.max (get key row,value)) 0 rows
        val kinds=sort (List.foldl (fn (row,ks) => if List.exists (fn k => k=kind row) ks then ks else kind row::ks) [] rows)
        fun utilisation intervals total =Json.Object (List.map (fn (key,w) => (key,
               case (intervals,total) of (SOME intervals,SOME total) => (case mmu intervals total (w*1e6) of SOME value => real value | NONE => Json.Null) | _ => Json.Null)) windows)
        val hist=Array.array (length histogram+1,0)
        fun bin value=let fun loop [] i=i | loop (cut::rest) i=if value<cut then i else loop rest (i+1) in loop histogram 0 end
        val ()=List.app (fn length => let val i=bin (float length/1e6) in Array.update (hist,i,Array.sub (hist,i)+1) end) lengths
        val limits=0.0::histogram
        val labels=ListPair.map (fn (lo,hi) => general lo ^ "-" ^ general hi ^ " ms") (List.take (limits,length histogram),histogram) @ [">" ^ general (List.last histogram) ^ " ms"]
        fun count n=Json.Number (Int.toString n)
        val runValue=case run of NONE => Json.Null | SOME n => if exactTime orelse null rows then big (getOpt (wall,IntInf.fromLarge (Real.toLargeInt IEEEReal.TO_ZERO n))) else real n
        (* A supplied wall can end before the last recorded pause. *)
        val runValue=if exactTime then (case run of NONE => Json.Null | SOME n => big (List.foldl (fn (p:pause,total) => IntInf.max (getOpt (#finish p,0),total)) (getOpt (wall,0)) pauses)) else runValue
    in Json.Object [("log",Json.String file),("header",header),("passes",count (length rows)),("pauses",count (length pauses)),
       ("kinds",Json.Object (List.map (fn k => (k,count (length (List.filter (fn row => kind row=k) rows)))) kinds)),
       ("bytes_allocated",member "bytes" ending),("objects_allocated",member "objects" ending),("instructions",big instructions),
       ("copied",big (sum "copied")),("promoted",big (sum "promoted")),("max_live_after",big (maximum "live_after")),
       ("max_heap_size",big (maximum "heap_size")),("final_heap_size",big (if null rows then 0 else get "heap_size" (List.last rows))),
       ("max_rss_at_gc",big (maximum "rss_bytes")),("vmpeak_kb",member "vmpeak_kb" ending),("vmhwm_kb",member "vmhwm_kb" ending),
       ("complete",Json.Bool (not (null (object ending)))),("gc_ns",big gc),("cpu_ns",big (sum "cpu_ns")),("run_ns",runValue),("wall_clock",Json.String clock),
       ("gc_share",case run of NONE => Json.Null | SOME n => real (float gc/n)),("longest_ns",big (if null ordered then 0 else List.last ordered)),
       ("mean_ns",if null ordered then big 0 else real (float gc/Real.fromInt (length ordered))),
       ("p50_ns",big (percentile ordered 0.50)),("p90_ns",big (percentile ordered 0.90)),("p99_ns",big (percentile ordered 0.99)),("p999_ns",big (percentile ordered 0.999)),
       ("histogram",Json.Array (List.map (fn (i,label) => Json.Array [Json.String label,count (Array.sub (hist,i))]) (ListPair.zip (List.tabulate (length labels,fn i => i),labels)))),
       ("mmu_wall",utilisation wallIntervals wallTotal),("mmu_instr",utilisation instrIntervals instrTotal)] end
end

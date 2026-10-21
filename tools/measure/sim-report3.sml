structure MeasureSimReport3 =
struct
  open MeasureCommon
  structure F=MeasureFormat structure T=MeasureTabular structure D=MeasureValidationText
  fun table rows =
    let val header="| trace | heap | fill | stock: coll. semispace copied | lo | hi | band width | clock max diff | verdict |\n|---|---:|---:|---|---|---|---:|---:|---|"
        fun metrics cell=case String.tokens (fn c => Char.isSpace c orelse c = #"|") cell of [collections,space,copied] =>
                collections ^ ", " ^ intText (IntInf.div (MeasureMMU.natural space,1048576)) ^ " MiB, " ^ fixed 1 (decimal copied/1048576.0) ^ " MiB"
              | _ => raise Failed "malformed simulator validation triple"
        val rows=List.map (fn row => case row of trace::heap::fill::stock::lo::hi::width::clock::verdict::_ =>
               "| " ^ String.concatWith " | " [trace,intText (IntInf.div (MeasureMMU.natural heap,1048576)) ^ "M",fill,metrics stock,metrics lo,metrics hi,
                   trim (String.translate (fn #"|" => "" | c => str c) width),MeasureGCEval.replace clock "maxdiff=" "",verdict] ^ " |"
              | _ => raise Failed "malformed simulator validation row") rows
    in String.concatWith "\n" (header::rows) end
  fun main [directory,output] =
    let val ()=mkdirs output
        val command="tools/heapsim/report3.py " ^ directory ^ " " ^ output
        val files=sort (List.map (fn file => directory ^ "/" ^ file) (List.filter (fn file => String.isSuffix ".log" file orelse String.isSuffix ".txt" file) (entries directory)))
        val log=List.concat (List.map (lines o read) files)
        val test=lines (read (directory ^ "/test2.log"))
        val ok=length (List.filter (String.isPrefix "ok") test) val bad=length (List.filter (String.isPrefix "FAIL") test)
        val checks=List.map trim (List.filter (fn line => String.isPrefix "check " line andalso String.isSubstring "mismatching " line) log)
        val mismatch=length (List.filter (fn line => not (String.isSubstring "mismatching 0 " line)) checks)
        val validation=List.filter (fn row => length row=9 andalso List.nth (row,1)<>"" andalso CharVector.all Char.isDigit (List.nth (row,1)) andalso String.isPrefix "|" (List.nth (row,3))) (List.map tabs log)
        val verdicts=List.foldl (fn (row,counts) => let val key=List.nth (row,8) val n=getOpt (Option.map #2 (List.find (fn (name,_) => key=name) counts),0)
                      in (key,n+1)::List.filter (fn (name,_) => key<>name) counts end) [] validation
        val verdicts=sorted (fn ((a,_),(b,_)) => a<b) verdicts
        val collections=List.filter (fn row => not (String.isPrefix "0 " (trim (String.translate (fn #"|" => "" | c => str c) (List.nth (row,3)))))) validation
        val prototype=List.filter (fn line => String.isSubstring "\t|" line andalso length (tabs line)=7) log
        val parts=["# Validation of the simulator (gcsim)\n",F.format D.intro [F.Text command],
            F.format D.closed [F.Integer (IntInf.fromInt ok),F.Integer (IntInf.fromInt bad),F.Text (String.concatWith "\n" test)],
            F.format D.reading [F.Integer (IntInf.fromInt (length checks)),F.Integer (IntInf.fromInt mismatch),F.Text (String.concatWith "\n" checks)],
            F.format D.copying [F.Integer (IntInf.fromInt (length validation)),F.Text (if null verdicts then "none" else String.concatWith ", " (List.map (fn (key,n) => key ^ " " ^ Int.toString n) verdicts)),F.Text (table collections)],
            F.format D.nursery [F.Text (String.concatWith "\n" prototype)]]
        val ()=write (output ^ "/sim-validation.md",String.concatWith "\n" parts ^ "\n")
        val pretenure=directory ^ "/pretenure"
        val files=List.map (fn file => pretenure ^ "/" ^ file) (List.filter (String.isSuffix ".tsv") (entries pretenure))
        val files=sorted (fn (a,b) => if String.isSubstring "bootstrap" a=String.isSubstring "bootstrap" b then a<b else String.isSubstring "bootstrap" a) files
        val rows=List.concat (List.map (fn file =>
          let val base=String.substring (OS.Path.file file,0,size (OS.Path.file file)-4)
              val split=fields #"." base val n=length split
              val (pair,nursery,old)=if n>=3 then (String.concatWith "." (List.take (split,n-2)),List.nth (split,n-2),List.nth (split,n-1)) else (base,"-","-")
              val data=T.readTable file
              val apply=if null data then "" else T.get "workload" (hd data)
              val learn=if apply<>"" andalso String.isSuffix ("-" ^ apply) pair then String.substring (pair,0,size pair-size apply-1) else pair
              val name=if learn=apply then learn ^ " (half -> half)" else learn ^ " -> " ^ (if apply="" then "?" else apply)
              fun row data=
                let val config=T.get "config" data val (_,rest)=Substring.position "pretenure=" (Substring.full config)
                    val x=if Substring.isEmpty rest then "none" else Substring.string (Substring.takel (fn c => Char.isDigit c orelse c = #".") (Substring.triml 10 rest))
                    fun mb key=fixed 1 (T.number key data/1048576.0)
                in "| " ^ String.concatWith " | " [name,nursery ^ ", " ^ old,x,mb "promoted",mb "pt_bytes",mb "pt_saved",mb "pt_garbage",T.get "majors" data,mb "marked_major",mb "peak_committed"] ^ " |" end
          in List.map row data end) files)
        val parts=["# Pretenuring by allocation site\n",F.format D.pretenure [F.Text command],
              "| learn -> apply | nursery, old space | X | promoted MiB | pretenured MiB | copying saved MiB | garbage added MiB | majors | marked MiB | peak committed MiB |",
              "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"] @ rows
    in write (output ^ "/sim-pretenure.md",String.concatWith "\n" parts ^ "\n");0 end
    | main _=raise Usage "sim-report3 LOGDIR OUTDIR"
end

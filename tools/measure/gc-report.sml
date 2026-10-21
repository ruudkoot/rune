(* GC harness report calculations. Headings/prose are versioned templates;
   fits, grouping, provenance and counter selections are Standard ML. *)
structure MeasureGCReport =
struct
  open MeasureCommon
  structure G=MeasureGCTables structure T=MeasureTabular structure D=MeasureGCReportData structure F=MeasureFormat
  type row=G.row
  fun table heads rows=String.substring (G.table heads rows,0,size (G.table heads rows)-1)
  fun compareOps directory =
    let val directory=directory ^ "/ops"
        fun trace name =
          let val file=if name="compile-sigs" andalso not (exists (directory ^ "/compile-sigs.majors.tsv")) then directory ^ "/m.tsv" else directory ^ "/" ^ name ^ ".majors.tsv"
          in if not (exists file) then "" else
            let val mine=List.map tabs (lines (read file))
                val body=List.concat (List.map (fn model =>
                    let val event=directory ^ "/" ^ name ^ "." ^ model ^ ".ev"
                        val rows=List.filter (fn fields => length fields>=5 andalso List.nth (fields,1)=model) mine
                        val events=if exists event then List.filter (fn row => T.get "kind" row="major") (T.readTable event) else []
                        fun pair (row,event) =
                          let val held=decimal (List.nth (row,3)) val footprint=decimal (List.nth (row,4))
                              val committed=T.number "old_committed" event val whole=T.number "whole" event
                              val diff=if Real.== (committed-whole,0.0) then 0.0 else (footprint-(committed-whole))/(committed-whole)
                              val diff0=if Real.== (committed,0.0) then 0.0 else (footprint-committed)/committed
                          in [name,model,List.nth (row,2),fixed 2 (held/1048576.0),fixed 2 (T.number "held" event/1048576.0),fixed 2 (footprint/1048576.0),
                               fixed 2 (committed/1048576.0),fixed 2 (whole/1048576.0),F.format "%+.1f%%" [F.Decimal (100.0*diff0)],F.format "%+.1f%%" [F.Decimal (100.0*diff)]] end
                    in ListPair.map pair (List.take (rows,Int.min (length rows,length events)),List.take (events,Int.min (length rows,length events))) end)
                       ["segfit","immix","bestfit","nextfit","firstfit"])
                val models=List.foldl (fn (row,models) => let val model=List.nth (row,1) in if List.exists (fn old => old=model) models then models else models @ [model] end) [] body
                fun summary model =
                  let val rows=List.filter (fn row => List.nth (row,1)=model) body
                      fun values index=List.map (fn row => Real.abs (decimal (String.substring (List.nth (row,index),0,size (List.nth (row,index))-1)))) rows
                      val a=values 8 val b=values 9 val n=Real.fromInt (length rows)
                  in [model,Int.toString (length rows),fixed 1 (List.foldl (op +) 0.0 a/n) ^ "%",fixed 1 (List.foldl Real.max 0.0 a) ^ "%",
                       fixed 1 (List.foldl (op +) 0.0 b/n) ^ "%",fixed 1 (List.foldl Real.max 0.0 b) ^ "%"] end
            in if null body then "" else "Summary for " ^ name ^ ", |gcbench - gcsim| per major:\n\n" ^ table ["model","majors","mean vs old_committed","max","mean vs old_committed - whole","max"] (List.map summary models)
                  ^ "\n\n" ^ table ["trace","model","major","held (gcbench) MiB","held (gcsim) MiB","footprint (gcbench) MiB","old_committed (gcsim) MiB","whole (gcsim) MiB","vs old_committed","vs old_committed - whole"] body end end
    in if not (isDir directory) then "" else String.concatWith "\n\n" (List.filter (fn s => s<>"") (List.map trace ["compile-sigs","bootstrap"])) end
  fun main args =
    let val (directory,output)=case args of [] => (fromRoot "tests/out/gcbench",fromRoot "tests/out/gcbench/report")
             | [dir] => (dir,dir ^ "/report") | [dir,out] => (dir,out) | _ => raise Usage "gcbench-report [OUTDIR [RESULTSDIR]]"
        val clock=decimal (env ("GCB_CORE_GHZ","3.3"))
        fun get name event=let val file=directory ^ "/" ^ name ^ ".tsv" in if exists file then G.rows file event else [] end
        fun mem name=get name "mem"
        fun provenance names=String.concatWith "\n" (List.mapPartial (fn name =>
             let val rows=lines (read (directory ^ "/" ^ name ^ ".log"))
                 val command=if null rows then "" else Substring.string (Substring.dropl (fn c => c = #"#" orelse c = #" ") (Substring.full (hd rows)))
                 val loads=List.mapPartial (fn line => let val (_,rest)=Substring.position "starts at load " (Substring.full line)
                     in if Substring.isEmpty rest then NONE else Real.fromString (Substring.string (Substring.triml 15 rest)) end) rows
                 val command=case Substring.position " measure.sh " (Substring.full command) of (first,rest) => if Substring.isEmpty rest then command else Substring.string (Substring.triml 12 rest)
                 val load=if null loads then "" else " (loads at start " ^ fixed 2 (List.foldl Real.min (hd loads) loads) ^ "-" ^ fixed 2 (List.foldl Real.max (hd loads) loads) ^ ")"
             in if command="" then NONE else SOME ("- `" ^ command ^ "`" ^ load ^ (if List.exists (String.isSubstring "UNDER LOAD") rows then " **UNDER LOAD**" else "")) end) names)
        fun render pieces mainTable=List.map (fn D.Literal text => text | D.Clock template => F.format template [F.Decimal clock] | D.Provenance names => provenance names | D.MainTable => mainTable) pieces
        fun write file parts=(mkdirs output;MeasureCommon.write (output ^ "/" ^ file,Substring.string (Substring.dropr Char.isSpace (Substring.full (String.concatWith "\n" parts))) ^ "\n");say ("wrote " ^ output ^ "/" ^ file ^ "\n"))
        fun values row keys digits=ListPair.map (fn (key,digit) => fixed digit (G.get row key)) (keys,digits)
        val l3=mem "h10-l3" @ mem "h10-l3b"
        val latency=mem "h10-lat" @ List.filter (fn (r:row) => String.isPrefix "lat/" (#name r)) l3
        val bandwidth=mem "h10-bw"
        val ()=if null latency then () else
          let val indexed=List.foldl (fn (row:row,rows) => (#name row,row)::List.filter (fn (name,_) => name<> #name row) rows) []
                    (latency @ List.filter (fn (r:row) => String.isPrefix "latpg" (#name r)) l3)
              fun key name=case fields #"/" name of [kind,page,size] =>
                  let val unit=String.sub (size,SysWord.toInt (SysWord.fromInt (String.size size-1)))
                      val scale=case unit of #"K" => 1024.0 | #"M" => 1048576.0 | #"G" => 1073741824.0 | _ => raise Failed "unknown latency size"
                  in (kind,page,decimal (String.substring (size,0,String.size size-1))*scale) end | _ => raise Failed "invalid latency case"
              fun less ((a,_),(b,_))=let val (ka,pa,sa)=key a val (kb,pb,sb)=key b in ka<kb orelse (ka=kb andalso (pa<pb orelse (pa=pb andalso sa<sb))) end
              val body=List.map (fn (name,row) => name::values row ["cyc","ns","l1d_repl","l2_miss","llc_miss","dtlb_ld_walk"] [1,1,2,2,2,2] @ [fixed 0 (100.0*G.get row "spread") ^ "%"]) (sorted less indexed)
              val parts=render D.h10 "" @ [table ["case","cycles/load","ns/load","L1D repl.","L2 miss","LLC miss","dTLB walks","spread"] body]
              val parts=if null bandwidth then parts else parts @ ["","## Bandwidth (memcpy of a buffer into another, memset, a sum of 64-bit words)","",
                    table ["case","cycles/byte","ns/byte","GB/s","L2 miss/byte","LLC miss/byte","spread"]
                    (List.map (fn row:row => [#name row,fixed 3 (G.get row "cyc"),fixed 3 (G.get row "ns"),fixed 1 (1.0/G.get row "ns"),fixed 4 (G.get row "l2_miss"),fixed 4 (G.get row "llc_miss"),fixed 0 (100.0*G.get row "spread") ^ "%"]) bandwidth)]
          in write "gcbench-H10.md" parts end
        val h2=mem "h2-small" @ mem "h2-big"
        val ()=if null h2 then () else
          let val groups=ref [] : ((string*string*string*string)*(int*row) list) list ref
              val ()=List.app (fn row:row => case fields #"/" (#name row) of [collector,shape,size,order,live] =>
                   if size="" orelse not (CharVector.all Char.isDigit size) then () else
                   let val key=(live,shape,order,collector) val old=getOpt (Option.map #2 (List.find (fn (k,_) => k=key) (!groups)),[])
                   in groups:=(key,(integer size,row)::old)::List.filter (fn (k,_) => k<>key) (!groups) end | _ => ()) h2
              fun rank "32K"=0 | rank "1M"=1 | rank "128M"=2 | rank _=9
              val groups=sorted (fn (((a,b,c,d),_),((e,f,g,h),_)) => rank a<rank e orelse (rank a=rank e andalso String.concatWith "\t" [b,c,d]<String.concatWith "\t" [f,g,h])) (!groups)
              val fit=List.mapPartial (fn ((live,shape,order,collector),points) => if length points<2 then NONE else
                  let val points=sorted (fn ((a,_),(b,_)) => a<b) points
                      val (a,b)=G.leastSquares (List.map (fn (size,row) => (Real.fromInt size,G.get row "cyc")) points)
                      val row=case List.find (fn (size,_) => size=32) points of SOME (_,r) => r | NONE => #2 (hd points)
                  in SOME ([live,shape,order,collector,fixed 1 a,fixed 3 b,fixed 1 (a/clock),fixed 3 (b/clock)] @ values row ["cyc","ins","l1d_repl","l2_miss","llc_miss","dtlb_ld_walk"] [1,0,2,2,2,2]) end) groups
              val fitTable=table ["live","shape","order","collector","a cyc/obj","b cyc/B","a ns/obj","b ns/B","cyc/obj @32B","ins/obj @32B","L1D @32B","L2 miss @32B","LLC miss @32B","dTLB @32B"] fit
              val body=List.map (fn row:row => #name row::values row ["cyc","ins","l1d_repl","l2_miss","llc_miss","dtlb_ld_walk"] [1,0,2,2,2,2] @ [fixed 0 (100.0*G.get row "spread") ^ "%"]) h2
          in write "gcbench-H2.md" (render D.h2 "" @ [fitTable,"","## Every row (cycles, instructions and misses per object)","",table ["case (collector/shape/size/order/live)","cyc/obj","ins/obj","L1D repl.","L2 miss","LLC miss","dTLB walks","spread"] body]) end
        val h8=mem "h8"
        val ()=if null h8 then () else
          let fun parse (row:row)=case fields #"/" (#name row) of [how,frames,locals,returns,functions] =>
                 if List.all (fn (prefix,text) => String.isPrefix prefix text) [("frames=",frames),("locals=",locals),("rets=",returns),("funcs=",functions)] then
                     SOME ((String.extract (frames,7,NONE),how,integer (String.extract (returns,5,NONE)),integer (String.extract (functions,6,NONE)),integer (String.extract (locals,7,NONE))),row) else NONE | _ => NONE
              val data=List.mapPartial parse h8
              fun find frame how returns functions locals=Option.map #2 (List.find (fn (key,_) => key=(frame,how,returns,functions,locals)) (List.rev data))
              val body=List.concat (List.map (fn frame => List.concat (List.map (fn how => List.concat (List.map (fn returns => List.mapPartial (fn functions =>
                    let val points=List.mapPartial (fn locals => Option.map (fn row => (locals,row)) (find frame how returns functions locals)) [4,16,64]
                    in if length points<3 then NONE else let val (a,b)=G.leastSquares (List.map (fn (size,row) => (Real.fromInt size,G.get row "cyc")) points)
                             val row=valOf (find frame how returns functions 16)
                       in SOME ([frame,how,Int.toString returns,Int.toString functions] @ List.map (fn (_,row) => fixed 0 (G.get row "cyc")) points @ [fixed 1 a,fixed 2 b,fixed 0 (G.get row "ins"),fixed 2 (G.get row "l2_miss"),fixed 2 (G.get row "llc_miss")]) end end) [1,64,4096]) [4,64,1024])) ["all","live","hash","bits"])) ["100","10K","1M"])
          in write "gcbench-H8.md" (render D.h8 "" @ [table ["frames","how","rets","funcs","4 locals","16 locals","64 locals","per frame (fit)","per slot (fit)","ins @16","L2 miss @16","LLC miss @16"] body]) end
        fun generic (name,title,intro) =
          let val names=if name="" then sort (List.map (fn file => String.substring (file,0,size file-4)) (List.filter (fn file => String.isPrefix "h5-" file andalso String.isSuffix ".tsv" file andalso file<>"h5-frag.tsv") (entries directory))) else [name]
              val rows=List.concat (List.map mem names)
              val body=List.map (fn row:row => [#name row,#unit row] @ List.map (fn key => fixed 2 (G.get row key)) ["cyc","ins","l1d_repl","l2_miss","llc_miss","dtlb_ld_walk"] @ [fixed 1 (G.get row "ns"),fixed 0 (100.0*G.get row "spread") ^ "%"]) rows
              val text=["# " ^ title,"",intro,"",provenance names,"",table ["case","unit","cyc","ins","l1d_repl","l2_miss","llc_miss","dtlb_ld_walk","ns (TSC)","spread"] body]
              val text=if name<>"h6" then text else
                   let val counts=sort (List.foldl (fn (line,ls) => if String.isPrefix "# H6 " line andalso (String.isSubstring "slow" line orelse String.isSubstring "stores" line) andalso not (List.exists (fn old => old=trim line) ls) then trim line::ls else ls) [] (lines (read (directory ^ "/h6.log"))))
                   in text @ ["","## Counts (stores, old-to-young stores, slow paths, cards and remembered objects scanned)","","```",String.concatWith "\n" counts,"```"] end
              val file=if name="" then "gcbench-H5.md" else "gcbench-" ^ String.map Char.toUpper name ^ ".md"
          in if null rows then () else write file text end
        val ()=List.app generic D.generic
        val h1=mem "h1" @ mem "h1-huge" val l2=get "h1" "l2"
        val ()=if null h1 then () else
          let val survival=ref [] : ((string*string)*(int*real)) list ref
              fun log line=if not (String.isPrefix "# H1 n=" line) then () else
                   let val words=String.tokens Char.isSpace line
                   in if length words<15 then () else
                      let val nursery=String.extract (List.nth (words,2),2,NONE) val pf=String.extract (List.nth (words,3),3,NONE)
                          val minors=integer (List.nth (words,5))
                          val percent=String.translate (fn #"%" => "" | #")" => "" | c => str c) (List.nth (words,14))
                      in survival:=((nursery,pf),(minors,decimal percent)):: !survival end end
              val ()=List.app (fn name => List.app log (lines (read (directory ^ "/" ^ name ^ ".log")))) ["h1","h1-huge"]
              val body=List.mapPartial (fn row:row => case fields #"/" (#name row) of kind::nursery::pf::band::rest =>
                  if not (kind="mutator" orelse kind="minor") then NONE else
                   let val key=(String.extract (nursery,2,NONE),String.extract (pf,3,NONE))
                       val (minors,share)=getOpt (Option.map #2 (List.find (fn (old,_) => old=key) (!survival)),(0,0.0))
                       val other=List.find (fn (r:row) => #name r= #name row) (List.rev l2)
                       fun missing key=case other of NONE => "nan" | SOME row => fixed 1 (G.get row key)
                   in SOME (#name row::values row ["cyc","ins","l1d_repl","l2_miss","llc_miss","dtlb_ld_walk"] [0,0,1,1,2,2]
                         @ [missing "l2_rfo_miss",missing "l2_dmd_rd_miss",if kind="minor" then Int.toString minors else "",if kind="minor" then fixed 2 share ^ "%" else "",
                            if kind="minor" then if Real.== (share,0.0) then "nan" else fixed 0 (G.get row "cyc"/(share/100.0)) else "",fixed 0 (100.0*G.get row "spread") ^ "%"]) end | _ => NONE) h1
          in write "gcbench-H1.md" (render D.h1 "" @ [table ["case","cyc/KiB","ins/KiB","L1D repl/KiB","L2 miss/KiB","LLC miss/KiB","dTLB walks/KiB","L2 RFO miss/KiB","L2 demand-read miss/KiB","minors","survival","minor cyc/KiB promoted","spread"] body]) end
        val fragment=directory ^ "/h5-frag.tsv"
        val ()=if not (exists fragment) then () else
          let val rows=sort (List.foldl (fn (line,rows) => if trim line="" orelse List.exists (fn old => old=line) rows then rows else line::rows) [] (lines (read fragment)))
              val (ops,regular)=List.partition (fn line => String.isPrefix "ops:" (List.nth (tabs line,1))) rows
              val parts=render D.frag (table D.fragColumns (List.map tabs regular))
              val parts=if null ops then parts else parts @ ["","## Replays of gcsim's ops stream (same placements and frees for every allocator)","",table D.fragColumns (List.map tabs ops)]
              val comparison=compareOps directory
              val parts=if comparison="" then parts else parts @ ["","## Per major: gcbench's footprint against gcsim's old_committed (same op stream, same schedule)","",
                    "gcsim: `gcsim --trace T --nursery 1M --old MODEL --major-every 16M --events E` (segfit also `--ops`); gcbench:",
                    "`gcbench h5 ops=T.segfit.ops majors=...`. gcsim's old_committed counts whole free blocks or pools still committed",
                    "(column whole; for the free lists gcsim's whole is its own measure); gcbench returns empty pools and blocks.",
                    "held: gcbench's is the live bytes in the old space; gcsim's is its own (lines or blocks held, for Immix and the free lists).","",comparison]
          in write "gcbench-fragmentation.md" parts end
    in 0 end
end

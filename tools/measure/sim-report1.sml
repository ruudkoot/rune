structure MeasureSimReport1 =
struct
  open MeasureCommon
  structure T=MeasureTabular structure D=MeasureSimReport1Data
  type row=(string*string) list
  fun s row key=T.get key row
  fun n row key=T.number key row
  fun b row key=MeasureMMU.natural (s row key)
  fun mb value=fixed 2 (value/1048576.0)
  fun ratio a z=if Real.== (z,0.0) then "-" else fixed 3 (a/z)
  fun percent a z=if Real.== (z,0.0) then "-" else fixed 1 (100.0*a/z) ^ "%"
  fun human n=let fun unit size suffix=if n>=size andalso IntInf.mod (n,size)=0 then SOME (intText (IntInf.div (n,size)) ^ suffix) else NONE
              in case unit 1073741824 "G" of SOME s => s | NONE => (case unit 1048576 "M" of SOME s => s | NONE => (case unit 1024 "K" of SOME s => s | NONE => intText n)) end
  fun table headings rows="| " ^ String.concatWith " | " headings ^ " |\n|" ^ String.concat (List.tabulate (length headings,fn _ => "---|"))
                 ^ (if null rows then "" else "\n" ^ String.concatWith "\n" (List.map (fn row => "| " ^ String.concatWith " | " row ^ " |") rows))
  fun main args =
    let val directory=case args of [] => "tests/out/heapsim" | [path] => path | _ => raise Usage "sim-report [RESULTSDIR]"
        val command="python3 tools/heapsim/report.py" ^ (if null args then "" else " " ^ directory)
        val files=sort (List.filter (fn file => String.isPrefix "sweep-" file andalso String.isSuffix ".tsv" file) (entries directory))
        val rows=List.concat (List.map (fn file => T.readTable (directory ^ "/" ^ file)) files)
        val ()=need (not (null rows),"no sweep TSV files")
        fun lv row=s row "layout" ^ (if s row "variant"="-" then "" else "+" ^ s row "variant")
        fun unique values=List.foldl (fn (x,xs) => if List.exists (fn y => x=y) xs then xs else x::xs) [] values
        fun rank ordered key=let fun loop [] _=100 | loop (x::xs) i=if x=key then i else loop xs (i+1) in loop ordered 0 end
        fun ordering order (a,b)=rank order a<rank order b orelse (rank order a=rank order b andalso a<b)
        val workloads=sorted (ordering D.wl_order) (unique (List.map (fn row => s row "workload") rows))
        val layouts=sorted (ordering D.lv_order) (unique (List.map lv rows))
        fun one workload layout collector params band level=List.find (fn row =>
              s row "workload"=workload andalso lv row=layout andalso s row "collector"=collector andalso s row "params"=params andalso s row "band"=band
                andalso getOpt (Option.map #2 (List.find (fn (key,_) => key="real_level") row),"store")=level) rows
        fun copier workload layout band=one workload layout "copier" "heap=67108864,fill=50" band "store"
        fun nursery workload layout band bytes promote=one workload layout "nursery" ("nursery=" ^ Int.toString bytes ^ ",promote=" ^ promote ^ ",heap=4194304,fill=50") band "store"
        fun optional NONE _="-" | optional (SOME row) f=f row
        fun emit file headings body=
          let val (_,title,note)=valOf (List.find (fn (name,_,_) => name=file) D.reports)
          in write (directory ^ "/" ^ file,"# " ^ title ^ "\n\nMade by: `" ^ command ^ "` (from sweep.sh's results/sweep-*.tsv; sim.c of sim/).\n\n" ^ note ^ table headings body ^ "\n");say ("wrote " ^ file ^ "\n") end
        fun perWorkload f=List.concat (List.map f workloads)
        val allocated=List.mapPartial (fn workload => Option.map (fn base => workload::mb (n base "bytes_L0")::
                List.map (fn layout => optional (copier workload layout "lo") (fn row => ratio (n row "bytes_allocated") (n base "bytes_L0"))) layouts) (copier workload "L0" "lo")) workloads
        val ()=emit "sim-heap-bytes.md" (["workload","L0 MiB"] @ layouts) allocated
        val boxes=perWorkload (fn workload => List.concat (List.map (fn layout => if layout="L0" then [] else List.mapPartial (fn level =>
              case one workload layout "copier" "heap=67108864,fill=50" "lo" level of NONE => NONE | SOME row =>
                 if level<>"store" andalso Real.== (n row "hist_boxes",0.0) then NONE else SOME ([workload,layout,level,s row "extra_boxes",mb (n row "extra_box_bytes")]
                  @ List.map (s row) ["boxes_int","boxes_word","boxes_real"] @ List.map (mb o n row) ["box_bytes_int","box_bytes_word","box_bytes_real"]
                  @ [s row "unrepresentable",percent (n row "extra_box_bytes") (n row "bytes_L0"),s row "objects"])) ["store","call","result"]) layouts))
        val ()=emit "sim-boxes.md" ["workload","layout","level","boxes","box MiB","int","word","real","int MiB","word MiB","real MiB","unrepresentable","box bytes / L0 bytes","objects"] boxes
        val copied=perWorkload (fn workload => case copier workload "L0" "lo" of NONE => [] | SOME base => List.mapPartial (fn layout =>
              case (copier workload layout "lo",copier workload layout "hi") of (SOME lo,SOME hi) => SOME
                 [workload,layout,mb (n lo "bytes_allocated"),ratio (n lo "bytes_allocated") (n base "bytes_L0"),mb (n lo "bytes_copied"),mb (n hi "bytes_copied"),ratio (n lo "bytes_copied") (n base "bytes_copied"),
                  s lo "collections_major",s hi "collections_major",human (b lo "final_semispace"),human (b hi "final_semispace"),mb (n lo "final_live"),mb (n hi "final_live"),fixed 2 (n lo "band_width_pct") ^ "%"] | _ => NONE) layouts)
        val ()=emit "sim-copied-64M.md" ["workload","layout","alloc MiB","alloc/L0","copied lo MiB","copied hi MiB","copied/L0 (lo)","coll lo","coll hi","semispace lo","semispace hi","live@exit lo","live@exit hi","band"] copied
        val collections=perWorkload (fn workload => List.mapPartial (fn layout =>
              let val cells=List.map (fn heap => let val params="heap=" ^ Int.toString heap ^ ",fill=50"
                    in case (one workload layout "copier" params "lo" "store",one workload layout "copier" params "hi" "store") of
                       (SOME lo,SOME hi) => s lo "collections_major" ^ "/" ^ s hi "collections_major" ^ " (" ^ mb (n lo "bytes_copied") ^ "-" ^ mb (n hi "bytes_copied") ^ ")" | _ => "-" end) D.hs
              in if List.all (fn x => x="-") cells then NONE else SOME (workload::layout::cells) end) layouts)
        val ()=emit "sim-collections.md" (["workload","layout"] @ List.map (human o IntInf.fromInt) D.hs) collections
        val survival=perWorkload (fn workload => List.concat (List.map (fn layout => List.mapPartial (fn band =>
              let val cells=List.map (fn bytes => case nursery workload layout band bytes "1" of NONE => "-" | SOME row => fixed 2 (100.0*n row "survival_fraction") ^ "%"
                      ^ optional (nursery workload layout band bytes "2") (fn row => " / " ^ fixed 2 (100.0*n row "promoted_fraction") ^ "%")) D.nsizes
                  val cells=List.map (fn x => if String.isSuffix "-" x andalso x<>"-" then String.substring (x,0,size x-1) else x) cells
              in if List.all (fn x => x="-") cells then NONE else SOME (workload::layout::band::cells) end) ["lo","hi"]) ["L0","L1","L4"]))
        val ()=emit "sim-survival.md" (["workload","layout","band"] @ List.map (human o IntInf.fromInt) D.nsizes) survival
        val remset=perWorkload (fn workload => List.mapPartial (fn bytes => case nursery workload "L0" "lo" bytes "1" of NONE => NONE | SOME row =>
              let val mut=one workload "L0" "mutseg" ("nursery=" ^ Int.toString bytes ^ ",promote=1,heap=4194304,fill=50") "lo" "store"
                  val second=nursery workload "L0" "lo" bytes "2"
              in SOME ([workload,human (IntInf.fromInt bytes)] @ List.map (s row) ["collections_minor","max_remset_entries","max_remset_cards","remset_entries_total","remset_cards_total","oy_setenv","oy_ref","oy_array","setenv_old_src","stores_setenv","stores_ref","stores_array"]
                  @ [optional mut (fn r => s r "max_remset_entries"),optional mut (fn r => s r "remset_entries_total"),optional second (fn r => s r "max_remset_entries"),optional second (fn r => s r "oy_setenv")]) end) D.nsizes)
        val ()=emit "sim-remset.md" ["workload","nursery","minors","max entries","max cards","entries total","cards total","oy SETENV","oy ref_set","oy array_update","SETENV old src","SETENV stores","ref_set stores","array_update stores","mutseg max entries","mutseg entries total","promote2 max entries","promote2 oy SETENV"] remset
        val sticky=perWorkload (fn workload => List.mapPartial (fn bytes => case (nursery workload "L0" "lo" bytes "1",one workload "L0" "sticky" ("nursery=" ^ Int.toString bytes ^ ",heap=4194304,fill=50") "lo" "store") of
             (SOME c,SOME r) => SOME ([workload,human (IntInf.fromInt bytes),mb (n c "bytes_copied_minor"),mb (n c "bytes_copied_major"),s c "collections_major",mb (n c "max_heap")]
                  @ List.map (mb o n r) ["bytes_marked_minor","bytes_marked_major","sweep_bytes"] @ [s r "collections_major",mb (n r "max_heap")]) | _ => NONE) D.nsizes)
        val ()=emit "sim-sticky.md" ["workload","nursery","promoted MiB","major copied MiB","majors","max heap MiB","minor marked MiB","major marked MiB","swept MiB","majors","max heap MiB"] sticky
        fun los workload threshold=one workload "L0" "los" ("heap=67108864,fill=50,los=" ^ Int.toString threshold) "lo" "store"
        val losRows=perWorkload (fn workload => case copier workload "L0" "lo" of NONE => [] | SOME c =>
             let val nur=nursery workload "L0" "lo" 1048576 "1" val keys=["bytes_copied","los_copied_2k","los_copied_8k","los_copied_32k"]
             in [[workload] @ List.map (mb o n c) keys @ List.map (fn key => optional nur (fn r => mb (n r key))) keys
                  @ List.map (fn threshold => optional (los workload threshold) (fn r => String.concatWith " / " [s r "los_objects",mb (n r "los_bytes"),mb (n r "los_live_max"),mb (n r "bytes_copied"),s r "collections_major"])) [2048,8192,32768]] end)
        val ()=emit "sim-los.md" ["workload","copier copied",">=2K of it",">=8K",">=32K","nursery(1M) copied",">=2K",">=8K",">=32K","los 2K","los 8K","los 32K"] losRows
        val compare=perWorkload (fn workload => case copier workload "L0" "lo" of NONE => [] | SOME base =>
              List.mapPartial (fn layout => Option.map (fn lo => [workload,layout,ratio (n lo "bytes_allocated") (n base "bytes_L0"),s lo "extra_boxes",mb (n lo "extra_box_bytes"),ratio (n lo "bytes_copied") (n base "bytes_copied"),
                   (case (copier workload layout "hi",copier workload "L0" "hi") of (SOME hi,SOME bh) => if Real.== (n base "bytes_copied",0.0) then "-" else ratio (n hi "bytes_copied") (n bh "bytes_copied") | _ => "-"),s lo "collections_major" ^ "/" ^ s base "collections_major"]) (copier workload layout "lo")) ["L1","L1+REALIMM","L2","L3","L4","L4+L4UNIFORM","L1+PAIRS","L4+PAIRS"])
        val ()=emit "sim-layouts-vs-L0.md" ["workload","layout","alloc/L0","boxes","box MiB","copied/L0 lo","copied/L0 hi","collections L/L0"] compare
        val coupling=perWorkload (fn workload => case (copier workload "L0" "lo",nursery workload "L0" "lo" 1048576 "1") of (SOME base,SOME bn) =>
              List.mapPartial (fn layout => case (copier workload layout "lo",nursery workload layout "lo" 1048576 "1") of (SOME r,SOME nur) =>
                let val a=if Real.== (n base "bytes_L0",0.0) then 0.0 else n r "bytes_allocated"/n base "bytes_L0"
                in SOME [workload,layout,fixed 3 a,ratio (n r "bytes_copied") (n base "bytes_copied"),if Real.== (a,0.0) orelse Real.== (n base "bytes_copied",0.0) then "-" else fixed 3 (n r "bytes_copied"/n base "bytes_copied"/a),
                   s r "collections_major" ^ "/" ^ s base "collections_major",fixed 2 (100.0*n nur "survival_fraction") ^ "% / " ^ fixed 2 (100.0*n bn "survival_fraction") ^ "%",ratio (n nur "bytes_copied") (n bn "bytes_copied"),
                   s nur "collections_minor" ^ "/" ^ s bn "collections_minor",s nur "max_remset_entries" ^ "/" ^ s bn "max_remset_entries"] end | _ => NONE) layouts | _ => [])
        val ()=emit "sim-coupling.md" ["workload","layout","alloc/L0","copied/L0 (64M)","copied/L0/alloc","collections L/L0","survival 1M L / L0","nursery copied/L0","minors L/L0","max remset L/L0"] coupling
        val selected=List.filter (fn w => List.exists (fn old => old=w) workloads) ["bootstrap","compile-sigs"]
        val answers1=List.concat (List.map (fn workload => case copier workload "L0" "lo" of NONE => [] | SOME base =>
             List.mapPartial (fn layout => Option.map (fn lo =>
                let val hi=copier workload layout "hi" val bh=copier workload "L0" "hi"
                in [workload,layout,mb (n lo "bytes_allocated"),percent (n base "bytes_L0"-n lo "bytes_allocated") (n base "bytes_L0"),mb (n lo "bytes_copied"),optional hi (fn r => mb (n r "bytes_copied")),percent (n base "bytes_copied"-n lo "bytes_copied") (n base "bytes_copied"),
                   (case (hi,bh) of (SOME hi,SOME bh) => percent (n bh "bytes_copied"-n hi "bytes_copied") (n bh "bytes_copied") | _ => "-"),s lo "collections_major" ^ " vs " ^ s base "collections_major",mb (n lo "max_live"),mb (n base "max_live"),s lo "extra_boxes",
                   "int " ^ s lo "boxes_int" ^ " word " ^ s lo "boxes_word" ^ " real " ^ s lo "boxes_real",mb (n lo "extra_box_bytes"),s lo "unrepresentable"] end) (copier workload layout "lo"))
                   ["L1","L1+REALIMM","L2","L3","L4","L4+L4UNIFORM","L1+PAIRS","L4+PAIRS","L1+HDR4","L1+COMPACT","L1+ALIGN16"]) selected)
        val answers2=List.concat (List.map (fn workload => List.mapPartial (fn bytes => Option.map (fn r =>
             let val second=nursery workload "L0" "lo" bytes "2" val mut=one workload "L0" "mutseg" ("nursery=" ^ Int.toString bytes ^ ",promote=1,heap=4194304,fill=50") "lo" "store"
                 val st=one workload "L0" "sticky" ("nursery=" ^ Int.toString bytes ^ ",heap=4194304,fill=50") "lo" "store"
             in [workload,human (IntInf.fromInt bytes),s r "collections_minor",human (b r "nursery_effective"),fixed 2 (100.0*n r "survival_fraction") ^ "%",optional second (fn r => fixed 2 (100.0*n r "promoted_fraction") ^ "%"),mb (n r "bytes_copied_minor"),mb (n r "bytes_copied_major"),s r "collections_major"]
                  @ List.map (s r) ["max_remset_entries","max_remset_cards","remset_entries_total","oy_setenv","oy_ref","oy_array","setenv_old_src"]
                  @ [optional mut (fn r => s r "max_remset_entries"),optional st (fn r => mb (n r "bytes_marked_major")),optional st (fn r => mb (n r "sweep_bytes")),optional st (fn r => s r "collections_major")] end) (nursery workload "L0" "lo" bytes "1")) [262144,1048576,4194304]) selected)
        val answers3=List.concat (List.map (fn workload => case copier workload "L0" "lo" of NONE => [] | SOME c => List.map (fn (threshold,key) =>
              let val nur=nursery workload "L0" "lo" 1048576 "1" val r=los workload threshold
              in [workload,human (IntInf.fromInt threshold),mb (n c "bytes_copied"),mb (n c key),percent (n c key) (n c "bytes_copied"),optional nur (fn r => mb (n r "bytes_copied")),optional nur (fn r => mb (n r key)),
                  optional r (fn r => s r "los_objects"),optional r (fn r => mb (n r "los_bytes")),optional r (fn r => mb (n r "los_live_max")),optional r (fn r => mb (n r "bytes_copied")),optional r (fn r => s r "collections_major")] end)
                     [(2048,"los_copied_2k"),(8192,"los_copied_8k"),(32768,"los_copied_32k")]) selected)
        val answersBody="## Layouts vs L0 (64 MiB copier; boxes at store level)\n\n" ^ table ["workload","layout","alloc MiB","heap bytes saved vs L0","copied lo MiB","copied hi MiB","copied saved (lo)","copied saved (hi)","collections L vs L0","max live L","max live L0","boxes","by tag","box MiB","unrepresentable"] answers1
                 ^ "\n\n## Nursery, remembered set, sticky (L0)\n\n" ^ table ["workload","nursery","minors","effective nursery","survival (first minor)","promoted (2nd survival)","promoted MiB","old-space copied MiB","majors","max remset entries","max cards","entries total","old->young SETENV","ref_set","array_update","SETENV into old closure","mutseg max entries","sticky major marked MiB","sticky swept MiB","sticky majors"] answers2
                 ^ "\n\n## Large-object space\n\n" ^ table ["workload","T","copier(64M) copied","of it objects >= T","share","nursery(1M) copied","of it >= T","LOS objects","LOS alloc MiB","LOS max live","semispace copied with LOS","collections with LOS"] answers3
        val (_,title,_)=valOf (List.find (fn (name,_,_) => name="sim-answers.md") D.reports)
        val ()=write (directory ^ "/sim-answers.md","# " ^ title ^ "\n\nMade by: `" ^ command ^ "` (from sweep.sh's results/sweep-*.tsv; sim.c of sim/).\n\n" ^ answersBody ^ "\n")
        val ()=say "wrote sim-answers.md\n"
        val mlton=List.filter (String.isPrefix "mlton-") workloads
        val aggregate=List.mapPartial (fn workload => case (copier workload "L0" "lo",copier workload "L1" "lo") of (SOME base,SOME l1) =>
             let val l1r=copier workload "L1+REALIMM" "lo" val l2=copier workload "L2" "lo" val l4=copier workload "L4" "lo" val l4u=copier workload "L4+L4UNIFORM" "lo" val l5=copier workload "L1+PAIRS" "lo" val nur=nursery workload "L0" "lo" 1048576 "1"
             in SOME [workload,mb (n base "bytes_L0"),s base "objects",s base "collections_major",mb (n base "bytes_copied"),ratio (n l1 "bytes_allocated") (n base "bytes_L0"),optional l5 (fn r => ratio (n r "bytes_allocated") (n base "bytes_L0")),ratio (n l1 "bytes_copied") (n base "bytes_copied"),
                  s l1 "boxes_real",mb (n l1 "box_bytes_real"),percent (n l1 "box_bytes_real") (n base "bytes_L0"),optional l1r (fn r => s r "boxes_real"),s l1 "unrepresentable",optional l2 (fn r => intText (b r "boxes_word"+b r "boxes_int")),optional l4 (fn r => s r "extra_boxes"),optional l4u (fn r => s r "extra_boxes"),
                  optional nur (fn r => fixed 1 (100.0*n r "survival_fraction") ^ "%"),optional nur (fn r => s r "max_remset_entries"),optional nur (fn r => s r "oy_setenv"),getOpt (Option.map #2 (List.find (fn (key,_) => key="stores_mode") base),"file")] end | _ => NONE) mlton
    in emit "sim-mlton.md" ["workload","L0 MiB","objects","coll","copied MiB","L1 alloc/L0","L5 alloc/L0","L1 copied/L0","L1 real boxes","real box MiB","of L0 bytes","L1r real boxes","L1 unrepresentable","L2 int/word boxes","L4-mono boxes","L4-uniform boxes","survival 1M","max remset 1M","oy SETENV","stores"] aggregate;0 end
end

structure MeasureSimReport2 =
struct
  open MeasureCommon
  structure T=MeasureTabular structure F=MeasureFormat structure D=MeasureSimReportData
  type row=(string*string) list
  fun n row key=T.number key row
  fun s row key=T.get key row
  fun mb n=fixed 1 (n/1048576.0)
  fun natural n=intText (MeasureMMU.natural n)
  fun gc row =
    let fun c key= #2 (valOf (List.find (fn (name,_) => name=key) MeasureTimelineData.coefficients))
        fun e key=n row key
        val objects=e "promoted_objs"
        val average=if Real.== (objects,0.0) then 32.0 else e "copied_minor"/objects
        val scan=if String.isSubstring "jonkers" (s row "config") orelse s row "old"="mlton" then
                    2.0*(e "heap_scan_objs"*c "scan_obj_jonkers"+e "heap_scan_bytes"*c "scan_byte_jonkers")+2.0*e "marked_ptrs"*c "ptr_jonkers"
                 else if s row "old"="mc" orelse not (Real.== (e "compactions",0.0)) then 3.0*(e "heap_scan_objs"*c "scan_obj_lisp2"+e "heap_scan_bytes"*c "scan_byte_lisp2") else 0.0
        val total=e "minors"*c "fixed_minor"+e "majors"*c "fixed_major"+e "slots_total"*c "slot"+e "cards_total"*(c "card"+512.0*c "card_byte")+e "remset_total"*c "remset"
             +e "born_rem_fields"*c "born_rem_field"+e "mut_scan_total"*c "mut_scan_byte"+e "copied_minor"*c "copy_byte"+(if Real.== (average,0.0) then 0.0 else e "copied_minor"/average*c "copy_obj")
             +e "marked_major_objs"*c "mark_obj"+e "marked_fields"*c "mark_field"+e "sweep_scan"*c "sweep_byte"+e "moved_objs"*c "move_obj"+e "moved_bytes"*c "move_byte"
             +e "evac_objs"*c "evac_obj"+e "evac_bytes"*c "evac_byte"+scan+e "satb_work"*c "satb_byte"
    in total/1e6 end
  fun table header rows=MeasureGCTables.table header rows
  fun main (directory::output::requested) =
    let val ()=mkdirs output
        val command="tools/heapsim/report2.py " ^ String.concatWith " " (directory::output::requested)
        val files=List.concat (List.map (fn name => let val dir=directory ^ "/" ^ name
                      in if isDir dir then List.filter (String.isSuffix ".tsv") (entries dir) else [] end) (entries directory))
        val traces=if not (null requested) then requested else
               sorted (fn (a,b) => if String.isPrefix "bootstrap" a=String.isPrefix "bootstrap" b then a<b else String.isPrefix "bootstrap" a)
                    (List.foldl (fn (file,names) => let val name=String.substring (file,0,size file-4) in if List.exists (fn old => name=old) names then names else name::names end) [] files)
        fun load question trace=let val file=directory ^ "/" ^ question ^ "/" ^ trace ^ ".tsv" in if exists file then T.readTable file else [] end
        fun write name title body=MeasureCommon.write (output ^ "/" ^ name,F.format D.intro [F.Text title,F.Text command] ^ body)
        val survival=ref "" val nursery=ref "" val remset=ref ""
        fun add target text=target:= !target ^ text
        fun size bytes=let val bytes=MeasureMMU.natural bytes in if bytes<1048576 then intText (IntInf.div (bytes,1024)) ^ "K" else intText (IntInf.div (bytes,1048576)) ^ "M" end
        val ()=List.app (fn trace => case load "nursery" trace of [] => () | rows =>
          let val first=hd rows
              val ns=sorted (fn (a,b) => MeasureMMU.natural a<MeasureMMU.natural b) (List.foldl (fn (r,names) => let val name=s r "nursery" in if List.exists (fn old => old=name) names then names else name::names end) [] rows)
              fun find nursery promote band=List.find (fn r => s r "nursery"=nursery andalso s r "promote"=promote andalso s r "band"=band) (List.rev rows)
              fun percentage key row=fixed 2 (100.0*n row key) ^ "%"
              val survivalRows=List.mapPartial (fn bytes => case (find bytes "1" "lo",find bytes "2" "lo",find bytes "1" "hi") of
                     (SOME lo,SOME p2,SOME hi) => SOME [size bytes,s lo "minors",percentage "survival" lo,case find bytes "1" "near" of NONE => "-" | SOME r => percentage "survival" r,
                                 percentage "survival" hi,percentage "promoted_frac" lo,percentage "promoted_frac" p2,mb (n p2 "surv_copied") ^ " MB"] | _ => NONE) ns
              val ()=add survival ("\n## " ^ trace ^ "\n\n" ^ s first "objects" ^ " objects, " ^ mb (n first "bytes") ^ " MB allocated, max live " ^ mb (n first "max_live") ^ " MB (at the samples).\n\n"
                    ^ table ["nursery","minors","survival lo","survival near","survival hi","promoted p1","promoted p2 (lo)","survivor copies p2"] survivalRows)
              val pairs=List.concat (List.map (fn bytes => List.mapPartial (fn promote => Option.map (fn row => (bytes,promote,row)) (find bytes promote "lo")) ["1","2"]) ns)
              val ()=add nursery ("\n## " ^ trace ^ "\n\n" ^ table ["nursery","promote","minors","majors","copied minor MB","copied major MB","copied total MB","peak committed MB","stack slots (all)","slots above watermark","GC ms (model)"]
                   (List.map (fn (bytes,promote,row) => [size bytes,promote,s row "minors",s row "majors"] @ List.map (mb o n row) ["copied_minor","copied_major","copied_total","peak_committed"] @ [s row "slots_total",s row "watermark_slots_total",fixed 1 (gc row)]) pairs))
              val oldSource=case find "1048576" "1" "lo" of SOME row => row | NONE => first
              val ()=add remset ("\n## " ^ trace ^ "\n\nStores: " ^ s first "stores" ^ " (SETENV " ^ s first "stores_setenv" ^ ", ref_set " ^ s first "stores_ref" ^ ", array_update " ^ s first "stores_array" ^ "), of them into old objects at a 1M nursery: " ^ s oldSource "stores_old_src" ^ ".\n\n"
                   ^ table ["nursery","promote","remset max","remset total","cards max","cards total (old->young)","cards total (pointer stores)","cards total (all stores)","old->young SETENV","ref","array","born-remembered objs"]
                     (List.map (fn (bytes,promote,row) => [size bytes,promote] @ List.map (s row) ["remset_max","remset_total","cards_max","cards_total","cards_ptr_total","cards_any_total","oy_setenv","oy_ref","oy_array","born_rem_total"]) pairs))
          in () end) traces
        val ()=(write "sim-survival.md" "Survival by nursery size" (!survival);write "sim-nursery.md" "The nursery: copying, collections, stack" (!nursery);write "sim-remset.md" "The remembered set, cards and barrier traffic" (!remset))
        val oldspaces=ref "" val image=ref "" val fragmentation=ref ""
        fun limit row=if Real.== (n row "limit",0.0) then "none" else fixed 2 (n row "limit_x") ^ "x"
        val ()=List.app (fn trace => case load "old" trace of [] => () | rows =>
          let val live=n (hd rows) "max_live"
              val ()=add oldspaces ("\n## " ^ trace ^ " (max live " ^ mb live ^ " MB, 1M nursery)\n\n" ^
                    table ["old space","limit","majors","marked MB","copied (major) MB","moved+evac MB","swept MB","peak committed MB","peak / max live","frag int %","frag ext %","majors over limit","GC ms (model)"]
                       (List.map (fn row => [s row "old" ^ (if String.isSubstring "jonkers" (s row "config") then " (Jonkers)" else ""),limit row,s row "majors",mb (n row "marked_major"),mb (n row "copied_major"),mb (n row "moved_bytes"+n row "evac_bytes"),
                           mb (n row "sweep_scan"),mb (n row "peak_committed"),if Real.== (live,0.0) then "-" else fixed 2 (n row "peak_committed"/live),fixed 1 (100.0*n row "frag_int_mean"),fixed 1 (100.0*n row "frag_ext_mean"),s row "limit_over",fixed 1 (gc row)]) rows))
              val unlimited=List.filter (fn row => Real.== (n row "limit",0.0)) rows
              val chosen=(case unlimited of [] => [] | first::_ => [first]) @ List.filter (fn row => s row "old"="immix" orelse s row "old"="segfit") unlimited
              val ()=add image ("\n## " ^ trace ^ "\n\n" ^ table ["old space","majors","marked MB (all majors)","share born in first 1%","5%","10%","25%"]
                      (List.map (fn row => [s row "old",s row "majors",mb (n row "marked_major")] @ List.map (fn key => fixed 1 (100.0*n row key) ^ "%") ["phase01_share","phase05_share","phase10_share","phase25_share"]) chosen))
              val frag=load "frag" trace
              fun config row=if s row "old"<>"immix" then s row "config" else
                    MeasureGCEval.replace (MeasureGCEval.replace (s row "config") "immix," "immix ") ",fill=50" ""
                    ^ " line=" ^ s row "line" ^ " block=" ^ intText (IntInf.div (MeasureMMU.natural (s row "block"),1024)) ^ "K"
                    ^ (if Real.== (n row "exact_lines",0.0) then "" else " exact") ^ (if Real.== (n row "defrag",0.0) then " nodefrag" else "")
              val ()=if null frag then () else add fragmentation ("\n## " ^ trace ^ "\n\n" ^ table ["config","limit","majors","peak committed MB","frag int %","frag ext %","evacuated MB","overflows"]
                   (List.map (fn row => [config row,limit row,s row "majors",mb (n row "peak_committed"),fixed 1 (100.0*n row "frag_int_mean"),fixed 1 (100.0*n row "frag_ext_mean"),mb (n row "evac_bytes"),s row "limit_over"]) frag))
          in () end) traces
        val ()=(write "sim-oldspaces.md" "Old spaces at equal memory" (!oldspaces);write "sim-image.md" "An image or immortal space: the share of marked bytes born early" (!image);write "sim-fragmentation.md" "Fragmentation: Immix lines, blocks, evacuation; LOS thresholds" (!fragmentation))
        fun floating text=not (isSome (IntInf.fromString text) andalso not (String.isSubstring "." text orelse String.isSubstring "e" text orelse String.isSubstring "E" text))
        val ()=List.app (fn (question,file,title,columns) =>
            let fun section trace=case load question trace of [] => "" | rows =>
                  "\n## " ^ trace ^ "\n\n" ^ table (List.map #1 columns)
                    (List.map (fn row => List.map (fn (heading,key) => case key of NONE => fixed 1 (gc row) | SOME key =>
                       if key="config" then s row key else if String.isSuffix "_mean" key andalso String.isPrefix "frag" key then fixed 1 (100.0*n row key)
                       else if String.isSubstring "MB" heading then mb (n row key) else if String.isSubstring "KB" heading then fixed 0 (n row key/1024.0)
                       else if floating (s row key) andalso (case Real.fromString (s row key) of SOME _ => true | _ => false) then fixed 3 (n row key) else s row key) columns) rows)
            in write file title (String.concat (List.map section traces)) end) D.schemas
    in 0 end
    | main _=raise Usage "sim-report2 SWEEPDIR OUTDIR [TRACE...]"
end

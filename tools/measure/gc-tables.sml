(* GC harness tables and the calibrated H2 least-squares model. *)
structure MeasureGCTables =
struct
  open MeasureCommon
  type row={experiment:string,name:string,unit:string,event:string,reps:string,values:(string*real) list}
  val events=[("mem",["l1d_repl","l2_miss","llc_miss","dtlb_ld_walk"]),("l2",["l2_dmd_rd_miss","l2_rfo_miss","l2_pf_miss","dtlb_st_walk"]),
              ("br",["br_miss","l1d_repl","l2_dmd_rd_miss","llc_miss"]),("tlb",["dtlb_ld_walk","dtlb_walk_cyc","dtlb_st_walk","stlb_hit"])]
  fun get (row:row) name=case List.find (fn (key,_) => key=name) (#values row) of SOME (_,n) => n | NONE => 0.0/0.0
  fun rows file event =List.mapPartial (fn line =>
       if String.isPrefix "#" line then NONE else let val f=tabs line
       in if length f<15 then NONE else
          let val selected=List.nth (f,14)
              val names=case List.find (fn (key,_) => key=selected) events of SOME (_,names) => names | NONE => ["e0","e1","e2","e3"]
              val values=List.map (fn (key,i) => (key,decimal (List.nth (f,i)))) [("n",3),("cyc",4),("ins",5),("tsc",10),("ns",11),("cyc_med",12)]
                  @ ListPair.map (fn (key,value) => (key,decimal value)) (names,List.take (List.drop (f,6),4))
                  @ [("spread",if length f>16 then decimal (List.nth (f,16)) else 0.0)]
          in if event<>"" andalso event<>selected then NONE else SOME {experiment=hd f,name=List.nth (f,1),unit=List.nth (f,2),event=selected,reps=List.nth (f,13),values=values}:row option end end) (lines (read file))
  fun leastSquares points =
    let val n=Real.fromInt (length points)
        val x=List.foldl (fn ((x,_),sum) => x+sum) 0.0 points/n
        val y=List.foldl (fn ((_,y),sum) => y+sum) 0.0 points/n
        val xx=List.foldl (fn ((a,_),sum) => sum+(a-x)*(a-x)) 0.0 points
        val xy=List.foldl (fn ((a,b),sum) => sum+(a-x)*(b-y)) 0.0 points
        val slope=if Real.== (xx,0.0) then 0.0 else xy/xx
    in (y-slope*x,slope) end
  fun table headings rows ="| " ^ String.concatWith " | " headings ^ " |\n|" ^ String.concatWith "|" ("---" :: List.tabulate (length headings-1,fn _ => "---:")) ^ "|\n"
                   ^ String.concat (List.map (fn row => "| " ^ String.concatWith " | " row ^ " |\n") rows)
  fun fitH2 rows =
    let val groups=ref [] : ((string*string*string*string)*(int*row) list) list ref
        val ()=List.app (fn (row:row) => case fields #"/" (#name row) of [collector,shape,size,order,live] =>
              if size="" orelse not (CharVector.all Char.isDigit size) then () else
              let val key=(collector,shape,order,live)
                  val old=getOpt (Option.map #2 (List.find (fn (k,_) => k=key) (!groups)),[])
              in groups:=(key,(integer size,row)::old)::List.filter (fn (k,_) => k<>key) (!groups) end | _ => ()) rows
        val ordered=sorted (fn (((a,b,c,d),_),((e,f,g,h),_)) => String.concatWith "\t" [d,b,c,a] < String.concatWith "\t" [h,f,g,e]) (!groups)
        val ()=say "| collector | shape | order | live | sizes | cyc/obj (a) | cyc/byte (b) | ns/obj (a) | ns/byte (b) | ins/obj at 32 B |\n|---|---|---|---|---|---:|---:|---:|---:|---:|\n"
        val ()=List.app (fn ((collector,shape,order,live),points) => if length points<2 then () else
             let val points=sorted (fn ((a,_),(b,_)) => a<b) points
                 val (a,b)=leastSquares (List.map (fn (size,row) => (Real.fromInt size,get row "cyc")) points)
                 val (an,bn)=leastSquares (List.map (fn (size,row) => (Real.fromInt size,get row "ns")) points)
                 val ins=case List.find (fn (size,_) => size=32) points of SOME (_,row) => fixed 0 (get row "ins") | NONE => ""
                 val cells=[collector,shape,order,live,String.concatWith "," (List.map (Int.toString o #1) points),fixed 1 a,fixed 3 b,fixed 2 an,fixed 4 bn,ins]
             in say ("| " ^ String.concatWith " | " cells ^ " |\n") end) ordered
    in 0 end
  fun main (file::args) =
    let val pattern=ref NONE val event=ref "mem" val columns=ref ["cyc","ins","l1d_repl","l2_miss","llc_miss","dtlb_ld_walk"]
        val perByte=ref false val ns=ref false val fit=ref false
        fun parse []=() | parse ("--grep"::v::rest)=(pattern:=SOME (TerminalPattern.compile false v);parse rest)
          | parse ("--evset"::v::rest)=(event:=v;parse rest) | parse ("--cols"::v::rest)=(columns:=fields #"," v;parse rest)
          | parse ("--per-byte"::rest)=(perByte:=true;parse rest) | parse ("--ns"::rest)=(ns:=true;parse rest)
          | parse ("--fit-h2"::rest)=(fit:=true;parse rest) | parse _=raise Usage "gcbench-tables FILE [--grep REGEX] [--evset SET] [--cols LIST] [--per-byte] [--ns] [--fit-h2]"
        val ()=parse args
        val rows=List.filter (fn (row:row) => case !pattern of NONE => true | SOME p => isSome (TerminalPattern.find p (#name row) 0)) (rows file (!event))
        fun size row=let fun find (a::(rest as b::_))=if a<>"" andalso CharVector.all Char.isDigit a andalso (b="alloc" orelse b="shuf") then SOME (decimal a) else find rest
                           | find _=NONE
                     in find (List.drop (fields #"/" (#name (row:row)),1)) handle Subscript => NONE end
    in if !fit then fitH2 rows else
       (say (table (["case","unit"] @ !columns @ (if !ns then ["ns"] else []) @ ["spread"] @ (if !perByte then ["cyc/B"] else []))
            (List.map (fn row:row => [#name row,#unit row] @ List.map (fn key => fixed 2 (get row key)) (!columns) @ (if !ns then [fixed 2 (get row "ns")] else [])
                  @ [fixed 0 (100.0*get row "spread") ^ "%"] @ (if !perByte then [case size row of NONE => "" | SOME size => fixed 3 (get row "cyc"/size)] else [])) rows));0) end
    | main _=raise Usage "gcbench-tables FILE [OPTIONS]"
end

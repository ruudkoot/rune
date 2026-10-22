(* Replay validation: commands, streams and allocation clocks are retained
   with the trace; range decisions and verdicts belong to SML. *)
structure MeasureSimValidate =
struct
  open MeasureCommon
  type recipe={cwd:string,args:string list,output:string,input:string}
  fun recipe trace : recipe =
    let val rows=lines (read (trace ^ "/DONE"))
        fun get key=case List.find (String.isPrefix (key ^ " ")) rows of NONE => "" | SOME line => String.extract (line,size key+1,NONE)
        val args=CommandWords.split (get "cmd")
        val ()=need (not (null args),"no cmd in " ^ trace ^ "/DONE")
        val adjacent=if String.isSuffix ".rbc" (hd args) then String.substring (hd args,0,size (hd args)-4) ^ ".input" else ""
        val input=if get "stdin"<>"" then get "stdin" else if exists adjacent then adjacent else "/dev/null"
    in {cwd=get "cwd",args=args,output=get "out",input=input} end
  fun metadata file key=case List.find (String.isPrefix (key ^ " ")) (lines (read file)) of NONE => 0 | SOME line => MeasureMMU.natural (String.extract (line,size key+1,NONE))
  fun simulator trace prefix arguments =
    let val args=[fromRoot "bin/gcsim","--max-mb","5000","--trace",trace] @ arguments
        val result=execute (OS.FileSys.getDir ()) prefix args
        val text=successful result
    in case lines text of header::row::_ => ListPair.zip (tabs header,tabs row) | _ => raise Failed "simulator did not produce a header and row" end
  fun number key row=case List.find (fn (name,_) => key=name) row of SOME (_,n) => MeasureMMU.natural n | NONE => raise Failed ("missing simulator column " ^ key)
  fun between n a b=IntInf.min (a,b)<=n andalso n<=IntInf.max (a,b)
  fun vmRun vm (r:recipe) prefix options =
    let val ()=if #output r="" then () else rmTree (#output r)
        val args=["/bin/sh","-c","ulimit -v 4194304 || exit 125; exec \"$@\"","vm-quota",vm,"--jit=off"] @ options @ #args r
        val result=child {args=args,directory= #cwd r,input= #input r,prefix=prefix,timeout=1215,environment=fn e => e}
    in need (#status result=0,"trace VM failed: " ^ #errors result);result end
  fun copying vm output settings trace () =
    let val name=OS.Path.file trace val recipe=recipe trace val failed=ref false
        fun setting (heap,fill) =
          let val base=output ^ "/" ^ name ^ "." ^ heap ^ "." ^ fill
              val log=base ^ ".gclog"
              val result=vmRun vm recipe (output ^ "/" ^ name) ["--nursery","0","--stats","--gc-log",log,"--heap-size",heap,"--heap-fill",fill]
              val (_,_,_,rows)=MeasureMMU.parse log
              val collections=IntInf.fromInt (length rows)
              val semispace=if null rows then MeasureMMU.natural heap else MeasureMMU.get "heap_size" (List.last rows)
              val copied=List.foldl (fn (row,n) => n+MeasureMMU.get "copied" row) 0 rows
              val pre=metadata (trace ^ "/meta.txt") "pretrace_bytes"
              val clocks=List.map (fn row => MeasureMMU.get "bytes" row+MeasureMMU.get "box_bytes" row+pre) rows
              val ()=write (base ^ ".stock-clocks",String.concat (List.map (fn n => intText n ^ "\n") clocks))
              val common=["--nursery","0","--old","copy","--heap-size",heap,"--heap-fill",fill]
              val lo=simulator trace (base ^ ".lo") (common @ ["--band","lo","--events",base ^ ".lo.ev","--header"])
              val hi=simulator trace (base ^ ".hi") (common @ ["--band","hi","--header"])
              val lc=number "majors" lo val ls=number "final_semispace" lo val lx=number "copied_major" lo
              val hc=number "majors" hi val hs=number "final_semispace" hi val hx=number "copied_major" hi
              val events=MeasureTimeline.events (base ^ ".lo.ev")
              val loClocks=List.map (MeasureMMU.get "clock") (List.filter (fn event => text (field "kind" event)="major") events)
              val ()=write (base ^ ".lo-clocks",String.concat (List.map (fn n => intText n ^ "\n") loClocks))
              fun differences (a::aa,b::bb) best=differences (aa,bb) (IntInf.max (best,IntInf.abs (b-a))) | differences _ best=best
              val delta=differences (clocks,loClocks) 0
              val slack=IntInf.div (IntInf.abs (hx-lx),2)+1
              val verdict=if lc=collections andalso ls=semispace andalso lx-slack<=copied andalso copied<=hx+slack then "ok"
                   else if between collections lc hc andalso between semispace ls hs andalso between copied (IntInf.min (lx,hx)-slack) (IntInf.max (lx,hx)+slack) then "band" else "FAIL"
              val ()=if verdict="FAIL" then failed:=true else ()
              val width=if lx>0 then fixed 3 (100.0*MeasureMMU.float (hx-lx)/MeasureMMU.float lx) else "0"
              fun triple a b c=String.concatWith " " (List.map intText [a,b,c])
          in say (String.concatWith "\t" [name,heap,fill,"| " ^ triple collections semispace copied,"| " ^ triple lc ls lx,"| " ^ triple hc hs hx,"| " ^ width ^ "%","maxdiff=" ^ intText delta,verdict] ^ "\n") end
    in List.app setting settings;not (!failed) end
  fun prototype vm output nurseries trace () =
    let val name=OS.Path.file trace val recipe=recipe trace val failed=ref false
        fun one nursery =
          let val base=output ^ "/" ^ name ^ "." ^ nursery val log=base ^ ".gclog"
              val _=vmRun vm recipe (output ^ "/" ^ name) ["--nursery",nursery,"--gc-log",log]
              val (_,_,_,rows)=MeasureMMU.parse log
              val minors=IntInf.fromInt (length (List.filter (fn row => MeasureMMU.kind row="minor") rows))
              val fulls=IntInf.fromInt (length rows)-minors
              val promoted=List.foldl (fn (row,n) => n+MeasureMMU.get "promoted" row) 0 rows
              val cards=List.foldl (fn (row,n) => n+(if MeasureMMU.kind row="minor" then MeasureMMU.get "cards_dirty" row else 0)) 0 rows
              val common=["--nursery",nursery,"--old","copy","--full","appel","--header"]
              val lo=simulator trace (base ^ ".lo") (common @ ["--band","lo"])
              val hi=simulator trace (base ^ ".hi") (common @ ["--band","hi"])
              val lm=number "minors" lo val lf=number "fulls" lo val lp=number "promoted" lo val lc=number "cards_any_total" lo
              val hm=number "minors" hi val hf=number "fulls" hi val hp=number "promoted" hi val hc=number "cards_any_total" hi
              val mn=IntInf.min (lp,hp) val mx=IntInf.max (lp,hp)
              val verdict=if lm=minors andalso lf=fulls andalso between promoted mn mx then "ok"
                    else if lm=minors andalso lf=fulls andalso promoted>mx then "nepotism"
                    else if between minors lm hm andalso between fulls lf hf then "band" else "DIFF"
              val ()=if verdict="DIFF" then failed:=true else ()
              val midpoint=(MeasureMMU.float mn+MeasureMMU.float mx)/2.0
              val percent=if midpoint>0.0 then MeasureFormat.format "%+.2f%%" [MeasureFormat.Decimal (100.0*(MeasureMMU.float promoted-midpoint)/midpoint)] else "-"
              fun quadruple a b c d=String.concatWith " " (List.map intText [a,b,c,d])
          in say (String.concatWith "\t" [name,nursery,"| " ^ quadruple minors fulls promoted cards,"| " ^ quadruple lm lf lp lc,"| " ^ quadruple hm hf hp hc,"| " ^ percent,verdict] ^ "\n") end
    in List.app one nurseries;not (!failed) end
  fun main proto args =
    let val vm=ref (if proto then "" else fromRoot "bin/runevm") val output=ref (if proto then "tests/out/gcsim/vproto" else "tests/out/gcsim/validate")
        val settings=ref "4194304:50 67108864:50 268435456:50 67108864:25 67108864:80" val nurseries=ref "262144 1048576 4194304"
        fun parse ("--vm"::v::rest)=(vm:=v;parse rest) | parse ("--out"::v::rest)=(output:=v;parse rest)
          | parse ("--settings"::v::rest)=(settings:=v;parse rest) | parse ("--nurseries"::v::rest)=(nurseries:=v;parse rest)
          | parse (arg::rest)=if String.isPrefix "-" arg then raise Usage ("unknown validation option " ^ arg) else arg::rest | parse []=[]
        val traces=parse args val ()=need (!vm<>"","prototype validation needs --vm")
        val vm=executable (!vm) val output=OS.Path.mkAbsolute {path= !output,relativeTo=OS.FileSys.getDir ()} val ()=mkdirs output
        val pairs=List.map (fn setting => case fields #":" setting of [heap,fill] => (heap,fill) | _ => raise Usage "setting must be HEAP:FILL") (String.tokens Char.isSpace (!settings))
        val failed=ref false
        val ()=List.app (fn trace => (if (if proto then prototype vm output (String.tokens Char.isSpace (!nurseries)) trace () else copying vm output pairs trace ()) then () else failed:=true)
                         handle Failed why => (failed:=true;say ("FAIL " ^ OS.Path.file trace ^ ": " ^ why ^ "\n"))) traces
    in if !failed then 1 else 0 end
  fun pretenure args =
    let val (output,args)=case args of "--out"::path::rest => (path,rest) | _ => ("tests/out/gcsim",args)
        val (learn,apply,nursery,old)=case args of learn::apply::rest => (learn,apply,case rest of n::_ => n | [] => "1M",case rest of _::old::_ => old | _ => "immix")
              | _ => raise Usage "pretenure [--out DIR] LEARN APPLY [NURSERY] [OLD]"
        val output=output ^ "/pretenure" val ()=mkdirs output
        val ln=OS.Path.file learn val an=OS.Path.file apply
        val tsv=output ^ "/" ^ ln ^ "-" ^ an ^ "." ^ nursery ^ "." ^ old ^ ".tsv" val sites=output ^ "/" ^ ln ^ "." ^ nursery ^ ".sites"
        fun run label args=child {args=["/bin/sh","-c","ulimit -v 6291456 || exit 125; exec \"$@\"","sim-quota",fromRoot "bin/gcsim","--max-mb","5000"] @ args,
                 directory=OS.FileSys.getDir (),input="",prefix=tsv ^ "." ^ label,timeout=7200,environment=fn e => e}
        val _=successful (run "learn" (["--trace",learn,"--nursery",nursery,"--old",old,"--learn",sites] @ (if learn=apply then ["--learn-until","0.5"] else [])))
        val ()=write (tsv,successful (run "baseline" ["--header","--trace",apply,"--nursery",nursery,"--old",old]))
        val ()=List.app (fn x => let val result=run x (["--trace",apply,"--nursery",nursery,"--old",old,"--pretenure",sites,"--pretenure-x",x] @ (if learn=apply then ["--pretenure-from","0.5"] else []))
                  in append (tsv,successful result);append (tsv ^ ".err",#errors result) end) ["50","80","95"]
    in say ("pretenure " ^ ln ^ " -> " ^ an ^ " (" ^ nursery ^ ", " ^ old ^ "): " ^ Int.toString (length (lines (read tsv))-1) ^ " rows in " ^ tsv ^ "\n");0 end
end

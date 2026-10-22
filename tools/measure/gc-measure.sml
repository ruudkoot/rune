(* Idle-gated GC harness samples and least-cycles row selection. *)
structure MeasureGCMeasure =
struct
  open MeasureCommon
  fun load ()=case String.tokens Char.isSpace (read "/proc/loadavg") of first::_ => decimal first | _ => 0.0
  fun measure (name::args) =
    let val count=ref 5 val events=ref ["mem"] val cpu=ref "5" val memory=ref 4194304
        fun parse ("-n"::v::rest)=(count:=integer v;parse rest) | parse ("-e"::v::rest)=(events:=String.tokens Char.isSpace v;parse rest)
          | parse ("-c"::v::rest)=(cpu:=v;parse rest) | parse ("-m"::v::rest)=(memory:=integer v;parse rest)
          | parse ("--"::rest)=rest | parse rest=rest
        val command=parse args val ()=need (!count>0 andalso !memory>0,"invalid GC measurement sample/memory count")
        val output=fromRoot "tests/out/gcbench" val original=output ^ "/gcbench"
        val ()=need (OS.FileSys.access (original,[OS.FileSys.A_EXEC]),"build gcbench before measuring")
        val ()=mkdirs output val binary=output ^ "/" ^ name ^ ".bin"
        val ()=copy original binary val ()=Posix.FileSys.chmod (binary,Posix.FileSys.ST.mode (Posix.FileSys.stat original))
        val base=output ^ "/" ^ name val raw=base ^ ".raw.tsv" val log=base ^ ".log"
        val loadMaxText=env ("LOADMAX","1.5") val loadMax=decimal loadMaxText val spare=integer (env ("SPARE","8388608"))
        val rerun=Real.max (2.0*loadMax,3.0)
        val date=trim (successful (execute root (base ^ ".date") ["date","+%F %T"]))
        val ()=write (log,"# " ^ date ^ " measure.sh " ^ name ^ " -n " ^ Int.toString (!count) ^ " -e \"" ^ String.concatWith " " (!events) ^ "\" -c " ^ !cpu ^ " -m " ^ Int.toString (!memory) ^ " LOADMAX=" ^ loadMaxText ^ " -- " ^ String.concatWith " " command ^ "\n# built with: " ^ trim (read (output ^ "/flags.txt")) ^ "\n")
        val ()=if loadMaxText="1.5" then () else append (log,"# UNDER LOAD: runs start at a 1-minute load below " ^ loadMaxText ^ ", not 1.5: cycles are not an idle machine's\n")
        val ()=write (raw,"")
        val rows=ref [] : string list ref val header=ref ""
        fun idle waited =if load ()<=loadMax andalso (not (exists "/proc/meminfo") orelse MeasureGCEval.available ()>= !memory+spare) then ()
             else if waited>=3600 then raise Failed "GC measurement idle/memory wait exceeded one hour" else (OS.Process.sleep (Time.fromSeconds 15);idle (waited+15))
        fun samples event i retries =if i> !count then () else
          let val ()=need (retries<100,"GC measurement load kept invalidating samples") val ()=idle 0
              val ()=append (log,"# run " ^ Int.toString i ^ " (" ^ event ^ ") starts at load " ^ general (load ()) ^ "\n")
              val ()=rmTree (base ^ ".time")
              val args=["/usr/bin/time","-f","time_%U_%S_%R_%M","-o",base ^ ".time","taskset","-c",!cpu,"timeout","3600",binary] @ command
              val args=["/bin/sh","-c","ulimit -v \"$1\" || exit 125; shift; exec \"$@\"","gcbench-quota",Int.toString (!memory)] @ args
              val result=child {args=args,directory=fromRoot "tests/gcbench",input="",prefix=base ^ ".sample",timeout=3615,environment=setEnv ("GCB_EV",event)}
              val ()=append (log,#errors result ^ String.translate (fn #"_" => " " | c => str c) (read (base ^ ".time")))
              val ()=need (#status result=0,"GC harness sample failed: " ^ #output result)
          in if load ()>rerun then (append (log,"# load " ^ general (load ()) ^ " after run " ^ Int.toString i ^ " (" ^ event ^ "): rerun\n");samples event i (retries+1)) else
               (case List.find (String.isPrefix "#exp") (lines (#output result)) of SOME line => header:=line | NONE => raise Failed "GC harness omitted its row header";
                List.app (fn line => if String.isPrefix "#" line then () else let val line=line ^ "\t" ^ Int.toString i in append (raw,line ^ "\n");rows:= !rows @ [line] end) (lines (#output result));
                append (log,"# run " ^ Int.toString i ^ " (" ^ event ^ ") done at load " ^ general (load ()) ^ "\n");samples event (i+1) 0) end
        val ()=List.app (fn event => samples event 1 0) (!events)
        type best={row:string,minimum:IntInf.int,maximum:IntInf.int}
        val groups=ref [] : ((string*string*string)*best) list ref
        val ()=List.app (fn row => let val cells=tabs row val ()=need (length cells>=15,"GC harness emitted a short row")
                  val key=(hd cells,List.nth (cells,1),List.nth (cells,14)) val cycles=MeasureMMU.natural (List.nth (cells,4))
                  val ()=need (cycles>0,"GC harness cycles unavailable or invalid")
              in case List.find (fn (old,_) => old=key) (!groups) of NONE => groups:= !groups @ [(key,{row=row,minimum=cycles,maximum=cycles})]
                 | SOME (_,old) => groups:=List.map (fn (k,b:best) => if k<>key then (k,b) else (k,{row=if cycles< #minimum b then row else #row b,minimum=IntInf.min (cycles,#minimum b),maximum=IntInf.max (cycles,#maximum b)})) (!groups) end) (!rows)
        val ()=write (base ^ ".tsv",!header ^ "\trun\tspread\n" ^ String.concat (List.map (fn (_,best:best) => #row best ^ "\t" ^ fixed 3 (MeasureMMU.float (#maximum best)/MeasureMMU.float (#minimum best)-1.0) ^ "\n") (!groups)))
    in say ("measure.sh: ../out/gcbench/" ^ name ^ ".tsv\n");0 end
    | measure _=raise Usage "gcbench-measure NAME [-n RUNS] [-e SETS] [-c CPU] [-m KiB] -- COMMAND [ARG=VALUE...]"
  fun main args =
    let val lock=CommandWords.split (env ("GCB_LOCK",""))
    in if null lock orelse env ("GCB_LOCKED","")<>"" then measure args else
         let val payload=CommandLine.name () val prefix=fromRoot ("tests/out/gcbench/locked-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())))
             val result=child {args=lock @ [fromRoot "bin/runevm",payload,"gcbench-measure"] @ args,directory=OS.FileSys.getDir (),input="",prefix=prefix,timeout=86400,
                    environment=setEnv ("GCB_LOCKED","1") o setEnv ("RUNE_TEST_RUN",OS.Path.dir prefix) o setEnv ("RUNE_TEST_CPUS","1")}
         in say (#output result ^ #errors result);#status result end end
end

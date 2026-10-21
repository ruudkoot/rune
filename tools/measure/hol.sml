(* HOL trees remain read-only: caches and theory rebuilds belong to private
   measurement directories. HOL and perf remain independent instruments. *)
structure MeasureHOL =
struct
  open MeasureCommon
  fun absolute path=OS.Path.mkAbsolute {path=path,relativeTo=OS.FileSys.getDir ()}
  fun cache hol output requested =
    let val directory=if requested<>"" then absolute requested else output ^ "/cache-" ^ OS.Path.file hol
        val ()=if exists directory then () else
           let val pending=directory ^ "." ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())) ^ ".pending"
               val ()=rmTree pending
               val ()=copyTree (hol ^ "/tools-rune/cache") pending
           in OS.FileSys.rename {old=pending,new=directory} handle OS.SysErr _ => if exists directory then rmTree pending else raise Failed "HOL cache publication failed" end
    in directory end
  fun kernel args =
    let val (hol,file)=case args of [hol] => (absolute hol,fromRoot "scripts/hol-kernel.sml") | [hol,file] => (absolute hol,absolute file)
                           | _ => raise Usage "hol-kernel HOL [FILE]"
        val build=hol ^ "/bin/buildheap" val state=hol ^ "/bin/hol.state"
        val ()=need (OS.FileSys.access (build,[OS.FileSys.A_EXEC]) andalso exists state,"HOL is not built: " ^ hol)
        val output=fromRoot "tests/out/hol"
        val ()=mkdirs output
        val rune=isDir (hol ^ "/tools-rune")
        val cache=if rune then SOME (cache hol output (env ("RUNE_CACHE",""))) else NONE
        val vm=env ("RUNEVM","") val options=env ("RUNEVM_OPTS","")
        val vm=if vm<>"" then absolute vm else
             if rune andalso options<>"" then
               (case List.find (String.isPrefix "exec ") (lines (read build)) of SOME line =>
                  (case CommandWords.split line of _::vm::_ => vm | _ => "") | NONE => "") else ""
        val ()=if vm="" then () else need (OS.FileSys.access (vm,[OS.FileSys.A_EXEC]),"HOL VM is not executable")
        val inputs=["Arbint","Arbrat",hol ^ "/tools-poly/prelude.ML",hol ^ "/tools-poly/prelude2.ML",file]
        val command=if rune andalso (vm<>"" orelse options<>"") then vm :: CommandWords.split options @ ["--name",build,"--restore",state,"--","--holstate=" ^ state] @ inputs
                       else [build,"--gcthreads=1","--holstate=" ^ state] @ inputs
        val env=case cache of NONE => (fn e => e) | SOME cache => setEnv ("RUNE_CACHE",cache)
        val result=child {args=command,directory=OS.FileSys.getDir (),input="",prefix=output ^ "/kernel-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())),timeout=7200,environment=env}
        val text= #output result ^ #errors result
        val ()=say text
        val ()=need (#status result=0,"HOL kernel process failed")
    in need (not (null (prefixed "HOLBENCH " text)),"hol-kernel: no workload ran");0 end
  fun fresh hol directory theory work =
    let val source=hol ^ "/" ^ directory
        val ()=(rmTree work;copyTree source work)
        val objects=work ^ "/.hol/objs"
        val ()=List.app (fn file => if String.isPrefix (theory ^ "Theory.") file then rmTree (objects ^ "/" ^ file) else ()) (entries objects)
        val makefile=work ^ "/Holmakefile"
        val text=read makefile
        fun rewrite text =
          let val (first,rest)=Substring.position "HOLHEAP" (Substring.full text)
          in if Substring.isEmpty rest then text else
             let val tail=Substring.dropl Char.isSpace (Substring.triml 7 rest)
             in if Substring.isEmpty tail orelse Substring.sub (tail,0)<> #"=" then Substring.string first ^ "HOLHEAP" ^ rewrite (Substring.string (Substring.triml 7 rest)) else
                let val value=Substring.dropl Char.isSpace (Substring.triml 1 tail)
                    val path=Substring.string (Substring.takel (not o Char.isSpace) value)
                    val after=Substring.string (Substring.triml (size path) value)
                in if not (String.isPrefix "../" path) then Substring.string first ^ "HOLHEAP" ^ rewrite (Substring.string (Substring.triml 7 rest))
                   else Substring.string first ^ "HOLHEAP = " ^ OS.Path.mkCanonical (source ^ "/" ^ path) ^ rewrite after end end end
        val changed=rewrite text
    in if changed=text then () else
          (write (makefile ^ ".tmp",changed);OS.FileSys.rename {old=makefile ^ ".tmp",new=makefile};
           (* Time's public resolution is microseconds; this OS adapter
              retains the original nanosecond timestamp used by Holmake. *)
           ignore (successful (execute root (work ^ "/heap-timestamp") ["touch","-r",source ^ "/Holmakefile",makefile]))) end
  fun theory (hol::requested::args) =
    let val hol=absolute hol val runs=ref 3 val output=ref "tests/out/hol" val vm=ref "" val options=ref "" val selectedCache=ref "" val perf=ref true
        fun parse []=() | parse ("--runs"::v::rest)=(runs:=integer v;parse rest) | parse ("--out"::v::rest)=(output:=v;parse rest)
          | parse ("--vm"::v::rest)=(vm:=absolute v;parse rest) | parse ("--vm-opts"::v::rest)=(options:=v;parse rest)
          | parse ("--cache"::v::rest)=(selectedCache:=v;parse rest) | parse ("--no-perf"::rest)=(perf:=false;parse rest)
          | parse _=raise Usage "hol-theory HOL THEORY [--runs N] [--out DIR] [--vm VM] [--vm-opts OPTS] [--cache DIR] [--no-perf]"
        val ()=parse args val output=absolute (!output) val ()=mkdirs output
        val known=[("logroot","src/num/extra_theories"),("mergesort","src/sort"),("string","src/string"),("toto","src/finite_maps")]
        val (directory,theory)=case fields #":" requested of [directory,theory] => (directory,theory)
             | [_] => (case List.find (fn (name,_) => name=requested) known of SOME (_,directory) => (directory,requested) | NONE => raise Usage ("unknown HOL theory: " ^ requested))
             | _ => raise Usage "theory must be DIR:NAME"
        val holmake=hol ^ "/bin/Holmake" val ()=need (exists holmake,"HOL is not built: missing Holmake")
        val rune=isDir (hol ^ "/tools-rune")
        val ()=need (rune orelse (!vm="" andalso !options="" andalso !selectedCache=""),"VM/cache options need a HOL built by Rune")
        val ()=if !vm="" then () else need (OS.FileSys.access (!vm,[OS.FileSys.A_EXEC]),"HOL VM is not executable")
        val environment=if not rune then (fn e => e) else
              setEnv ("RUNE_CACHE",cache hol output (!selectedCache)) o (if !vm="" then (fn e => e) else setEnv ("RUNEVM",!vm))
                  o (if !options="" then (fn e => e) else setEnv ("RUNEVM_OPTS",!options))
        val tag=OS.Path.file hol ^ "-" ^ theory val work=output ^ "/work/" ^ tag
        fun run i =
          let val ()=fresh hol directory theory work
              val base=output ^ "/" ^ tag ^ "." ^ Int.toString i
              val command=["/usr/bin/time","-f","MAXRSS %M KB",holmake,"--nolmbc",theory ^ "Theory.uo"]
              val command=if !perf then ["perf","stat","-x",",","-e","task-clock,cycles:u,instructions:u","-o",base ^ ".perf"] @ command else command
              val result=child {args=command,directory=work,input="",prefix=base,timeout=7200,environment=environment}
              val text= #output result ^ #errors result val ()=write (base ^ ".log",text)
              val logfile=work ^ "/.hol/logs/" ^ theory ^ "Theory"
              val holtext=read logfile
              val ()=if exists logfile then copy logfile (base ^ ".hollog") else ()
              fun took line=let val (_,rest)=Substring.position " took " (Substring.full line)
                            in if Substring.isEmpty rest then NONE else
                               let val duration=Substring.string (Substring.takel (fn c => Char.isDigit c orelse c = #".") (Substring.triml 6 rest))
                               in if duration="" then NONE else SOME duration end end
              val took=last (List.mapPartial took (lines holtext))
              val rss=case List.rev (prefixed "MAXRSS " text) of line::_ => (case String.tokens Char.isSpace line of [_,n,_] => n | _ => "?") | [] => "?"
              val stats=List.mapPartial (fn line => case fields #"," line of n::unit::event::_ => if n<>"" andalso Char.isDigit (String.sub (n,0)) then SOME (hd (fields #":" event),(n,unit)) else NONE | _ => NONE) (lines (read (base ^ ".perf")))
              fun counter name=getOpt (Option.map (#1 o #2) (List.find (fn (key,_) => key=name) stats),"?")
              val clock=case List.find (fn (key,_) => key="task-clock") stats of SOME (_, (n,unit)) => fixed 2 (decimal n/(if unit="msec" then 1e3 else 1e9)) | NONE => "?"
              val ()=say (tag ^ " run " ^ Int.toString i ^ ": exit " ^ Int.toString (#status result) ^ ", took " ^ getOpt (took,"?") ^ " s, task-clock " ^ clock ^ " s, cycles " ^ counter "cycles"
                       ^ ", instructions " ^ counter "instructions" ^ ", max RSS " ^ rss ^ " KB\n")
          in need (#status result=0,"hol-theory: Holmake failed: " ^ base ^ ".log");need (isSome took,"hol-theory: theory was not rebuilt (no took in HOL log)") end
    in List.app run (List.tabulate (!runs,fn i => i));0 end
    | theory _=raise Usage "hol-theory HOL THEORY [OPTIONS]"
end

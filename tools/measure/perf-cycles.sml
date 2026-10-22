(* Hardware counters and heap sweeps. Commands are argument vectors; perf
   supplies observations, while SML owns selection and result checks. *)
structure MeasurePerfCycles =
struct
  open MeasureCommon
  val output=fromRoot "tests/out/cycles"
  fun human text=let val n=decimal text in fixed 1 (n/(if n>=1e9 then 1e9 else 1e6)) ^ (if n>=1e9 then "G" else "M") end
  fun jit "jit"=["--jit=all"] | jit name=
    let val parts=fields #"+" (String.extract (name,4,NONE))
        fun option item=case String.sub (item,0) of #"c" => "--jit-calls=" ^ String.extract (item,1,NONE)
             | #"w" => "--jit-work=" ^ String.extract (item,1,NONE) | #"t" => "--jit-tier=" ^ String.extract (item,1,NONE) | _ => raise Usage ("invalid JIT setting " ^ item)
    in ("--jit=" ^ hd parts)::List.map option (tl parts) end
  fun stats text=case last (List.filter (fn line => String.isPrefix "runevm: " line andalso String.isSubstring " collections," line andalso String.isSubstring "semispace " line) (lines text)) of NONE => [] | SOME line =>
       List.mapPartial (fn s => IntInf.fromString s) (String.tokens (fn c => Char.isSpace c orelse c = #",") line)
  fun counter name values=case List.find (fn (key,_) => key=name orelse key=name ^ ":u" orelse key=name ^ ":uD") values of
      SOME (_,value) => value | NONE => raise Failed ("perf event unavailable: " ^ name)
  fun main args =
    let val runs=ref 5 val configs=ref "rune,mlton,polyml" val profile=ref "" val events=ref "cycles:u,instructions:u" val options=ref [] val vm=ref (fromRoot "bin/runevm")
        val gc=ref false val sweep=ref false val benchDir=ref "" val benchFile=ref "" val filter=ref ""
        fun parse []=() | parse ("--runs"::v::rest)=(runs:=integer v;parse rest) | parse ("--configs"::v::rest)=(configs:=v;parse rest)
          | parse ("--profile"::v::rest)=(profile:=v;parse rest) | parse ("--events"::v::rest)=(events:=v;parse rest)
          | parse ("--vm-opts"::v::rest)=(options:= !options @ CommandWords.split v;parse rest) | parse ("--vm"::v::rest)=(vm:=executable v;parse rest)
          | parse ("--gc"::rest)=(gc:=true;parse rest) | parse ("--sweep"::rest)=(sweep:=true;gc:=true;events:="cycles:uD,instructions:uD,task-clock,page-faults";parse rest)
          | parse ("--mlton-bench"::d::f::rest)=(benchDir:=fromRoot d;benchFile:=fromRoot f;parse rest)
          | parse (v::rest)=if String.isPrefix "-" v then raise Usage ("unknown perf-cycles option " ^ v) else (filter:=v;parse rest)
        val ()=parse args val ()=need (!runs>=1 andalso !runs<=100000,"invalid cycle sample count") val ()=mkdirs output
        val ()=ignore (successful (execute root (output ^ "/vm-version") [!vm,"--version"]))
        val ()=if !gc then options:= !options @ ["--stats"] else ()
        val perf=tool "PERF" "perf" val rune=tool "RUNE" (fromRoot "bin/rune")
        val hosts=env ("RUNE_HOSTS",env ("HOME","") ^ "/.local/rune-hosts")
        val mlton=env ("MLTON",hosts ^ "/mlton/bin/mlton") val polyc=env ("POLYC",hosts ^ "/polyml/bin/polyc")
        val boot=MeasureCensus.boot output
        val configs=fields #"," (!configs)
        fun execute label args=child {args=args,directory=root,input="",prefix=output ^ "/" ^ label,timeout=3600,environment=setEnv ("RUNEVM_OPTIONS",String.concatWith " " (!options))}
        fun built label command =let val result=execute label command in need (#status result=0,"build refused: " ^ #errors result) end
        fun runtime config program =
          if config="rune" orelse config="new" orelse String.isPrefix "jit" config then
            [!vm] @ (if String.isPrefix "jit" config then jit config else []) @ ["--heap-size","67108864"] @ !options @ [fromRoot ("bin/" ^ program ^ ".rbc")]
          else if config="stack" then [fromRoot "bin/runevm-stack","--heap-size","67108864"] @ !options @ [fromRoot ("bin/" ^ program ^ ".stack.rbc")]
          else if config="opt" then
            let val native=output ^ "/" ^ program ^ ".native"
                val ()=built (program ^ ".native") [fromRoot "bin/runeopt-mlton","--options","--heap-size 67108864",fromRoot ("bin/" ^ program ^ ".stack.rbc"),"-o",native]
            in [native] end
          else if List.exists (fn x => x=config) ["mlton","polyml","mlkit","smlnj-legacy","smlnj32","smlnj-dev"] then
            let val binary=fromRoot ("bin/" ^ program ^ "-" ^ config) in need (exists binary,"missing host compiler " ^ config);[binary] end
          else raise Failed ("unknown configuration " ^ config)
        fun build config name source =
          let val register=config="rune" orelse config="new" orelse String.isPrefix "jit" config
              val target=output ^ "/" ^ name ^ (if register then ".new.rbc" else ".rbc")
          in if register orelse config="stack" orelse config="opt" then
               (built (name ^ "." ^ config ^ ".compile") (rune @ [if register then "--target=registers" else "--target=stack",source,"-o",target]);
                if config="opt" then let val native=output ^ "/" ^ name ^ ".native" val ()=built (name ^ ".opt") [fromRoot "bin/runeopt-mlton",target,"-o",native] in [native] end
                else (if register then [!vm] @ (if String.isPrefix "jit" config then jit config else []) else [fromRoot "bin/runevm-stack"]) @ !options @ [target])
             else if config="mlton" then let val native=output ^ "/" ^ name ^ ".mlton" val ()=built (name ^ ".mlton") [mlton,"-output",native,source] in [native] end
             else if config="polyml" then let val native=output ^ "/" ^ name ^ ".poly" val ()=built (name ^ ".poly") [polyc,"-o",native,source] in [native] end
             else raise Failed ("program configuration unavailable: " ^ config) end
        fun command config name =
          if name="bootstrap" then runtime config "rune" @ ["--lib","lib","-o",output ^ "/boot." ^ config ^ ".rbc"] @ boot
          else if !benchDir<>"" orelse exists (fromRoot ("tests/perf/" ^ name ^ ".expected")) then
            let val source=output ^ "/" ^ name ^ "." ^ config ^ ".wrapped.sml"
                val text=if !benchDir<>"" then
                    let val row=List.find (fn line => case String.tokens Char.isSpace line of first::_ => first=name | _ => false) (lines (read (!benchFile)))
                        val reps=case Option.map (String.tokens Char.isSpace) row of SOME (_::n::_) => n | _ => "1"
                    in read (!benchDir ^ "/" ^ name ^ ".sml") ^ "\n" ^ (if config="polyml" then "fun main ()" else "val ()") ^ " = Main.doit " ^ reps ^ "\n" end
                  else let val reps=case MeasureCensus.budget name "wall" of first::_ => first | _ => "1"
                       in (if config="polyml" then "local\n" else "") ^ "structure CommandLine = struct fun name () = \"bench\" fun arguments () : string list = [] end\nfun runeBody__ () = let\n" ^ read (fromRoot ("tests/perf/" ^ name ^ ".sml")) ^ "\nin () end\nfun runeLoop__ 0 = () | runeLoop__ k = (runeBody__ (); runeLoop__ (k - 1))\n" ^
                          (if config="polyml" then "in fun main () = runeLoop__ " ^ reps ^ " end\n" else "val () = runeLoop__ " ^ reps ^ "\n") end
                val ()=write (source,text)
            in build config name source end
          else let val generated=MeasureCensus.budget name "generate" val file=output ^ "/" ^ name ^ ".gen.sml"
                   val ()=if null generated then () else write (file,successful (execute (name ^ ".generate") ([fromRoot "bin/rune-generate","perf"] @ generated)))
                   val files=MeasureCensus.budget name "compile" val doc=MeasureCensus.budget name "runedoc"
                   fun expand "@boot"=boot | expand "@gen"=[file] | expand other=[other]
               in if not (null doc) then runtime config "runedoc" @ ["--lib","lib"] @ doc
                  else (need (not (null files),"no measurement recipe: " ^ name);runtime config "rune" @ ["--lib","lib","-o",output ^ "/" ^ name ^ "." ^ config ^ ".rbc"] @ List.concat (List.map expand files)) end
        fun measure label command =
          let val best=ref (NONE:(IntInf.int*string*string*(string*string) list) option)
              fun one _=
                let val file=output ^ "/" ^ label ^ ".perf"
                    val result=execute label (perf @ ["stat","-x,","-e",!events,"-o",file,"--"] @ command)
                    val ()=need (#status result=0,"perf sample failed: " ^ #errors result)
                    val counters=MeasureLayoutMeasure.counters (read file) val c=counter "cycles" counters val n=counter "instructions" counters
                    val cycles=MeasureMMU.natural c val ()=need (cycles>0,"perf cycles unavailable")
                in case !best of SOME (old,_,_,_) => if cycles>=old then () else
                       (best:=SOME (cycles,n,#errors result,counters);copy file (output ^ "/" ^ label ^ ".best.perf");write (output ^ "/" ^ label ^ ".best.stderr",#errors result))
                 | NONE => (best:=SOME (cycles,n,#errors result,counters);copy file (output ^ "/" ^ label ^ ".best.perf");write (output ^ "/" ^ label ^ ".best.stderr",#errors result)) end
              val ()=List.app one (List.tabulate (!runs,fn i => i))
          in valOf (!best) end
        val programs=if !benchDir<>"" then List.mapPartial (fn line => case String.tokens Char.isSpace line of [] => NONE | name::_ => if String.isPrefix "#" name then NONE else SOME name) (lines (read (!benchFile)))
           else List.map OS.Path.base (List.map OS.Path.file (List.filter (fn file => exists (OS.Path.base file ^ ".expected")) (glob (fromRoot "tests/perf",".sml")))) @
               (if !filter="" then ["compile-sigs","runedoc-page","bootstrap"] else List.map (OS.Path.base o OS.Path.file) (List.filter (fn file => not (exists (OS.Path.base file ^ ".expected"))) (glob (fromRoot "tests/perf",".budget"))))
        val programs=List.filter (String.isSubstring (!filter)) programs
        val gcRows=ref [] : string list ref
        fun row name =
          let val base=ref (NONE:IntInf.int option)
              fun cell config =
                let val cmd=SOME (command config name) handle Failed _ => NONE | OS.SysErr _ => NONE | IO.Io _ => NONE
                in case cmd of NONE => "n/a" | SOME cmd =>
                  let val ()=List.app rmTree [output ^ "/boot." ^ config ^ ".rbc",output ^ "/" ^ name ^ "." ^ config ^ ".rbc",output ^ "/" ^ name ^ "." ^ config ^ ".stdout"]
                      val measured=SOME (measure (name ^ "." ^ config) cmd) handle Failed _ => NONE
                  in case measured of NONE => "FAIL" | SOME (cycles,instructions,errors,values) =>
                    let val stdout=read (output ^ "/" ^ name ^ "." ^ config ^ ".stdout") val expected=fromRoot ("tests/perf/" ^ name ^ ".expected")
                        val correct= !benchDir<>"" orelse not (exists expected) orelse List.exists (fn line => List.exists (fn answer => line=answer) (lines (read expected))) (lines stdout)
                        val present=if name="bootstrap" then exists (output ^ "/boot." ^ config ^ ".rbc") else if exists expected orelse !benchDir<>"" then true else
                               if not (null (MeasureCensus.budget name "runedoc")) then size stdout>0 else List.exists (fn x => x="--typecheck-only") (MeasureCensus.budget name "compile") orelse exists (output ^ "/" ^ name ^ "." ^ config ^ ".rbc")
                    in if not correct then "WRONG" else if not present then "NO OUTPUT" else
                      let val ()=if isSome (!base) then () else base:=SOME cycles val count=intText cycles
                          val stats=stats errors
                          val extra=if length stats=8 then
                            let val collections=List.nth (stats,0) val heap=List.nth (stats,2) val copied=List.nth (stats,4) val us=List.nth (stats,6)
                            in if !gc then gcRows:= !gcRows @ ["| " ^ String.concatWith " | " [name,config,intText collections,human (intText copied),fixed 1 (MeasureMMU.float us/1000.0) ^ " ms",human (intText heap)] ^ " |"] else ();
                               "collections=" ^ intText collections ^ " copied=" ^ intText copied ^ " gc_us=" ^ intText us ^ " semispace=" ^ intText heap end else ""
                          val ()=append (output ^ "/numbers.txt",String.concatWith " " [name,config,count,instructions] ^ " " ^ String.concat (List.map (fn (k,v) => k ^ "=" ^ v ^ " ") values) ^ extra ^ "\n")
                      in human count ^ " cycles, " ^ human instructions ^ " instr. (" ^ fixed 2 (MeasureMMU.float cycles/MeasureMMU.float (valOf (!base))) ^ ")" end end end end
          in say ("| " ^ name ^ " | " ^ String.concatWith " | " (List.map cell configs) ^ " |\n") end
        val ()=say ("| Program | " ^ String.concatWith " | " configs ^ " |\n|---|" ^ String.concat (List.map (fn _ => "---:|") configs) ^ "\n")
        val ()=List.app row programs
        val ()=if !gc then say ("\n| Program | Configuration | Collections | Copied | GC time | Semispace |\n|---|---|---:|---:|---:|---:|" ^ String.concat (List.map (fn row => "\n" ^ row) (!gcRows)) ^ "\n") else ()
        val ()=if !profile="" then () else
          let val parts=fields #":" (!profile) val config=hd parts val name=if length parts>1 then List.nth (parts,1) else "bootstrap"
              val cmd=command config name val cmd=if config="rune" orelse config="new" orelse String.isPrefix "jit" config then hd cmd::"--jit-perf-map"::tl cmd else cmd
              val disassembly=execute "frames" ["objdump","-d","--disassemble=copy_obj",hd cmd]
              val graph=if String.isSubstring "%rsp,%rbp" (#output disassembly) then ["--call-graph","fp"] else []
              val data=output ^ "/" ^ name ^ "." ^ config ^ ".data"
              val ()=built "record" (perf @ ["record","-e","cycles:u"] @ graph @ ["-o",data,"--"] @ cmd)
              val report=successful (execute "symbols" (perf @ ["report","-i",data,"--stdio","--no-children","-g","none","--sort","symbol","--percent-limit","0.3"]))
              val rows=List.filter (fn line => line<>"" andalso not (String.isPrefix "#" line)) (lines report)
              val ()=say ("\n" ^ name ^ " in " ^ config ^ ", by symbol (perf record" ^ (if null graph then "" else ", --call-graph fp") ^ "):\n\n" ^ String.concat (List.map (fn line => line ^ "\n") (List.take (rows,Int.min (25,length rows)))))
              val samples=successful (execute "profile-script" (perf @ ["script","-i",data,"-F","period,ip,sym,dso"]))
              val file=output ^ "/profile.samples" val ()=write (file,samples)
              val groups=successful (execute "profile-groups" [fromRoot "bin/runevm",CommandLine.name (),"perf-groups","--top","12",file])
              val ()=say ("\n" ^ name ^ " in " ^ config ^ ", by group (percent of samples):\n\n")
          in List.app (fn line => case tabs line of ["group",key,value] => if decimal value>=0.05 then say ("  " ^ StringCvt.padRight #" " 40 key ^ " " ^ StringCvt.padLeft #" " 6 value ^ "%\n") else ()
              | ["sym",key,value] => say ("    " ^ StringCvt.padRight #" " 38 key ^ " " ^ StringCvt.padLeft #" " 6 value ^ "%\n") | _ => ()) (lines groups) end
        val ()=if not (!sweep) then () else
          let val ()=write (output ^ "/sweep.txt","") val ()=say "\n| Program | Configuration | Heap | Semispace | Collections | Copied | GC time | Cycles | Task-clock | Faults |\n|---|---|---:|---:|---:|---:|---:|---:|---:|---:|\n"
              fun point name config key heap fill =
                let val ()=options:=["--heap-fill",fill,"--heap-size",heap,"--stats"]
                    val (cycles,instructions,errors,values)=measure (name ^ "." ^ config) (command config name)
                    val stats=stats errors val ()=need (length stats=8,"sweep omitted GC counters")
                    fun n i=intText (List.nth (stats,i))
                    val tc=(counter "task-clock" values handle Failed _ => "0") val pf=(counter "page-faults" values handle Failed _ => "0")
                    val ()=append (output ^ "/sweep.txt",String.concatWith " " [name,config,key,heap,n 0,n 4,n 6,n 3,intText cycles,instructions,tc,pf] ^ "\n")
                in if fill="99" then () else say ("| " ^ String.concatWith " | " [name,config,key,human (n 2),n 0,human (n 4),fixed 1 (decimal (n 6)/1000.0) ^ " ms",human (intText cycles),fixed 1 (decimal tc/1e6) ^ " ms",pf] ^ " |\n");List.nth (stats,5) end
              fun one name config =
                let val live=(point name config "L (fill 99 from 4 MiB)" "4194304" "99" handle Failed _ => 0)
                in if live<=0 then say ("| " ^ name ^ " | " ^ config ^ " | no live data: nothing to sweep | | | | | | | |\n") else
                     List.app (fn key => ignore (point name config key (if key="2GiB" then "2147483648" else intText (IntInf.fromLarge (Real.toLargeInt IEEEReal.TO_ZERO (decimal key*MeasureMMU.float live)))) "100") handle Failed why => say ("sweep sample refused: " ^ why ^ "\n")) ["1.25","1.5","2","3","4","6","8","2GiB"] end
          in List.app (fn name => List.app (one name) configs) programs end
    in 0 end
end

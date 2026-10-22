(* REPL latency uses the shared SML PTY service. Private history prevents
   timed inputs from changing a person's interactive session. *)
structure MeasurePerfRepl =
struct
  open MeasureCommon
  structure F=MeasureFormat
  fun main args =
    let val runs=case args of [] => 5 | [n] => integer n | _ => raise Usage "perf-repl [RUNS]"
        val ()=need (runs>0,"REPL sample count must be positive")
        val output=fromRoot "tests/out/perf-repl"
        val ()=mkdirs output
        val state=output ^ "/state" val config=output ^ "/config"
        val ()=(mkdirs state;mkdirs config)
        val environment=setEnv ("XDG_STATE_HOME",state) o setEnv ("XDG_CONFIG_HOME",config)
        val repl=[fromRoot "bin/runevm","--heap-size","67108864","--restore",fromRoot "bin/rune-repl.img","--","-q","--no-init","--color=never"]
        fun measure file label editor count =
          let fun sample i =
                let val args=[fromRoot "bin/rune-terminal","raw","80","24",file,"--"] @ repl @ (if editor then [] else ["--basic"])
                    val result=child {args=args,directory=root,input="",prefix=output ^ "/" ^ label ^ "-" ^ Int.toString i,timeout=1800,environment=environment}
                    val ()=need (#status result=0,"REPL latency sample failed: " ^ #errors result)
                    val values=List.filter (String.isPrefix ("REPORT " ^ label ^ " ")) (lines (#output result))
                in case values of [line] => (case String.tokens Char.isSpace line of [_,_,value,"ms"] => decimal value | _ => raise Failed "malformed REPL latency record")
                   | _ => raise Failed "REPL sample did not report exactly one interval" end
              val values=List.tabulate (count,fn i => sample i)
          in List.foldl Real.min (hd values) values end
        fun row title value=say (F.format "%-36s %12s\n" [F.Text title,F.Text (fixed 2 value)])
        val start=output ^ "/start.script" val editor=output ^ "/start-editor.script"
        val ()=write (start,"mark start\nuntil - 30\nreport start\nmark entry\nwrite 1;\\r\nuntil val it = 1 : int\\r\\n- 30\nreport entry\nwrite \\x04\nquiet 300\n")
        val ()=write (editor,"mark start\nuntil - 30\nreport start\nwrite \\x04\nquiet 300\n")
        val ()=say (F.format "%-36s %12s\n" [F.Text "what",F.Text "best, ms"])
        val ()=row "start to the first prompt" (measure start "start" false runs)
        val ()=row "start to the editor's first prompt" (measure editor "start" true runs)
        val ()=row "1; to its answer" (measure start "entry" false runs)
        val ()=List.app (fn n =>
          let val file=output ^ "/paste" ^ Int.toString n ^ ".script"
              val declarations=List.tabulate (n,fn i => "val x" ^ Int.toString i ^ " = " ^ Int.toString i ^ (if i=n-1 then ";" else ""))
              val text=String.concatWith "\\r" declarations ^ "\\r"
              val ()=write (file,"until - 30\nmark paste\nwrite " ^ text ^ "\nuntil : int\\r\\n- 600\nreport paste\nwrite \\x04\nquiet 300\n")
          in row ("a paste of " ^ Int.toString n ^ " lines") (measure file "paste" false (if n>=1000 then 2 else runs)) end) [10,100,1000,2000]
        val compiled=execute root (output ^ "/keystroke-compile") [fromRoot "bin/rune","--library","terminal","tests/terminal/keystroke.sml","-o",output ^ "/keystroke.rbc"]
        val ()=if #status compiled<>0 then say (#errors compiled) else say (successful (execute root (output ^ "/keystroke") [fromRoot "bin/runevm",output ^ "/keystroke.rbc"]))
        val load=List.take (String.tokens Char.isSpace (read "/proc/loadavg"),3) handle Subscript => []
    in say ("load average: " ^ String.concatWith " " load ^ "\n");0 end
end

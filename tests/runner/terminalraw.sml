(* Byte/timing scenarios share the same PTY transport as screen checks.
   Timing is reported in milliseconds, separate from deterministic verdicts. *)
structure TerminalRaw =
struct
  open Sh
  exception Failed of string
  fun need (ok,why)=if ok then () else raise Failed why
  fun run {columns,rows,file,args,environment,directory,output} () =
    let val ()=need (exists file,"raw terminal script is missing: " ^ file)
        val t=TerminalIO.spawn {args=args,environment=environment,directory=directory,columns=columns,rows=rows}
        val seen=ref 0
        val dumped=ref 0
        val written=ref (Runtime.clock ())
        val marked=ref (!written)
        val record=ref [] : string list ref
        fun say line=(record:=line :: !record;Sh.say (line ^ "\n"))
        fun elapsed start=Real.fmt (StringCvt.FIX (SOME 2)) (1000.0*Time.toReal (Time.- (Runtime.clock (),start)))
        fun integer value=case Int.fromString value of SOME n => n | NONE => raise Failed "invalid raw terminal integer"
        fun until pattern seconds =
          let val expression=TerminalPattern.compile true pattern
              val deadline=Time.+ (Runtime.clock (),Time.fromReal seconds)
              fun loop ()=
                let val ()=TerminalIO.drain t
                in case TerminalPattern.find expression (!(#raw t)) (!seen) of SOME (_,last) => seen:=last
                   | NONE => if Time.>= (Runtime.clock (),deadline) then raise Failed ("raw terminal timed out: " ^ pattern)
                             else if !(#eof t) then raise Failed ("raw terminal ended before: " ^ pattern)
                             else (ignore (TerminalIO.read t (Time.fromMilliseconds 20));loop ()) end
          in loop ();say ("UNTIL " ^ String.toString pattern ^ " " ^ elapsed (!written) ^ " ms") end
        fun command raw =
          let val text=Hosts.trim raw
              val (command,rest)=TerminalChecks.split text
          in if text="" orelse String.isPrefix "#" text then () else case command of
                "write" => (written:=Runtime.clock ();TerminalIO.write t (TerminalChecks.escapes rest))
              | "until" => let val (pattern,seconds)=TerminalChecks.duration rest 10.0 in until pattern seconds end
              | "quiet" => TerminalIO.quiet t (Time.fromMilliseconds (LargeInt.fromInt (integer rest)))
              | "winch" => let val (columns,rows)=TerminalChecks.split rest in TerminalIO.resize t {columns=integer columns,rows=integer rows} end
              | "mark" => marked:=Runtime.clock ()
              | "report" => say ("REPORT " ^ rest ^ " " ^ elapsed (!marked) ^ " ms")
              | "dump" => (say ("DUMP " ^ Int.toString (size (!(#raw t))- !dumped) ^ " bytes: " ^ String.toString (String.extract (!(#raw t),!dumped,NONE)));dumped:=size (!(#raw t)))
              | _ => raise Failed ("unknown raw terminal instruction: " ^ command)
          end
        fun save ()=(mkdirs (OS.Path.dir output);write (output ^ ".raw",!(#raw t));write (output ^ ".log",String.concatWith "\n" (List.rev (!record)) ^ "\n"))
        val ()=(List.app command (String.fields (fn c => c = #"\n") (read file)) handle e => (save ();TerminalIO.close t;raise e))
    in save ();TerminalIO.close t end
  fun one name () =
    let val args=[fromRoot "bin/runevm","--heap-size","67108864","--restore",fromRoot "bin/rune-repl.img","--"]
        val environment=setEnv ("TERM_PROGRAM","vscode") (setEnv ("TERM","xterm-256color") (TerminalChecks.environment name))
    in run {columns=80,rows=24,file=fromRoot ("tests/terminal/" ^ name ^ ".pty"),args=args,environment=environment,directory=root,
            output=Sh.run ^ "/terminal/" ^ name ^ "/raw"} ();say ("PASS terminal/" ^ name ^ "\n") end
end

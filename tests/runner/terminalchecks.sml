(* Versioned terminal scenarios, evaluated over the runtime PTY and Emulator.
   Shell syntax in a scenario is the program under test; assertions, waits,
   input, resizing, status and fixture comparison are SML operations. *)
structure TerminalChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok,why)=if ok then () else raise Failed why
  fun replace source old value =
    let fun loop text=let val (first,rest)=Substring.position old (Substring.full text)
                      in if Substring.isEmpty rest then text else Substring.string first ^ value ^ loop (Substring.string (Substring.triml (size old) rest)) end
    in loop source end
  fun substitute values source=List.foldl (fn ((key,value),source) => replace source ("@" ^ key ^ "@") value) source values
  fun escapes source =
    let fun hex c=if Char.isDigit c then ord c-ord #"0" else if c>= #"a" andalso c<= #"f" then ord c-ord #"a"+10
                     else if c>= #"A" andalso c<= #"F" then ord c-ord #"A"+10 else raise Failed "invalid hexadecimal input escape"
        fun loop i=if i=size source then "" else if String.sub (source,i)<> #"\\" then str (String.sub (source,i)) ^ loop (i+1)
             else if i+1=size source then raise Failed "trailing input escape" else
             let val c=String.sub (source,i+1)
             in case c of #"n" => "\n" ^ loop (i+2) | #"r" => "\r" ^ loop (i+2) | #"t" => "\t" ^ loop (i+2)
               | #"e" => "\027" ^ loop (i+2) | #"b" => "\b" ^ loop (i+2) | #"f" => "\f" ^ loop (i+2)
               | #"x" => if i+3<size source then str (Char.chr (16*hex (String.sub (source,i+2))+hex (String.sub (source,i+3)))) ^ loop (i+4) else raise Failed "short hex input escape"
               | #"\\" => "\\" ^ loop (i+2) | _ => raise Failed ("unsupported input escape: " ^ str c)
             end
    in loop 0 end
  fun key "Enter"="\r" | key "Tab"="\t" | key "BSpace"="\127" | key "Escape"="\027"
    | key "Up"="\027[A" | key "Down"="\027[B" | key "Right"="\027[C" | key "Left"="\027[D"
    | key name=if String.isPrefix "C-" name andalso size name=3 then str (Char.chr (ord (Char.toUpper (String.sub (name,2))) mod 32))
               else if String.isPrefix "M-" name then "\027" ^ key (String.extract (name,2,NONE))
               else if size name=1 then name else raise Failed ("unknown terminal key " ^ name)
  fun split text =let val (first,rest)=Substring.position " " (Substring.full text)
                 in (Substring.string first,if Substring.isEmpty rest then "" else Substring.string (Substring.triml 1 rest)) end
  fun duration text fallback =
    let val parts=String.fields (fn c => c = #" ") text
        val last=List.last parts
    in case (if length parts>1 andalso last<>"" andalso CharVector.all (fn c => Char.isDigit c orelse c = #".") last then Real.fromString last else NONE) of SOME seconds => if seconds>0.0 then
           (String.substring (text,0,size text-size (List.last parts)-1),seconds) else raise Failed "nonpositive terminal deadline"
       | NONE => (text,fallback) end
  fun plain text =
    let fun trimRight line=Substring.string (Substring.dropr Char.isSpace (Substring.full line))
        fun trimRows []=[] | trimRows ("" :: rest)=trimRows rest | trimRows rows=rows
        val rows=List.map trimRight (String.fields (fn c => c = #"\n") text)
    in String.concatWith "\n" (List.rev (trimRows (List.rev rows))) ^ "\n" end
  fun screen t=plain (Emulator.text (!(#screen (t : TerminalIO.terminal))))
  fun wait t pattern seconds present styled =
    let val expression=TerminalPattern.compile false pattern
        val deadline=Time.+ (Runtime.clock (),Time.fromReal seconds)
        fun loop ()=
          let val ()=TerminalIO.drain t
              val text=if styled then TerminalIO.styled t else screen t
              val found=isSome (TerminalPattern.find expression text 0)
          in if found=present then () else if Time.>= (Runtime.clock (),deadline) then
                  raise Failed ((if present then "missing " else "still present ") ^ pattern ^ "\n" ^ screen t)
             else (ignore (TerminalIO.read t (Time.fromMilliseconds 20));loop ()) end
    in loop () end
  fun environment name =
    let val directory=run ^ "/terminal/" ^ name
        val ()=(rmTree (directory ^ "/state");rmTree (directory ^ "/config");mkdirs (directory ^ "/state");mkdirs (directory ^ "/config"))
    in setEnv ("TERM","xterm") (setEnv ("RUNE_COLORS","auto")
         (setEnv ("XDG_STATE_HOME",OS.FileSys.fullPath (directory ^ "/state"))
          (setEnv ("XDG_CONFIG_HOME",OS.FileSys.fullPath (directory ^ "/config"))
           (unsetEnv ["FORCE_COLOR","CLICOLOR_FORCE","NO_COLOR","CLICOLOR","RUNE_CACHE","AI_AGENT","CLAUDECODE","CODEX_SANDBOX","CURSOR_AGENT","GEMINI_CLI"] (Posix.ProcEnv.environ ()))))) end
  fun version () =
    let val text=read (fromRoot "build/config.sml")
        val (_,rest)=Substring.position "val version = \"" (Substring.full text)
        val rest=Substring.triml (size "val version = \"") rest
    in need (not (Substring.isEmpty rest),"build version is unavailable");Substring.string (#1 (Substring.position "\"" rest)) end
  val prepared=run ^ "/terminal-prepared"
  fun prepare () =
    let val ()=mkdirs prepared
        fun compile name libraries source =
          let val status=Children.exec Subprocess.unlimited (fn e => e)
               {cmd=[fromRoot "bin/rune"] @ libraries @ [source,"-o",prepared ^ "/" ^ name ^ ".rbc"],dir=SOME root,stdin="",
                stdout=prepared ^ "/" ^ name ^ ".out",stderr=prepared ^ "/" ^ name ^ ".err",timeout=120}
          in need (status=0,"terminal probe compile failed: " ^ name ^ ": " ^ read (prepared ^ "/" ^ name ^ ".err")) end
    in compile "keys" [] "tests/terminal/keys.sml";compile "readline" ["--library","terminal"] "examples/readline.sml";
       compile "display" ["--library","test/runner"] "tests/runner/displayfixture.sml" end
  fun substitutions windows =
    let val vm=fromRoot (if windows then "bin/runevm.exe" else "bin/runevm")
    in [("REPL",quote vm ^ " --heap-size 67108864 --restore " ^ quote (fromRoot "bin/rune-repl.img") ^ " --"),
        ("KEYS",quote vm ^ " --stack-size 1048576 " ^ quote (prepared ^ "/keys.rbc")),
        ("READLINE",quote vm ^ " " ^ quote (prepared ^ "/readline.rbc")),("VERSION",version ()),("DIR",fromRoot "tests/terminal")] end
  fun start windows name columns rows command =
    let fun assignments ("env" :: rest) env=assignments rest env
          | assignments (first :: rest) env=if String.isSubstring "=" first then
               let val (key,value)=Substring.position "=" (Substring.full first)
               in assignments rest (setEnv (Substring.string key,Substring.string (Substring.triml 1 value)) env) end
             else (first :: rest,env)
          | assignments [] env=([],env)
        val shell=not windows andalso List.exists (fn token => String.isSubstring token command) [";","|","&&",">","<"]
        val (args,env)=if not shell then assignments (CommandWords.split command) (environment name)
                       else (["/bin/sh","-c",command],environment name)
    in need (not (null args),"empty terminal command");TerminalIO.spawn {args=args,environment=env,directory=root,columns=columns,rows=rows} end
  fun restoration () =
    let fun check (key,status) =
          let val name="restore-" ^ key
              val t=start false name 80 30 (#2 (valOf (List.find (fn (key,_) => key="KEYS") (substitutions false))))
              fun verify ()=
                let val ()=wait t "^size 80x30$" 20.0 true false
                    val ()=TerminalIO.write t key
                    val got=TerminalIO.wait t 20.0
                    val flags=Posix.TTY.getlflag (Posix.TTY.TC.getattr (TerminalIO.input (#session t)))
                in need (got=status,"raw-mode probe exit changed: " ^ key);
                   need (Posix.TTY.L.allSet (Posix.TTY.L.flags [Posix.TTY.L.icanon,Posix.TTY.L.echo],flags),"terminal raw mode survived " ^ key)
                end
              val ()=(verify () handle e => (TerminalIO.close t;raise e))
          in TerminalIO.close t end
    in List.app check [("q",0),("x",1),("f",2),("t",143),("h",129)];say "PASS terminal/term-restore\n" end
  fun one false "term-restore" () =
        (need (exists (fromRoot "tests/terminal/term-restore.script"),"selected restore fixture is missing");restoration ())
    | one windows name () =
    let val file=fromRoot ("tests/terminal/" ^ name ^ ".script")
        val ()=need (exists file andalso read file<>"","selected terminal fixture is missing: " ^ file)
        val values=substitutions windows
        val active=ref NONE : TerminalIO.terminal option ref
        fun terminal ()=case !active of SOME t => t | NONE => raise Failed "terminal instruction before start"
        fun number text=case Int.fromString text of SOME n => n | NONE => raise Failed ("invalid terminal integer: " ^ text)
        fun command raw =
          let val raw=substitute values raw
              val text=Hosts.trim raw
              val (command,rest)=split text
          in if text="" orelse String.isPrefix "#" text then () else
             case command of
               "start" => let val (columns,rest)=split rest val (rows,program)=split rest
                           in need (not (isSome (!active)),"terminal already started");active:=SOME (start windows name (number columns) (number rows) program) end
             | "send" => TerminalIO.write (terminal ()) (escapes rest)
             | "keys" => List.app (TerminalIO.write (terminal ()) o key) (String.tokens Char.isSpace rest)
             | "paste" => TerminalIO.write (terminal ()) ("\027[200~" ^ escapes rest ^ "\027[201~")
             | "wait" => let val (pattern,seconds)=duration rest 20.0 in wait (terminal ()) pattern seconds true false end
             | "waits" => let val (pattern,seconds)=duration rest 20.0 in wait (terminal ()) pattern seconds true true end
             | "gone" => let val (pattern,seconds)=duration rest 20.0 in wait (terminal ()) pattern seconds false false end
             | "resize" => let val (columns,rows)=split rest in TerminalIO.resize (terminal ()) {columns=number columns,rows=number rows} end
             | "expect" => let val ()=need (exists rest,"terminal screen fixture is missing: " ^ rest)
                                val expected=plain (substitute values (read rest))
                                val seconds=case OS.Process.getEnv "TERMINAL_SCREEN_TIMEOUT" of NONE => 20.0
                                     | SOME value => (case Real.fromString value of SOME n => if n>0.0 then n else raise Failed "invalid screen timeout"
                                                      | NONE => raise Failed "invalid screen timeout")
                                val deadline=Time.+ (Runtime.clock (),Time.fromReal seconds)
                                fun loop ()=let val ()=TerminalIO.drain (terminal ()) val got=screen (terminal ())
                                   in if got=expected then () else if Time.>= (Runtime.clock (),deadline) then
                                        (write (run ^ "/terminal/" ^ name ^ "/screen.got",got);raise Failed ("terminal screen differs: " ^ rest ^ "\n" ^ got))
                                      else (ignore (TerminalIO.read (terminal ()) (Time.fromMilliseconds 20));loop ()) end
                            in loop () end
             | "capture" => write (rest,screen (terminal ()))
             | "exited" => let val args=String.tokens Char.isSpace rest
                                val expected=case args of [] => NONE | n::_ => SOME (number n)
                                val seconds=case args of [_,s] => getOpt (Real.fromString s,20.0) | _ => 20.0
                                val status=TerminalIO.wait (terminal ()) seconds
                            in need (not (isSome expected) orelse expected=SOME status,"terminal exit differs: " ^ Int.toString status) end
             | "sleep" => let val deadline=Time.+ (Runtime.clock (),Time.fromMilliseconds (LargeInt.fromInt (number rest)))
                              fun loop ()=if Time.>= (Runtime.clock (),deadline) then () else (ignore (TerminalIO.read (terminal ()) (Time.fromMilliseconds 10));loop ())
                          in loop () end
             | _ => raise Failed ("unknown terminal instruction: " ^ command)
          end
        fun save ()=case !active of NONE => () | SOME t =>
             (write (run ^ "/terminal/" ^ name ^ "/raw.bin",!(#raw t));write (run ^ "/terminal/" ^ name ^ "/screen",screen t))
        fun finish ()=(save ();case !active of NONE => () | SOME t => TerminalIO.close t)
        val ()=(List.app command (String.fields (fn c => c = #"\n") (read file)) handle e => ((finish () handle _ => ());raise e))
    in finish ();say ("PASS terminal/" ^ name ^ "\n") end
end

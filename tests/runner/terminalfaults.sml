(* Driver faults exercise actual PTYs, child status and retained frames.
   The C fixture changes only OS terminal flags; assertions are SML. *)
structure TerminalFaults =
struct
  open Sh
  fun need (ok,why)=if ok then () else raise Fail ("terminal fault: " ^ why)
  fun one () =
    let val directory=run ^ "/terminal-faults"
        val fixture=directory ^ "/fixture with spaces"
        val ()=(mkdirs (fixture ^ "/tests/terminal");mkdirs (fixture ^ "/build"))
        val ()=TerminalPlatform.copy (fromRoot "build/config.sml") (fixture ^ "/build/config.sml")
        val worker=fromRoot "bin/rune-terminal"
        fun execute name script expected succeeds =
          let val ()=write (fixture ^ "/tests/terminal/" ^ name ^ ".script",script)
              val status=Children.exec {addressSpace=NONE,cpuTime=SOME 30,fileSize=SOME (8*1024*1024),core=SOME 0}
                   (setEnv ("RUNE_TEST_ROOT",fixture) o setEnv ("TERMINAL_SCREEN_TIMEOUT","1") o setEnv ("TERMINAL_OUTPUT_LIMIT","65536"))
                   {cmd=[worker,"one",name],dir=SOME root,stdin="",stdout=directory ^ "/" ^ name ^ ".out",stderr=directory ^ "/" ^ name ^ ".err",timeout=15}
              val out=read (directory ^ "/" ^ name ^ ".out")
          in need ((status=0)=succeeds andalso status<>124 andalso String.isSubstring expected out,"unexpected " ^ name ^ " result: " ^ out) end
        val ()=write (fixture ^ "/wrong.screen","wrong\n")
        val ()=execute "wrong-frame" ("start 20 4 /bin/sh -c 'printf correct; sleep 30'\nwait correct\nexpect " ^ fixture ^ "/wrong.screen\n") "screen differs" false
        val ()=execute "dropped-key" "start 20 4 /bin/sh -c 'printf ready; sleep 30'\nwait ready\nsend x\nwait got-x 1\n" "missing got-x" false
        val ()=execute "invalid-size" "start 0 4 /bin/sh -c 'exit 0'\n" "FAIL terminal" false
        val ()=execute "crash-after-answer" "start 20 4 /bin/sh -c 'printf done; kill -SEGV $$'\nwait done\nexited 0\n" "exit differs" false
        val ()=execute "flood" "start 20 4 /bin/sh -c 'yes X'\nwait impossible 1\n" "output exceeds" false
        (* Replay the basic fixture with its result and next prompt apart.
           Sending at the result races the terminal's echo, so the answer
           then follows "- " instead of starting a line of its own. *)
        val basic=directory ^ "/basic-peer"
        val ()=write (basic,"#!/bin/sh\n" ^
             "printf '%s' '- '\nIFS= read -r input || exit 2\n" ^
             "printf '%s\\n' 'val x = \"two\" : string'\nsleep 1\n" ^
             "printf '%s' '- '\nIFS= read -r input || exit 3\n" ^
             "printf '%s\\n' 'val it = \"two\" : string'\nprintf '%s' '- '\n" ^
             "IFS= read -r input || exit 4\n")
        val ()=Posix.FileSys.chmod (basic,Posix.FileSys.S.irwxu)
        val ()=TerminalPlatform.copy (fromRoot "tests/terminal/repl-basic.screen") (fixture ^ "/tests/terminal/repl-basic.screen")
        val script=TerminalChecks.replace (read (fromRoot "tests/terminal/repl-basic.script")) "@REPL@" (quote basic)
        val script=TerminalChecks.replace script "wait ^val it = \"two\" : string$" "wait ^val it = \"two\" : string$ 3"
        val ()=execute "delayed-basic-prompt" script "PASS terminal/delayed-basic-prompt" true
        val pidfile=directory ^ "/descendant.pid"
        val background="(trap \"\" HUP; sleep 30) & echo $! > " ^ quote pidfile ^ "; printf done"
        val ()=execute "background-child" ("start 20 4 /bin/sh -c " ^ quote background ^ "\nwait done\n") "PASS terminal" true
        val descendant=case Int.fromString (Hosts.trim (read pidfile)) of SOME pid => pid | NONE => raise Fail "missing planted descendant"
        fun alive ()=(Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt descendant)),Posix.Signal.fromWord 0w0);
                       let val stat=read ("/proc/" ^ Int.toString descendant ^ "/stat")
                           val fields=String.tokens Char.isSpace stat
                       in not (length fields>2 andalso List.nth (fields,2)="Z") end) handle OS.SysErr _ => false
        val ()=OS.Process.sleep (Time.fromMilliseconds 100)
        val ()=need (not (alive ()) orelse
             (Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt descendant)),Posix.Signal.kill);false),"background terminal child survived cleanup")
        val source=directory ^ "/raw-exit.c"
        val binary=directory ^ "/raw-exit"
        val ()=write (source,"#include <termios.h>\n#include <unistd.h>\nint main(void) { struct termios t; if(tcgetattr(0,&t)) return 2; t.c_lflag &= ~(ICANON|ECHO); if(tcsetattr(0,TCSANOW,&t)) return 3; _exit(0); }\n")
        val status=Children.exec Subprocess.unlimited (fn e => e)
             {cmd=["cc",source,"-o",binary],dir=SOME root,stdin="",stdout=directory ^ "/cc.out",stderr=directory ^ "/cc.err",timeout=60}
        val ()=need (status=0,"raw-mode fixture did not compile")
        val t=TerminalIO.spawn {args=[binary],environment=Posix.ProcEnv.environ (),directory=root,columns=80,rows=24}
        val ()=ignore (TerminalIO.wait t 10.0)
        val flags=Posix.TTY.getlflag (Posix.TTY.TC.getattr (TerminalIO.input (#session t)))
        val cooked=Posix.TTY.L.allSet (Posix.TTY.L.flags [Posix.TTY.L.icanon,Posix.TTY.L.echo],flags)
        val ()=TerminalIO.close t
        val ()=need (not cooked,"bad raw-mode restoration was not observable")
        val s=Pty.spawn {program="/bin/sh",args=["sh","-c","exit 0"],env=NONE,dir=NONE,columns=80,rows=24}
        val ()=ignore (Subprocess.wait (SOME (Pty.process s)))
        val ()=(Pty.close s;Pty.close s)
        val closed=(ignore (Pty.input s);false) handle Pty.Closed => true
        val ()=need (closed,"closed terminal descriptor remained available")
    in say "PASS terminal frame, input, dimensions, crash, flood, descendant, restoration and closed-session faults\n" end
end

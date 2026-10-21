(* Capture the actual runner through a PTY and through ordinary streams.
   Assertions concern final frames, progress, failure styles and resize. *)
structure TerminalDisplay =
struct
  open Sh
  fun need (ok,why)=if ok then () else raise Fail ("runner display: " ^ why)
  fun one () =
    let val directory=run ^ "/terminal-display"
        val ()=mkdirs directory
        val vm=fromRoot "bin/runevm"
        val payload=TerminalChecks.prepared ^ "/display.rbc"
        fun environment name=setEnv ("DISPLAY_VM",vm) (setEnv ("DISPLAY_PAYLOAD",payload) (TerminalChecks.environment name))
        fun args name=[vm,payload,"run","--root",root,"--out",directory ^ "/" ^ name,"--history",directory ^ "/" ^ name ^ "-history.tsv","-j","1"]
        val t=TerminalIO.spawn {args=args "tty",environment=environment "display",directory=root,columns=120,rows=32}
        fun check () =
          let val ()=TerminalChecks.wait t "[0-2]/2 done" 10.0 true false
              val ()=TerminalIO.resize t {columns=100,rows=28}
              val status=TerminalIO.wait t 20.0
              val screen=TerminalChecks.screen t
              val raw= !(#raw t)
              val ()=write (directory ^ "/tty.raw",raw)
              val ()=write (directory ^ "/tty.screen",screen)
              val ()=need (status=1 andalso String.isSubstring "RESULT: FAIL 2 of 2" screen,"final result frame differs: " ^ screen)
              val ()=need (String.isSubstring "display/fails" screen,"failure identity disappeared")
              val ()=need (not (String.isSubstring "running" screen),"stale progress remains in the final frame")
              val cells=List.concat (List.tabulate (28,fn i => Emulator.row (!(#screen t),i)))
              val ()=need (List.exists (fn ({text,style}:Emulator.cell) => text="F" andalso #fg style=Style.Ansi 1 andalso #bold style) cells,"failure styles were lost")
              fun final bytes=String.isSubstring "RESULT: FAIL" (Emulator.text (Emulator.write (Emulator.new {columns=100,rows=28,policy=Grapheme.ByCluster},bytes)))
              val ()=need (not (final "\r0/2 done, 0 failed, 1 running\027[K"),"a stale-only frame passed")
          in () end
        val ()=(check () handle e => (TerminalIO.close t;raise e))
        val ()=TerminalIO.close t
        val status=Children.exec Subprocess.unlimited (fn _ => environment "display-plain")
             {cmd=args "plain",dir=SOME root,stdin="",stdout=directory ^ "/plain.out",stderr=directory ^ "/plain.err",timeout=30}
        val plain=read (directory ^ "/plain.out")
        val ()=need (status=1 andalso String.isSubstring "RESULT: FAIL 2 of 2" plain andalso String.isSubstring "display/fails" plain,"plain result differs")
        val ()=need (not (CharVector.exists (fn c => c = #"\027") plain),"non-terminal report contains drawing escapes")
    in say "PASS runner display progress, failure, resize, final frame and plain output\n" end
end

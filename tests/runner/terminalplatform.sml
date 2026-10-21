(* Native Windows staging is separate from terminal capability. Every VM
   width owns its staging tree and private scenario state. *)
structure TerminalPlatform =
struct
  open Sh
  fun copy source target =
    let val ()=mkdirs (OS.Path.dir target)
        val input=BinIO.openIn source val output=BinIO.openOut target
        fun loop ()=let val data=BinIO.inputN (input,65536) in if Word8Vector.length data=0 then () else (BinIO.output (output,data);loop ()) end
        val ()=(loop () handle e => (BinIO.closeIn input;BinIO.closeOut output;raise e))
    in BinIO.closeIn input;BinIO.closeOut output end
  fun prepare () =
    let val directory=WindowsDir.directory () ^ "/terminal-sml-" ^ OS.Path.file run
        fun bits (name,binary)=
          let val stage=directory ^ "/" ^ name
              val files=[("bin/" ^ binary,"bin/runevm.exe"),("bin/rune-repl.img","bin/rune-repl.img"),("bin/rune-repl.cmd","bin/rune-repl.cmd"),
                    ("bin/rune-terminal.rbc","bin/rune-terminal.rbc"),("build/config.sml","build/config.sml")]
              val ()=List.app (fn (source,target) => copy (fromRoot source) (stage ^ "/" ^ target)) files
              val ()=List.app (fn file => copy (fromRoot ("bin/" ^ file)) (stage ^ "/bin/" ^ file)) (List.filter (String.isSuffix ".dll") (entries (fromRoot "bin")))
              val ()=List.app (fn file => copy (fromRoot ("tests/terminal/" ^ file)) (stage ^ "/tests/terminal/" ^ file))
                    (List.filter (fn file => String.isSuffix ".script" file orelse String.isSuffix ".screen" file) (entries (fromRoot "tests/terminal")))
              val ()=List.app (fn file => copy (TerminalChecks.prepared ^ "/" ^ file ^ ".rbc") (stage ^ "/tests/out/terminal/terminal-prepared/" ^ file ^ ".rbc")) ["keys","readline"]
          in () end
        val ()=List.app bits [("64","runevm.exe"),("32","runevm32.exe")]
    in write (run ^ "/terminal-windows-stage",directory ^ "\n") end
  fun stage bits=let val directory=Hosts.trim (read (run ^ "/terminal-windows-stage"))
                in TerminalChecks.need (directory<>"" andalso (bits="64" orelse bits="32"),"Windows terminal staging is unavailable");directory ^ "/" ^ bits end
  fun one bits name () =
    let val directory=stage bits
        val out=run ^ "/terminal-windows/" ^ bits ^ "/" ^ name
        val ()=mkdirs out
        val env=setEnv ("WSLENV","RUNE_TEST_ROOT:RUNE_TEST_RUN:" ^ env ("WSLENV",""))
                 (setEnv ("RUNE_TEST_ROOT",".") (setEnv ("RUNE_TEST_RUN","tests/out/terminal") (Posix.ProcEnv.environ ())))
        val status=Children.exec Subprocess.unlimited (fn _ => env)
             {cmd=[directory ^ "/bin/runevm.exe","bin/rune-terminal.rbc","native-one",name],dir=SOME directory,stdin="",stdout=out ^ "/stdout",stderr=out ^ "/stderr",timeout=300}
        val source=directory ^ "/tests/out/terminal/terminal/" ^ name
        val ()=List.app (fn file => if exists (source ^ "/" ^ file) then copy (source ^ "/" ^ file) (out ^ "/" ^ file) else ()) ["raw.bin","screen","screen.got"]
    in say (read (out ^ "/stdout"));TerminalChecks.need (status=0,"Windows terminal scenario failed: " ^ read (out ^ "/stderr")) end
  fun cmd bits () =
    let val directory=stage bits
        val out=run ^ "/terminal-cmd-" ^ bits
        val status=Children.exec Subprocess.unlimited (fn e => e)
             {cmd=["/mnt/c/Windows/System32/cmd.exe","/d","/c","bin\\rune-repl.cmd","--no-init","-e","1 + 1;"],dir=SOME directory,stdin="",stdout=out ^ ".out",stderr=out ^ ".err",timeout=60}
        val text=String.translate (fn #"\r" => "" | c => str c) (read (out ^ ".out"))
    in TerminalChecks.need (status=0 andalso text="val it = 2 : int\n","Windows REPL cmd launcher differs: " ^ text);say ("PASS terminal/windows-" ^ bits ^ "/rune-repl.cmd\n") end
end

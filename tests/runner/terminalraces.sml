(* Hold a command open until the driver has typed ahead, so the terminal
   transition is tested without relying on scheduling or a short sleep. *)
structure TerminalRaces =
struct
  open Sh
  fun need (ok, why) = if ok then () else raise Fail ("terminal race: " ^ why)
  fun one () =
    let
      val () = mkdirs run
      val directory = OS.FileSys.fullPath run ^ "/terminal-races"
      val () = mkdirs directory
      val binary = directory ^ "/resize-read"
      val status = Children.exec Subprocess.unlimited (fn e => e)
        {cmd = ["cc", "-std=c17", "-Wall", "-Wextra", "-pedantic", "-Iruntime",
                "-U_FORTIFY_SOURCE", "-Dpoll=rune_test_poll",
                "tests/terminal/resize-read.c", "runtime/sys/sys_posix.c", "-o", binary],
         dir = SOME root, stdin = "", stdout = directory ^ "/cc.out", stderr = directory ^ "/cc.err", timeout = 60}
      val () = need (status = 0, "resize probe compile: " ^ read (directory ^ "/cc.err"))
      val status = Children.exec Subprocess.unlimited (fn e => e)
        {cmd = [binary], dir = SOME root, stdin = "", stdout = directory ^ "/resize.out",
         stderr = directory ^ "/resize.err", timeout = 15}
      val () = need (status = 0, "pending resize: " ^ read (directory ^ "/resize.err"))
      val gate = directory ^ "/continue"
      val source = directory ^ "/wait.sml"
      val edited = directory ^ "/edited.sml"
      val editor = directory ^ "/editor"
      val () = if exists gate then OS.FileSys.remove gate else ()
      val () = write (source,
        "val () = (print \"command-ready\\n\"; TextIO.flushOut TextIO.stdOut;\n" ^
        "  while not (OS.FileSys.access (\"" ^ String.toString gate ^ "\", [])) do\n" ^
        "    OS.Process.sleep (Time.fromMilliseconds 10));\n")
      val () = write (edited, "val edited = 17;\n")
      val () = write (editor, "#!/bin/sh\nprintf 'editor-ready\\n'\nIFS= read -r line\n[ \"$line\" = editor-input ]\n")
      val () = Posix.FileSys.chmod (editor, Posix.FileSys.S.irwxu)
      val environment = setEnv ("VISUAL", quote editor) (TerminalChecks.environment "races")
      val t = TerminalIO.spawn
        {args = [fromRoot "bin/runevm", "--heap-size", "67108864", "--restore", fromRoot "bin/rune-repl.img", "--", "--no-init"],
         environment = environment, directory = root, columns = 100, rows = 30}
      fun wait pattern = TerminalChecks.wait t pattern 20.0 true false
      fun send text = TerminalIO.write t (text ^ "\r")
      fun mode cooked =
        let val attrs = Posix.TTY.TC.getattr (TerminalIO.input (#session t))
            val localFlags = Posix.TTY.getlflag attrs
            val inputFlags = Posix.TTY.getiflag attrs
        in need (Posix.TTY.L.anySet (Posix.TTY.L.echo, localFlags) = cooked andalso
                 Posix.TTY.L.anySet (Posix.TTY.L.icanon, localFlags) = cooked andalso
                 Posix.TTY.I.anySet (Posix.TTY.I.icrnl, inputFlags) = cooked,
                 if cooked then "external reader did not get cooked input" else "command did not keep type-ahead quiet") end
      fun check () =
        (wait "^-$";
         send (":use " ^ source);
         wait "^command-ready$";
         mode false;
         send "val typedAhead = 40 + 2;";
         write (gate, "continue\n");
         wait "^val typedAhead = 42 : int$";
         send ":sh printf 'shell-ready\\n'; IFS= read -r line; printf 'shell-got:%s\\n' \"$line\"";
         wait "^shell-ready$";
         mode true;
         send "shell-input";
         wait "^shell-got:shell-input$";
         (* The shell owns cooked input until it exits; wait for the REPL
            to take it back before typing the next command. *)
         wait "^-$";
         send (":edit " ^ edited);
         wait "^editor-ready$";
         mode true;
         send "editor-input";
         wait "^val edited = 17 : int$";
         send ":quit";
         need (TerminalIO.wait t 20.0 = 0, "REPL exit"))
      fun save () = (TerminalIO.drain t; write (directory ^ "/raw.bin", !(#raw t));
                     write (directory ^ "/screen", TerminalChecks.screen t))
      val () = (check () handle e => (save (); TerminalIO.close t; raise e))
    in save (); TerminalIO.close t; say "PASS terminal pending resize, command type-ahead, shell and editor modes\n" end
end

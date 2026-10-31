(* Terminal scenarios are ordinary inventory cases; capability is the
   runtime PTY, independent of tmux or a Python installation. *)
structure TerminalJobs =
struct
  open Sh
  fun tags names tree=List.foldl (fn (name,tree) => Test.tag name tree) tree names
  fun job name args after =Test.it name
      {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-terminal " ^ String.concatWith " " (List.map quote args)],
       env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 300,cap=0,cpus=1,memory=1000,pools=[],exclusive=false,after=after,judge=failLines} : Run.command Test.tree
  val files=glob (fromRoot "tests/terminal",".script")
  val scripts=List.map (fn file => OS.Path.base (OS.Path.file file)) files
  val raw=List.map (fn file => OS.Path.base (OS.Path.file file)) (glob (fromRoot "tests/terminal",".pty"))
  val windows=List.map (fn file => OS.Path.base (OS.Path.file file)) (List.filter (fn file => firstLine file="# windows") files)
  val covers=["covers:tests/terminal/*","covers:tests/runner/terminal*.sml","covers:tests/runner/displayfixture.sml","covers:lib/terminal/*","covers:lib/test/runner/report*.sml","covers:lib/basis/pty*.sml"]
  val base=Test.requires ["pty"] (tags (["check","test-terminal"] @ covers)
      (Test.describe "terminal" (job "prepare" ["prepare"] [] ::
          List.map (fn name => job name ["one",name] ["terminal/prepare"]) scripts @
          List.map (fn name => job name ["raw-one",name] ["terminal/prepare"]) raw @
          [job "runner-display" ["display"] ["terminal/prepare"],
           Test.requires ["cc"] (job "races" ["races"] ["terminal/prepare"]),
           Test.requires ["cc"] (job "faults" ["faults"] ["terminal/prepare"])])))
  val windowsTree=Test.requires ["windows"] (tags (["test-windows","nightly","windows","vm"] @ covers)
      (Test.describe "terminal" (job "windows-prepare" ["windows-prepare"] ["terminal/prepare"] ::
           List.map (fn bits => Test.describe ("windows-" ^ bits)
             (List.map (fn name => job name ["windows-one",bits,name] ["terminal/windows-prepare"]) windows @
                  [job "rune-repl.cmd" ["windows-cmd",bits] ["terminal/windows-prepare"]])) ["64","32"])))
  val tree=Test.describe "" [base,windowsTree]
  val capabilities=[{name="pty",probe="bin/rune-terminal probe",hint="build a VM with POSIX PTY support or Windows ConPTY"}]
end

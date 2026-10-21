(* Windows staging, compilation, execution, refusals and shared oracles are
   named producer/consumer cases in the same inventory as every local way. *)
structure WindowsJobs =
struct
  open Sh
  fun failure e=case e of WindowsChecks.Failed text => text | WindowsDir.Unavailable text => text
       | VMChecks.Failed text => text | VMOracles.Failed text => text | _ => General.exnMessage e
  fun protect f ()=f () handle e => (say ("FAIL Windows: " ^ failure e ^ "\n");Posix.Process.exit 0w1)
  fun command ["platform-faults"]=SOME (protect PlatformFaults.one)
    | command ["windows-directory"]=SOME (protect (fn () => say (WindowsDir.directory () ^ "\n")))
    | command ["windows-prepare"]=SOME (protect WindowsChecks.prepare)
    | command ["windows-compile",id,name]=SOME (protect (WindowsChecks.compile id name))
    | command ["windows-run",family,vm,name]=SOME (protect (WindowsChecks.runCase family vm name))
    | command ["windows-count",family,vm,name]=SOME (protect (WindowsChecks.count family vm name))
    | command ["windows-image",family,vm]=SOME (protect (WindowsChecks.image family vm))
    | command ["windows-refusals",family,vm]=SOME (protect (WindowsChecks.refusals family vm))
    | command ["vm-refusals",vm,defs,directory]=SOME (protect (fn () => VMChecks.run {vm=vm,defs=defs,directory=fromRoot directory,logs=fromRoot directory}))
    | command _=NONE
  fun tags names tree=List.foldl (fn (tag,tree) => Test.tag tag tree) tree names
  fun job name args after =
    Test.it name {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-windows " ^ String.concatWith " " (List.map quote args)],
       env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 1800,cap=0,cpus=1,memory=500,pools=[],exclusive=false,after=after,judge=failLines} : Run.command Test.tree
  val faults=tags ["check","covers:tests/runner/windows*.sml","covers:tests/runner/langchecks.sml"]
       (Test.describe "platform" [job "faults" ["platform-faults"] []])
  fun tree () =
    let val selected=env ("WINDOWS_SELECTED","0")="1"
        val names=WindowsChecks.names ()
        val families=WindowsChecks.families ()
        val compilers=List.foldl (fn (f : WindowsChecks.family,values) =>
              if List.exists (fn old : WindowsChecks.family => #compilerID old= #compilerID f) values then values else values @ [f]) [] families
        val ()=if null names then raise Fail "Windows selection has no matching language fixtures" else ()
        val compile=Test.describe "compile" (List.map (fn f : WindowsChecks.family =>
             let val active=List.filter (fn name => not (isSome (WindowsChecks.skipped name))) names
             in Test.describe (#compilerID f) (List.map (fn name => job name ["windows-compile",#compilerID f,name] ["windows/prepare"]) active) end) compilers)
        fun one (f : WindowsChecks.family) =
          Test.describe (#name f) (List.map (fn vm =>
            let val vmName=OS.Path.file vm
                fun run name=case WindowsChecks.skipped name of SOME row => Test.pending (Expectations.describe row)
                     (job name ["windows-run",#name f,vm,name] []) | NONE =>
                     job name ["windows-run",#name f,vm,name] ["windows/prepare","windows/compile/" ^ #compilerID f ^ "/" ^ name]
                val full=env ("WINDOWS_FILTER","")=""
                val oracles=if not full then [] else
                     List.map (fn name => job ("count/" ^ name) ["windows-count",#name f,vm,name]
                          ["windows/prepare","windows/compile/" ^ #compilerID f ^ "/" ^ name]) WindowsChecks.layoutCases
                     @ [job "image" ["windows-image",#name f,vm] ["windows/prepare","windows/compile/" ^ #compilerID f ^ "/rt.save_restore_cross"]]
            in Test.describe vmName (List.map run names @ [job "refusals" ["windows-refusals",#name f,vm] ["windows/prepare"]] @ oracles) end) (#vms f))
        val tree=Test.describe "windows" (job "prepare" ["windows-prepare"] [] :: compile :: List.map one families)
    in Test.requires ["windows"] (tags ((if selected then ["windows-selected"] else ["test-windows","nightly","windows","vm"])
                   @ ["covers:tests/lang/*","covers:tests/runtime/*","covers:tests/runner/windows*.sml"]) tree) end
end

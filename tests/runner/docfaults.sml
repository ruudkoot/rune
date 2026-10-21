(* Exercise real public check commands in private source trees. Each tree
   changes exactly one input; symlink expansion never edits the source tree. *)
structure DocFaults =
struct
  open Sh
  fun need (name, ok) = if ok then () else say ("FAIL documentation fault: " ^ name ^ "\n")
  fun copyRoot dir =
    (rmTree dir; mkdirs dir; List.app (fn name => Posix.FileSys.symlink {old = fromRoot name, new = dir ^ "/" ^ name})
      (List.filter (fn name => name <> ".git") (entries root)))
  fun override dir relative text =
    let fun parent (dir, []) = dir
          | parent (dir, name :: rest) =
            let val path = dir ^ "/" ^ name
                val () = if OS.FileSys.isLink path then
                  let val original = OS.FileSys.realPath path
                      val names = entries original
                      val () = OS.FileSys.remove path
                      val () = mkdirs path
                  in List.app (fn name => Posix.FileSys.symlink {old = original ^ "/" ^ name, new = path ^ "/" ^ name}) names end
                  else ()
            in parent (path, rest) end
        val parts = String.fields (fn c => c = #"/") relative
        val path = parent (dir, List.take (parts, length parts - 1)) ^ "/" ^ List.last parts
        val () = OS.FileSys.remove path
    in write (path, text) end
  fun one () =
    let val base = run ^ "/doc-faults"
        val payload = fromRoot "bin/rune-doc-check.rbc"
        fun attempt (name, path, text, args) =
          let val dir = base ^ "/" ^ name
              val () = copyRoot dir
              val () = override dir path text
              val () = mkdirs (dir ^ "/work")
              val status = Children.exec {addressSpace = SOME (1024 * 1024 * 1024), cpuTime = SOME 600,
                                         fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
                (setEnv ("RUNE_TEST_ROOT", dir) o setEnv ("RUNE_TEST_RUN", dir ^ "/work"))
                {cmd = fromRoot "bin/runevm" :: payload :: args, dir = SOME dir, stdin = "", stdout = dir ^ "/stdout",
                 stderr = dir ^ "/stderr", timeout = 600}
          in need (name, status = 1 andalso String.isSubstring "FAIL documentation" (read (dir ^ "/stdout"))) end
        val document = read (fromRoot "docs/language.md")
        val feature = valOf (List.find (String.isPrefix "| exp.case ") (lines document))
        val () = attempt ("missing-feature", "docs/language.md", String.concatWith "\n" (List.filter (fn line => line <> feature) (lines document)), ["docs-features"])
        val () = attempt ("duplicate-feature", "docs/language.md", document ^ "\n" ^ feature ^ "\n", ["docs-features"])
        val claims = read (fromRoot "docs/lib/basis/claims.tsv")
        val rows = lines claims
        val () = attempt ("duplicate-claim", "docs/lib/basis/claims.tsv", claims ^ List.nth (rows, 1) ^ "\n", ["docs-claims"])
        val () = attempt ("missing-claim", "docs/lib/basis/claims.tsv", hd rows ^ "\n", ["docs-claims"])
        val () = attempt ("missing-notes", "docs/lib/basis/notes.tsv", String.concatWith "\t" DocChecks.notesHeader ^ "\n", ["docs-notes"])
        val () = attempt ("stale-annotations", "tests/basis/annotations.txt", "stale\n", ["docs-annotations"])
        val () = attempt ("signature-token-drift", "lib/basis/sig_list.sml", "signature LIST = sig type planted = int end\n", ["docs-signatures"])
        val build = read (fromRoot "lib/basis/library.build")
        val () = attempt ("stale-signature-block", "lib/basis/library.build", String.concatWith "\n"
                    (List.filter (fn line => DocChecks.trim line <> "sig_list.sml") (String.fields (fn c => c = #"\n") build)), ["docs-signatures"])
        val () = need ("mutation sample locations", Mutants.sampled 107 2 = [1, 55] andalso Mutants.sampled 0 20 = [])
        val () = need ("surviving mutant", Mutants.classify ["L@S"] "PASS L@S: good\n" = ("SURVIVED", []))
        val () = need ("killed mutant", Mutants.classify ["L@S"] "FAIL L@S: bad\n" = ("KILLED", ["L@S"]))
        fun fake (name, body, timeout, cap) =
          let val dir = base ^ "/child-" ^ name
              val () = mkdirs dir
              val file = dir ^ "/runedoc"
              val () = write (file, "#!/bin/sh\n" ^ body ^ "\n")
              val () = Posix.FileSys.chmod (file, Posix.FileSys.S.flags
                           [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr])
              val command = {program = fromRoot "bin/runevm", args = [fromRoot "bin/runevm", payload, "mutants-prepare"],
                env = setEnv ("RUNEDOC", file) (setEnv ("RUNE_TEST_RUN", dir) (Posix.ProcEnv.environ ())), dir = root,
                stdin = "/dev/null", stdout = dir ^ "/stdout", stderr = dir ^ "/stderr", timeout = Time.fromSeconds timeout,
                cap = cap, cost = 0.0, cpus = 1, memory = 1000, pools = [], exclusive = false, failedLast = false, deps = []} : Supervisor.command
              val result = ref NONE : Supervisor.result option ref
              val () = Supervisor.run {commands = Vector.fromList [command], cpus = 1, memory = 1000,
                           finished = fn (_, r) => (result := SOME r; Supervisor.Passed), tick = fn _ => ()}
          in valOf (!result) end
        val bad = fake ("pass-before-failure", "printf 'PASS fake\\n'; exit 7", 10, 1000000)
        val () = need ("mutation producer PASS before failure", #outcome bad = Supervisor.Exited 1)
        val crash = fake ("crash", "kill -SEGV $$", 10, 1000000)
        val () = need ("mutation producer crash", #outcome crash = Supervisor.Exited 1)
        val loop = fake ("loop", "exec sleep 30", 1, 1000000)
        val () = need ("mutation producer loop", #outcome loop = Supervisor.TimedOut)
        val flood = fake ("flood", "exec yes FLOOD", 10, 10000)
        val () = need ("mutation producer flood", case #outcome flood of Supervisor.Exited 1 => true
                          | Supervisor.Capped => true | Supervisor.Signalled _ => true | _ => false)
        val leak = fake ("leak", "sleep 30 &\nexit 7", 10, 1000000)
        val () = need ("mutation producer descendant", #leaked leak)
    in () end
end

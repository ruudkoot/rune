(* Deliberate disagreements exercise the real cache oracle and public corpus
   controller. Fake compilers/VMs are process fixtures, never verdict logic. *)
structure IncrementalFaults =
struct
  open Sh
  fun need (ok,why) = if ok then () else raise Fail why
  fun executable file body =
    (write (file,"#!/bin/sh\n" ^ body ^ "\n"); Posix.FileSys.chmod (file,
       Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr]))
  fun captured file action =
    let val () = TextIO.flushOut TextIO.stdOut
        val saved = Posix.IO.dup Posix.FileSys.stdout
        val output = Posix.FileSys.creat (file,Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr])
        val () = (Posix.IO.dup2 {old=output,new=Posix.FileSys.stdout}; Posix.IO.close output)
        fun restore () = (TextIO.flushOut TextIO.stdOut; Posix.IO.dup2 {old=saved,new=Posix.FileSys.stdout}; Posix.IO.close saved)
    in (action () before restore ()) handle e => (restore (); raise e) end
  fun one () =
    let val dir = run ^ "/incremental-faults"
        val () = (rmTree dir; mkdirs dir)
        fun cacheCase name body fail =
          let val compiler = dir ^ "/" ^ name
              val () = executable compiler body
              val checker = MutationChecks.create compiler (dir ^ "/" ^ name ^ "-receipts") []
              val project = MutationProject.create compiler (dir ^ "/" ^ name ^ "-work") [("a.sml","val a = 1\n")] []
              val _ = captured (dir ^ "/" ^ name ^ ".out") (fn () => MutationChecks.check checker project ["planted " ^ name])
          in need ((!(#failures checker) > 0) = fail,"cache oracle misclassified " ^ name) end
        val parse = "cached=0; output=''\nwhile [ $# -gt 0 ]; do case $1 in --cache-dir) cached=1; shift 2 ;; -o) output=$2; shift 2 ;; *) shift ;; esac; done\n"
        val () = cacheCase "different-bytes" (parse ^ "if [ $cached -eq 1 ]; then printf stale; else printf fresh; fi > \"$output\"") true
        val () = cacheCase "status-disagreement" (parse ^ "if [ $cached -eq 1 ]; then printf bad > \"$output\"; else exit 1; fi") true
        val () = cacheCase "no-payload" "exit 0" true
        val () = cacheCase "ordinary-rejected-program" "exit 1" false
        val corrupt = dir ^ "/bad-entry"
        val () = CachePlant.writeBinary corrupt "RCE\128"
        val () = need (((CachePlant.parse corrupt; false) handle CachePlant.Invalid _ => true),"truncated corruption input was accepted")
        val () = need (((Incremental.replace "abc" "missing" "new"; false) handle Incremental.Failed _ => true),"stale edit marker was silently ignored")
        val () = mkdirs (dir ^ "/corpus")
        val () = write (dir ^ "/corpus/fib.sml","structure Main = struct fun doit _ = () end\n")
        val () = mkdirs (dir ^ "/corpus/DATA")
        val compiler = dir ^ "/compiler"
        val () = executable compiler (parse ^ "printf payload > \"$output\"")
        val vm = dir ^ "/vm"
        val () = executable vm "printf 'runevm: count: 1 instructions, 7 bytes, 8 objects\\n' >&2"
        val table = dir ^ "/counts.txt"
        val () = write (table,"# preserved comment\nfib 1 0 0 # deliberate expectation\n")
        val c = Scenarios.create "incremental-fault-cli" compiler
        val () = Scenarios.reset c
        fun public label flags = Scenarios.execute c label root
             ([fromRoot "bin/rune-external","benchmark","--dir",dir ^ "/corpus","--out",dir ^ "/external-" ^ label,
               "--table",table,"--rune",compiler,"--vm",vm,"-j","1"] @ flags)
        val result = public "wrong-count" []
        val () = need (#status result <> 0 andalso String.isSubstring "COUNT fib:" (#output result),"wrong external allocation count passed")
        val result = public "prepare" ["--prepare"]
        val () = need (#status result = 0 andalso String.isSubstring "PREPARED fib" (#output result),"external prepare did not stop before execution")
        val result = public "update" ["--update"]
        val () = need (#status result = 0 andalso read table = "# preserved comment\nfib 1 7 8 # deliberate expectation\n","explicit count update lost metadata or did not rewrite counts")
        val () = executable vm "sleep 30"
        val result = public "timeout" ["--timeout","1"]
        val () = need (#status result <> 0 andalso String.isSubstring "TIMEOUT fib:" (#output result),"external timeout passed")
        val result = Scenarios.execute c "missing-input" root [fromRoot "bin/rune-external","regression",dir ^ "/missing"]
        val () = need (#status result <> 0,"missing external corpus was treated as unavailable or passed")
    in say "PASS incremental and external boundary faults\n" end
end

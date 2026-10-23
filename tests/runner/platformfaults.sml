(* False success and unavailable targets are exercised through the actual
   SML entrypoints; process fixtures and all resulting files stay private. *)
structure PlatformFaults =
struct
  open Sh
  fun need (ok,why)=if ok then () else raise Fail ("platform fault: " ^ why)
  fun executable file text=(write (file,"#!/bin/sh\n" ^ text ^ "\n");Posix.FileSys.chmod (file,
             Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr]))
  fun staging () =
    let val dir=run ^ "/oracle-staging"
        val ()=mkdirs dir
        val vm=dir ^ "/counter"
        val ()=executable vm "printf 'runevm: count: ' >&2\ncat prog.rbc >&2"
        val a=dir ^ "/a.rbc" val b=dir ^ "/b.rbc"
        val ()=(write (a,"A\n");write (b,"B\n"))
        fun scenario label count =
          let val shared=dir ^ "/" ^ label ^ "/shared"
              val reference=dir ^ "/" ^ label ^ "/reference"
              val ()=(mkdirs shared;mkdirs reference)
              val entered=ref false
              fun endpoint name directory environment : VMOracles.endpoint =
                {name=name,program=vm,directory=directory,windows=false,options=[],environment=environment}
              fun interleave env =
                (entered:=true;count (dir ^ "/" ^ label ^ "/inner") b [] [endpoint "inner" shared (fn e => e)];env)
              val ()=count (dir ^ "/" ^ label ^ "/outer") a []
                [endpoint "racing" shared interleave,endpoint "reference" reference (fn e => e)]
          in need (!entered,"staging interleave was not exercised") end
        val rejected=(scenario "shared-control" (VMOracles.countWith (fn endpoint => endpoint));false)
          handle VMOracles.Failed message => String.isSubstring "VM counts differ" message
        val ()=need (rejected,"shared staging planted fault was not detected")
        val ()=scenario "isolated" VMOracles.count
    in say "PASS interleaved VM oracle staging and shared-directory planted fault\n" end
  fun one () =
    let val dir=run ^ "/platform-faults"
        val ()=mkdirs dir
        val compiler=dir ^ "/compiler with spaces"
        val ()=executable compiler "output=''; while [ $# -gt 0 ]; do case $1 in -o) output=$2; shift 2 ;; *) shift ;; esac; done\nprintf fixture > \"$output\""
        val vm=dir ^ "/vm with spaces"
        val expected=read (fromRoot "tests/lang/dec.val_simple.expected")
        fun execute label changes args =
          let val status=Children.exec {addressSpace=NONE,cpuTime=SOME 60,fileSize=SOME (8*1024*1024),core=SOME 0}
                    (List.foldl (fn ((name,value),f) => setEnv (name,value) o f) (fn e => e) changes)
                    {cmd=args,dir=SOME root,stdin="",stdout=dir ^ "/" ^ label ^ ".out",stderr=dir ^ "/" ^ label ^ ".err",timeout=60}
          in (status,read (dir ^ "/" ^ label ^ ".out"),read (dir ^ "/" ^ label ^ ".err")) end
        val ()=executable vm "printf 'planted wrong answer\\n'"
        val (status,out,_)=execute "wrong-output" []
               [fromRoot "bin/rune-suite","--rune",compiler,"--vm",vm,"--one","tests/lang/dec.val_simple.sml","--out",dir ^ "/wrong-output-run","-j","1"]
        val ()=need (status<>0 andalso String.isSubstring "stdout differs" out,"a zero exit with a wrong answer passed")
        val ()=executable vm ("printf '%s' " ^ quote expected ^ "\nkill -SEGV $$")
        val (status,out,_)=execute "crash-after-answer" []
               [fromRoot "bin/rune-suite","--rune",compiler,"--vm",vm,"--one","tests/lang/dec.val_simple.sml","--out",dir ^ "/crash-run","-j","1"]
        val ()=need (status<>0 andalso String.isSubstring "CRASH" out,"correct output before a crash passed")
        val (status,out,_)=execute "missing-vm" []
               [fromRoot "bin/rune-windows","--vm",dir ^ "/missing.exe","-j","1","dec.val_simple"]
        val ()=need (status<>0 andalso String.isSubstring "Windows VM is missing" out,"unavailable Windows target passed")
        val override=dir ^ "/directory with spaces"
        val (status,out,_)=execute "override-directory" [("RUNE_WINDOWS_DIR",override)] [fromRoot "bin/rune-windows","directory"]
        val ()=need (status=0 andalso Hosts.trim out=override andalso isDir override,"explicit Windows directory with spaces changed")
        val fixture=dir ^ "/expectations.txt"
        val ()=write (fixture,"* | first | UNSUPPORTED | deliberate reason\nother | second | HOST-ABSENT | a host reason\n* | third | HOST-BUG | still runs\n")
        val (status,out,_)=execute "skip-reader" [] [fromRoot "bin/rune-suite","skip","--reasons",fixture]
        val ()=need (status=0 andalso out="first deliberate reason\nsecond a host reason\n","shared skip categories/reasons changed")
        val (status,out,_)=execute "skip-way" [] [fromRoot "bin/rune-suite","skip",fixture,"local"]
        val ()=need (status=0 andalso out="first\n","skip way filtering changed")
    in say "PASS platform fixture, crash, unavailable-target, path and skip-reader faults\n" end
end

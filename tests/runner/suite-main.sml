(* Compatibility entry for the retired run-tests/skipped shell readers.
   Scheduling, fixture verdicts and explicit updates use the existing runner. *)
structure SuiteMain =
struct
  open Sh
  fun skip args =
    let val (reasons,args)=case args of "--reasons" :: args => (true,args) | _ => (false,args)
        val (file,way)=case args of [file] => (file,"") | [file,way] => (file,way) | _ => raise Fail "skip [--reasons] FILE [WAY]"
        val rows=Expectations.read (fromRoot file)
        val rows=List.filter (fn row : Expectations.line => List.exists (fn category => category= #category row)
                  ["HOST-ABSENT","XC1-NA","XC2-NA","UNTESTED","UNSUPPORTED"] andalso (way="" orelse Expectations.glob (#way row,way))) rows
    in List.app (fn row : Expectations.line => say (#path row ^ (if reasons then " " ^ #reason row else "") ^ "\n")) rows end
  fun main ("skip" :: args)=skip args
    | main args =
      let val compiler=ref (fromRoot "bin/rune-stack")
          val vm=ref (fromRoot "bin/runevm-stack")
          val out=ref (fromRoot "tests/out/suite")
          val jobs=ref (Int.toString (Runtime.processors ()))
          val filter=ref ""
          val one=ref ""
          val skip=ref ""
          val update=ref false
          fun parse []=()
            | parse ("--rune" :: value :: rest)=(compiler:=fromRoot value;parse rest)
            | parse ("--vm" :: value :: rest)=(vm:=fromRoot value;parse rest)
            | parse ("--out" :: value :: rest)=(out:=fromRoot value;parse rest)
            | parse ("--skip" :: value :: rest)=(skip:=fromRoot value;parse rest)
            | parse ("--one" :: value :: rest)=(one:=value;parse rest)
            | parse ("--update" :: rest)=(update:=true;parse rest)
            | parse ("-j" :: value :: rest)=(jobs:=value;parse rest)
            | parse (arg :: rest)=if String.isPrefix "-" arg then raise Fail ("unknown/incomplete suite option " ^ arg) else (filter:=arg;parse rest)
          val ()=parse args
          val kind=if String.isSubstring "errors/" (!one) then "errors" else if !one="" then "" else "lang"
          val name=if !one="" then "" else OS.Path.base (OS.Path.file (!one))
          val sources=glob (fromRoot "tests/lang",".sml") @ glob (fromRoot "tests/errors",".sml")
          val matches=List.filter (fn path => String.isSubstring (!filter) (basename path)
                  andalso (name="" orelse (basename path=name andalso String.isSubstring ("/" ^ kind ^ "/") path))) sources
          val ()=if null matches then raise Fail "suite selection has no matching fixtures" else ()
          val changes=[("RUNE_SUITE_COMPILER",!compiler),("RUNE_SUITE_VM",!vm),("RUNE_SUITE_FILTER",!filter),
                       ("RUNE_SUITE_ONE",name),("RUNE_SUITE_KIND",kind),("RUNE_SUITE_SKIP",!skip),("RUNE_SUITE_UPDATE",if !update then "1" else "0")]
          val environment=List.foldl (fn ((name,value),environment) => setEnv (name,value) environment) (Posix.ProcEnv.environ ()) changes
          val program=fromRoot "bin/runevm"
      in Posix.Process.exece (program,[program,fromRoot "bin/rune-test.rbc","run","--strict","--keep","--tier","suite-selected","--out",!out,"-j",!jobs]
                   @ (if !update then ["--accept"] else []),environment) end
end
val ()=(SuiteMain.main (CommandLine.arguments ()) handle e => (Sh.say ("FAIL suite: " ^ General.exnMessage e ^ "\n");Posix.Process.exit 0w2))

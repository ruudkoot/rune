structure TerminalMain =
struct
  open Sh
  fun probe () =
    let val windows=List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
        val shell=if windows then valOf (OS.Process.getEnv "COMSPEC") else "/bin/sh"
        val args=if windows then [shell,"/d","/c","exit 0"] else [shell,"-c","exit 0"]
        val s=Pty.spawn {program=shell,args=args,env=NONE,dir=NONE,columns=80,rows=24}
        val ()=Pty.resize (s,{columns=81,rows=25})
        val status=Subprocess.wait (SOME (Pty.process s))
        val ()=Pty.close s
    in TerminalChecks.need (#status status=Posix.Process.W_EXITED,"PTY capability child failed");say "PTY available\n" end
  fun resolve name =if String.isSubstring "/" name orelse String.isSubstring "\\" name then name else
    let val paths=String.fields (fn c => c = #":") (env ("PATH",""))
        val candidates=List.map (fn p => OS.Path.concat (p,name)) paths
    in case List.find (fn p => OS.FileSys.access (p,[OS.FileSys.A_EXEC]) andalso not (isDir p) handle OS.SysErr _ => false) candidates of
          SOME path => OS.FileSys.fullPath path | NONE => raise Fail ("terminal executable is unavailable: " ^ name) end
  fun main ["probe"]=probe ()
    | main ["prepare"]=TerminalChecks.prepare ()
    | main ["one",name]=TerminalChecks.one false name ()
    | main ["raw-one",name]=TerminalRaw.one name ()
    | main ["native-one",name]=TerminalChecks.one true name ()
    | main ["windows-prepare"]=TerminalPlatform.prepare ()
    | main ["windows-one",bits,name]=TerminalPlatform.one bits name ()
    | main ["windows-cmd",bits]=TerminalPlatform.cmd bits ()
    | main ["faults"]=TerminalFaults.one ()
    | main ["races"]=TerminalRaces.one ()
    | main ["display"]=TerminalDisplay.one ()
    | main ("raw" :: columns :: rows :: file :: "--" :: program :: args)=
       let fun integer text=case Int.fromString text of SOME n => n | NONE => raise Fail "invalid terminal dimension"
       in TerminalRaw.run {columns=integer columns,rows=integer rows,file=fromRoot file,args=resolve program :: args,
                 environment=Posix.ProcEnv.environ (),directory=root,output=run ^ "/terminal/raw-custom/trace"} () end
    | main args =
       let val windows=ref false val filter=ref "" val jobs=ref (Int.toString (Runtime.processors ()))
           fun parse []=() | parse ("--windows"::rest)=(windows:=true;parse rest)
             | parse ("-j"::n::rest)=(jobs:=n;parse rest)
             | parse (arg::rest)=if String.isPrefix "-" arg then raise Fail ("unknown terminal option: " ^ arg) else (filter:=arg;parse rest)
           val ()=parse args
           val files=glob (fromRoot "tests/terminal",".script") @
                     (if !windows then [] else glob (fromRoot "tests/terminal",".pty"))
           val selected=List.filter (fn file => String.isSubstring (!filter) (OS.Path.base (OS.Path.file file))
                         andalso (not (!windows) orelse firstLine file="# windows")) files
           val ()=TerminalChecks.need (not (null selected),"terminal selection has no matching scenarios")
           val vm=fromRoot "bin/runevm"
           val filter=if !windows then "terminal/windows-*/*" ^ !filter ^ "*" else "terminal/*" ^ !filter ^ "*"
       in Posix.Process.exece (vm,[vm,fromRoot "bin/rune-test.rbc","run",filter,"--tier",if !windows then "test-windows" else "test-terminal","-j",!jobs],Posix.ProcEnv.environ ()) end
end
val ()=(TerminalMain.main (CommandLine.arguments ()) handle e =>
      (Sh.say ("FAIL terminal: " ^ (case e of TerminalChecks.Failed text => text | TerminalRaw.Failed text => text | TerminalIO.Failed text => text
                      | TerminalPattern.Pattern text => text | Fail text => text | _ => General.exnMessage e) ^ "\n");Posix.Process.exit 0w1))

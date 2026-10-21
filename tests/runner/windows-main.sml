structure WindowsMain =
struct
  open Sh
  fun refusals args =
    let val vm=ref "bin/runevm-stack"
        val defs=ref "runtime/stack/opcodes.def"
        val directory=ref (fromRoot "tests/out/vm")
        fun parse []=() | parse ("--vm" :: value :: rest)=(vm:=value;parse rest)
          | parse ("--def" :: value :: rest)=(defs:=value;parse rest)
          | parse ("--out" :: value :: rest)=(directory:=fromRoot value;parse rest)
          | parse _=raise Fail "vm [--vm BIN] [--def FILE] [--out DIR]"
        val ()=parse args
    in VMChecks.run {vm= !vm,defs= !defs,directory= !directory,logs= !directory} end
  fun main ("vm" :: args)=refusals args
    | main ["directory"]=say (WindowsDir.directory () ^ "\n")
    | main args =
      let val changes=ref [("WINDOWS_SELECTED","1")]
          val vms=ref []
          val filter=ref ""
          val jobs=ref (Int.toString (Runtime.processors ()))
          fun set key value=changes:=(key,value) :: !changes
          fun parse []=()
            | parse ("--rune" :: value :: rest)=(set "WINDOWS_RUNE" (fromRoot value);parse rest)
            | parse ("--vm" :: value :: rest)=(vms:= !vms @ [fromRoot value];parse rest)
            | parse ("--native" :: value :: rest)=(set "WINDOWS_NATIVE" (fromRoot value);parse rest)
            | parse ("--def" :: value :: rest)=(set "WINDOWS_DEF" value;parse rest)
            | parse ("-j" :: value :: rest)=(jobs:=value;parse rest)
            | parse (arg :: rest)=if String.isPrefix "-" arg then raise Fail ("unknown/incomplete Windows option " ^ arg)
                                 else (filter:=arg;parse rest)
          val ()=parse args
          val ()=List.app (fn vm => if OS.FileSys.access (vm,[OS.FileSys.A_EXEC]) then ()
                        else raise Fail ("Windows VM is missing: " ^ vm)) (!vms)
          val ()=if null (!vms) then () else set "WINDOWS_VMS" (String.concatWith "\n" (!vms))
          val ()=set "WINDOWS_FILTER" (!filter)
          val environment=List.foldr (fn ((name,value),environment) => setEnv (name,value) environment) (Posix.ProcEnv.environ ()) (!changes)
          val vm=fromRoot "bin/runevm"
      in Posix.Process.exece (vm,[vm,fromRoot "bin/rune-test.rbc","run","--strict","--tier","windows-selected","-j",!jobs],environment) end
end
val ()=((case WindowsJobs.command (CommandLine.arguments ()) of SOME action => action () | NONE => WindowsMain.main (CommandLine.arguments ()))
        handle e => (Sh.say ("FAIL Windows controller: " ^ WindowsJobs.failure e ^ "\n");Posix.Process.exit 0w1))

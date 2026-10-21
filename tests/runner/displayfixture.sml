(* A real runner drawing progress and a failure. The terminal tests capture
   its bytes and frames; child modes are bounded deterministic processes. *)
structure DisplayFixture =
struct
  fun env (key,fallback)=getOpt (OS.Process.getEnv key,fallback)
  fun job name =
    let val vm=env ("DISPLAY_VM","bin/runevm")
        val payload=env ("DISPLAY_PAYLOAD","tests/out/display.rbc")
    in Test.it name {program=vm,args=[vm,payload,"job",name],env=NONE,dir=SOME (OS.FileSys.getDir ()),stdin=NONE,
          timeout=Time.fromSeconds 10,cap=4096,cpus=1,memory=200,pools=[],exclusive=false,after=[],judge=Run.exitZero} end
  fun main ["job",name]=(OS.Process.sleep (Time.fromMilliseconds (if name="passes" then 500 else 1500));
                          OS.Process.exit (if name="passes" then OS.Process.success else OS.Process.failure))
    | main _=Cli.main (Test.describe "display" [job "passes",job "fails"])
end
val ()=DisplayFixture.main (CommandLine.arguments ())

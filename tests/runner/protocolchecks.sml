(* Protocol launchers own lifecycle, staging and independent-peer execution.
   Test policy stays in SML; Python here is only an external interop peer. *)
structure ProtocolChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok,why)=if ok then () else raise Failed why
  fun copy source target =
    let val ()=mkdirs (OS.Path.dir target)
        val input=BinIO.openIn source
        val output=BinIO.openOut target
        fun loop ()=let val bytes=BinIO.inputN (input,65536) in if Word8Vector.length bytes=0 then () else (BinIO.output (output,bytes);loop ()) end
        val ()=(loop () handle e => (BinIO.closeIn input;BinIO.closeOut output;raise e))
    in BinIO.closeIn input;BinIO.closeOut output end
  fun launch directory name args environment =
    let val ()=mkdirs directory
        val file=directory ^ "/" ^ name ^ ".out"
        val out=Posix.FileSys.creat (file,Posix.FileSys.S.irwxu)
        val fd=SysWord.toInt (Posix.FileSys.fdToWord out)
        val pid=(Subprocess.spawn {program=hd args,args=args,env=SOME environment,search=not (String.isSubstring "/" (hd args)),dir=SOME root,
             stdin=NONE,stdout=SOME fd,stderr=SOME fd,group=false,limits=Subprocess.unlimited} handle e => (Posix.IO.close out;raise e))
    in Posix.IO.close out;(pid,file) end
  fun kill pid=Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)),Posix.Signal.kill)
  fun reap pid=(kill pid handle OS.SysErr _ => ();ignore (Subprocess.wait (SOME pid)) handle OS.SysErr _ => ())
  fun wait (pid,file) seconds =
    let val deadline=Time.+ (Runtime.clock (),Time.fromSeconds seconds)
        fun loop ()=case Subprocess.poll (SOME pid) of SOME ended =>
                   need (#status ended=Posix.Process.W_EXITED,"protocol child failed: " ^ file ^ "\n" ^ read file)
             | NONE => if Time.>= (Runtime.clock (),deadline) then (reap pid;raise Failed ("protocol child timed out: " ^ file))
                       else (OS.Process.sleep (Time.fromMilliseconds 10);loop ())
    in loop () end
  fun environment ()=setEnv ("RUNE_CACHE","") (Posix.ProcEnv.environ ())
  fun kernelWith windows inhibitInterrupt () =
    let val directory=run ^ "/kernel"
        val (file,connection)=KernelChecks.connection directory "a-kernel-key"
        val event=if windows then RuneRuntime.interruptEvent () else ~1
        val ()=need (not windows orelse event>=0,"Windows interrupt event could not be created")
        val env=if windows then setEnv ("JPY_INTERRUPT_EVENT",Int.toString event) (unsetEnv ["RUNE_INTERRUPT_EVENT"] (environment ())) else environment ()
        val args=if windows then [fromRoot "bin/runevm.exe",fromRoot "bin/rune-kernel.rbc","--vm",fromRoot "bin/runevm.exe",
                    "--image",fromRoot "bin/rune-repl.img","--program",fromRoot "bin/rune-kernel.rbc",file]
                 else [fromRoot "bin/rune-kernel",file]
        val child as (pid,_)=launch directory "kernel" args env
        fun interrupt ()=if windows then need (RuneRuntime.setInterrupt event,"Windows interrupt event was lost")
              else Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)),Posix.Signal.int)
        val ()=(KernelChecks.client connection {interrupt=if inhibitInterrupt then (fn () => ()) else interrupt,cleanup=interrupt} ()
                handle e => ((wait child 5 handle Failed _ => ());raise e))
    in wait child 60 end
  fun kernel windows=kernelWith windows false
  fun notebook () =
    let val directory=run ^ "/notebook-peer"
        val probe=Children.exec Subprocess.unlimited (fn e => e)
             {cmd=["python3","-c","import jupyter_client"],dir=SOME root,stdin="",stdout=run ^ "/notebook-probe.out",stderr=run ^ "/notebook-probe.err",timeout=30}
    in if probe<>0 then say "SKIP independent jupyter_client peer: module unavailable\n" else
         let val child=launch directory "notebook" ["python3",fromRoot "tests/kernel/notebook_client.py"] (environment ())
             val ()=wait child 240
         in say (read (#2 child)) end end
  fun interop library compiler vm directory () =
    let val ()=need (library="zmtp" orelse library="jupyter","unknown protocol interoperability peer")
        val ()=mkdirs directory
        val source=fromRoot ("tests/lib/" ^ library ^ "/interop/" ^ (if library="zmtp" then "server.sml" else "kernel.sml"))
        val payload=directory ^ "/" ^ library ^ ".rbc"
        val status=Children.exec Subprocess.unlimited (fn e => e)
             {cmd=[compiler,"--library",library,source,"-o",payload],dir=SOME root,stdin="",stdout=directory ^ "/compile.out",stderr=directory ^ "/compile.err",timeout=120}
        val ()=need (status=0,"interop peer compilation failed: " ^ read (directory ^ "/compile.err"))
        val endpoint=if library="zmtp" then directory ^ "/ports" else #1 (KernelChecks.connection directory "a-secret-key")
        val ()=if library="zmtp" then rmTree endpoint else ()
        val child as (pid,file)=launch directory "server" [vm,payload,endpoint] (environment ())
        fun peer ()=
          let val ()=if library="jupyter" then OS.Process.sleep (Time.fromSeconds 1) else ()
              val peer=launch directory "peer" ["python3",fromRoot ("tests/lib/" ^ library ^ "/interop/" ^ (if library="zmtp" then "peer.py" else "client.py")),endpoint] (environment ())
              val ()=(wait peer 60 handle e => (reap (#1 peer);raise e))
              val ()=wait child 60
              val ()=if library="zmtp" then need (String.isSubstring "server: done" (read file),"ZMTP server did not finish") else ()
          in say (read file);say (read (#2 peer)) end
    in peer () handle e => (reap pid;raise e) end
  fun windows suite () =
    let val ()=need (suite="dap" orelse suite="kernel","unknown Windows protocol suite")
        val stage=WindowsDir.directory () ^ "/protocol-" ^ suite ^ "-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
        val ()=mkdirs (stage ^ "/bin")
        val files=["runevm.exe","rune-repl.img","rune-" ^ suite ^ ".rbc","rune-protocol-check.rbc"]
                 @ List.filter (String.isSuffix ".dll") (entries (fromRoot "bin"))
        val ()=List.app (fn name => copy (if name="runevm.exe" then fromRoot (env ("PROTOCOL_WINDOWS_VM","bin/runevm.exe"))
                                          else fromRoot ("bin/" ^ name)) (stage ^ "/bin/" ^ name)) files
        val ()=if suite="dap" then List.app (fn name => copy (fromRoot ("tests/dap/" ^ name)) (stage ^ "/tests/dap/" ^ name)) ["prog.sml","loop.sml"] else ()
        val env=setEnv ("WSLENV","RUNE_TEST_ROOT:RUNE_TEST_RUN:" ^ env ("WSLENV",""))
                    (setEnv ("RUNE_TEST_ROOT",".") (setEnv ("RUNE_TEST_RUN","tests/out/protocol") (environment ())))
        val status=Children.exec Subprocess.unlimited (fn _ => env)
             {cmd=[stage ^ "/bin/runevm.exe","bin/rune-protocol-check.rbc",suite ^ "-native"],dir=SOME stage,stdin="",
              stdout=run ^ "/windows-" ^ suite ^ ".out",stderr=run ^ "/windows-" ^ suite ^ ".err",timeout=300}
    in say (read (run ^ "/windows-" ^ suite ^ ".out"));need (status=0,"Windows protocol suite failed: " ^ read (run ^ "/windows-" ^ suite ^ ".err")) end
  fun dap windows () =
    DapChecks.one (if windows then [fromRoot "bin/runevm.exe",fromRoot "bin/rune-dap.rbc","--vm",fromRoot "bin/runevm.exe","--image",fromRoot "bin/rune-repl.img"]
                        else [fromRoot "bin/rune-dap"]) root ()
end

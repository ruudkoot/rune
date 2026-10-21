(* Rune host boundary for the same pure build/package models. *)
structure BuildIO : BUILD_IO =
struct
  exception Interrupted
  exception TimedOut of string list * real
  fun initialize ()=ignore (Runtime.catchInterrupt ())
  fun code status=case status of Posix.Process.W_EXITED => 0 | Posix.Process.W_EXITSTATUS n => Word8.toInt n
       | Posix.Process.W_SIGNALED s => 128+SysWord.toInt (Posix.Signal.toWord s) | _ => 1
  fun execute {args,directory,input,output,errors,environment,timeout} =
    let fun executable name =
          if String.isSubstring "/" name orelse String.isSubstring "\\" name then OS.Path.mkAbsolute {path=name,relativeTo=directory}
          else let val windows=List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
                   val separator=if windows then #";" else #":"
                   val path=case List.find (String.isPrefix "PATH=") environment of SOME value => String.extract (value,5,NONE) | NONE => ""
                   val candidates=List.concat (List.map (fn dir => let val file=OS.Path.concat (if dir="" then directory else dir,name) in if windows then [file,file ^ ".exe"] else [file] end) (String.fields (fn c => c=separator) path))
               in case List.find (fn file => OS.FileSys.access (file,[OS.FileSys.A_EXEC]) andalso not (OS.FileSys.isDir file) handle OS.SysErr _ => false) candidates of SOME file => file | NONE => name end
        val program=executable (hd args)
        val ()=if (OS.FileSys.access (program,[OS.FileSys.A_EXEC]) andalso not (OS.FileSys.isDir program) handle OS.SysErr _ => false) then () else raise OS.SysErr ("cannot execute " ^ hd args,SOME Posix.Error.noent)
        val timer=Runtime.clock ()
        val mode=Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.irgrp,Posix.FileSys.S.iroth]
        val infd=Posix.FileSys.openf (if input="" then "/dev/null" else input,Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
        val outfd=Posix.FileSys.creat (output,mode) val errfd=if errors=output then outfd else Posix.FileSys.creat (errors,mode)
        fun close ()=(Posix.IO.close infd;Posix.IO.close outfd;if errors=output then () else Posix.IO.close errfd)
        fun fd d=SysWord.toInt (Posix.FileSys.fdToWord d)
        val grouped=not (isSome (OS.Process.getEnv "RUNE_TEST_RUN") andalso isSome (OS.Process.getEnv "RUNE_TEST_CPUS"))
        val pid=(Subprocess.spawn {program=program,args=args,env=SOME environment,search=not (String.isSubstring "/" (hd args) orelse String.isSubstring "\\" (hd args)),dir=SOME directory,
                   stdin=SOME (fd infd),stdout=SOME (fd outfd),stderr=SOME (fd errfd),group=grouped,limits={addressSpace=NONE,cpuTime=NONE,fileSize=NONE,core=SOME 0}} handle e => (close ();raise e))
        val ()=close ()
        fun kill signal=if grouped then Subprocess.kill (pid,signal) else Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)),signal)
        fun terminate ()=(kill Posix.Signal.kill handle OS.SysErr _ => ())
        fun reap ()=ignore (Subprocess.wait (SOME pid)) handle OS.SysErr _ => ()
        fun wait ()=case Subprocess.poll (SOME pid) of SOME result => code (#status result) | NONE =>
               if timeout>0.0 andalso Time.toReal (Time.- (Runtime.clock (),timer))>=timeout then (terminate ();reap ();raise TimedOut (args,timeout)) else (OS.Process.sleep (Time.fromMilliseconds 5);wait ())
        val status=(wait () handle SML90.Interrupt => (terminate ();reap ();raise Interrupted) | e => (terminate ();reap ();raise e))
        val leaked=grouped andalso ((kill (Posix.Signal.fromWord (SysWord.fromInt 0));true) handle OS.SysErr _ => false)
        val ()=if leaked then terminate () else ()
    in {status=if leaked andalso status=0 then 125 else status,seconds=Time.toReal (Time.- (Runtime.clock (),timer))} end
end

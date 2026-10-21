(* The bootstrap adapter uses the installed native MLton and POSIX process
   control. It requires no Rune executable, runtime, images or GMP configuration. *)
structure BuildIO : BUILD_IO =
struct
  exception Interrupted
  exception TimedOut of string list * real
  val interrupted=ref false
  fun initialize ()=
    let val handler=MLton.Signal.Handler.simple (fn () => interrupted:=true)
    in MLton.Signal.setHandler (Posix.Signal.int,handler);MLton.Signal.setHandler (Posix.Signal.term,handler) end
  fun code status=case status of Posix.Process.W_EXITED => 0 | Posix.Process.W_EXITSTATUS n => Word8.toInt n
       | Posix.Process.W_SIGNALED s => 128+SysWord.toInt (Posix.Signal.toWord s) | Posix.Process.W_STOPPED s => 128+SysWord.toInt (Posix.Signal.toWord s)
  fun execute {args,directory,input,output,errors,environment,timeout} =
    let val ()=if null args then raise Fail "empty build command" else ()
        val ()=if !interrupted then raise Interrupted else ()
        val timer=Timer.startRealTimer ()
        val mode=Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.irgrp,Posix.FileSys.S.iroth]
        val infd=Posix.FileSys.openf (if input="" then "/dev/null" else input,Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
        val outfd=Posix.FileSys.creat (output,mode)
        val errfd=if errors=output then outfd else Posix.FileSys.creat (errors,mode)
        fun close ()=(Posix.IO.close infd;Posix.IO.close outfd;if errors=output then () else Posix.IO.close errfd)
        fun env key =case List.find (fn entry => String.isPrefix (key ^ "=") entry) environment of NONE => "" | SOME entry => String.extract (entry,size key+1,NONE)
        fun executable name=if String.isSubstring "/" name then if OS.Path.isAbsolute name then name else OS.Path.mkAbsolute {path=name,relativeTo=directory}
              else let val candidates=List.map (fn dir => OS.Path.concat (if dir="" then directory else dir,name)) (String.fields (fn c => c = #":") (env "PATH"))
                   in case List.find (fn file => OS.FileSys.access (file,[OS.FileSys.A_EXEC]) handle OS.SysErr _ => false) candidates of SOME file => file | NONE => name end
        val program=executable (hd args)
        val ()=if (OS.FileSys.access (program,[OS.FileSys.A_EXEC]) andalso not (OS.FileSys.isDir program) handle OS.SysErr _ => false) then () else
             (close ();raise OS.SysErr ("cannot execute " ^ hd args,SOME (if (OS.FileSys.access (program,[]) handle OS.SysErr _ => false) then Posix.Error.acces else Posix.Error.noent)))
        val ()=(TextIO.flushOut TextIO.stdOut;TextIO.flushOut TextIO.stdErr)
        val pid=case Posix.Process.fork () of SOME pid => pid | NONE =>
            ((ignore (Posix.ProcEnv.setsid ());
              List.app (fn signal => MLton.Signal.setHandler (signal,MLton.Signal.Handler.default)) [Posix.Signal.int,Posix.Signal.term,Posix.Signal.pipe];
              Posix.IO.dup2 {old=infd,new=Posix.FileSys.wordToFD (SysWord.fromInt 0)};
              Posix.IO.dup2 {old=outfd,new=Posix.FileSys.wordToFD (SysWord.fromInt 1)};
              Posix.IO.dup2 {old=errfd,new=Posix.FileSys.wordToFD (SysWord.fromInt 2)};
              close ();OS.FileSys.chDir directory;Posix.Process.exece (program,args,environment))
             handle _ => Posix.Process.exit 0w127)
        val ()=close ()
        fun terminate ()=
          ((Posix.Process.kill (Posix.Process.K_GROUP pid,Posix.Signal.kill) handle OS.SysErr _ => ());
           (Posix.Process.kill (Posix.Process.K_PROC pid,Posix.Signal.kill) handle OS.SysErr _ => ()))
        fun reap ()=ignore (Posix.Process.waitpid (Posix.Process.W_CHILD pid,[])) handle OS.SysErr _ => ()
        fun wait ()=case Posix.Process.waitpid_nh (Posix.Process.W_CHILD pid,[]) of SOME (_,status) => code status | NONE =>
             if !interrupted then (terminate ();reap ();raise Interrupted)
             else if timeout>0.0 andalso Time.toReal (Timer.checkRealTimer timer)>=timeout then (terminate ();reap ();raise TimedOut (args,timeout))
             else (OS.Process.sleep (Time.fromMilliseconds 5);wait ())
        val status=(wait () handle e => (terminate ();reap ();raise e))
        val leaked=((Posix.Process.kill (Posix.Process.K_GROUP pid,Posix.Signal.fromWord (SysWord.fromInt 0));true) handle OS.SysErr _ => false)
        val ()=if leaked then terminate () else ()
    in {status=if leaked andalso status=0 then 125 else status,seconds=Time.toReal (Timer.checkRealTimer timer)} end
end

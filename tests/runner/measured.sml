(* Resource measurements for bounded children. CPU/RSS come from wait4 via
   Subprocess; kernel samples and instrumentation stay separate in callers. *)
structure Measured =
struct
  open Sh
  exception Failed of string
  type result = {status : int, output : string, errors : string, wall : Time.time,
                 user : Time.time, system : Time.time, residentKB : int}
  fun execute {args,environment,directory,prefix,timeout,limits} : result =
    let val ()=mkdirs (OS.Path.dir prefix)
        val mode=Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.irgrp,Posix.FileSys.S.iroth]
        val input=Posix.FileSys.openf ("/dev/null",Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
        val output=Posix.FileSys.creat (prefix ^ ".stdout",mode)
        val errors=Posix.FileSys.creat (prefix ^ ".stderr",mode)
        fun fd file=SysWord.toInt (Posix.FileSys.fdToWord file)
        fun close ()=(Posix.IO.close input;Posix.IO.close output;Posix.IO.close errors)
        val start=Runtime.clock ()
        val pid=(Subprocess.spawn {program=hd args,args=args,env=SOME environment,search=not (String.isSubstring "/" (hd args)),
                 dir=SOME directory,stdin=SOME (fd input),stdout=SOME (fd output),stderr=SOME (fd errors),group=false,limits=limits}
                 handle e => (close ();raise e))
        val ()=close ()
        fun wait ()=case Subprocess.poll (SOME pid) of SOME result => result | NONE =>
             if Time.>= (Time.- (Runtime.clock (),start),Time.fromSeconds timeout) then
               ((Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)),Posix.Signal.kill) handle OS.SysErr _ => ());
                ignore (Subprocess.wait (SOME pid));write (prefix ^ ".status","timeout\n");raise Failed "measurement process timed out")
             else (OS.Process.sleep (Time.fromMilliseconds 1);wait ())
        val ended=wait ()
        val status=case #status ended of Posix.Process.W_EXITED => 0 | Posix.Process.W_EXITSTATUS code => Word8.toInt code
           | Posix.Process.W_SIGNALED signal => 128+SysWord.toInt (Posix.Signal.toWord signal) | _ => 1
        val ()=write (prefix ^ ".status","exit:" ^ Int.toString status ^ "\n")
    in {status=status,output=read (prefix ^ ".stdout"),errors=read (prefix ^ ".stderr"),wall=Time.- (Runtime.clock (),start),
        user= #user ended,system= #system ended,residentKB= #peakResident ended} end
  fun sort (values : real list) =
    let fun insert x []=[x] | insert x (y :: rest)=if x<=y then x :: y :: rest else y :: insert x rest
    in List.foldl (fn (x,values) => insert x values) [] values end
  fun median values =
    let val values=sort values
        val n=length values
    in if n=0 then raise Failed "no measurement samples" else
       if n mod 2=1 then List.nth (values,n div 2) else (List.nth (values,n div 2-1)+List.nth (values,n div 2))/2.0 end
  fun number n=Json.Number (Real.fmt (StringCvt.FIX (SOME 9)) n)
  fun time value=number (Time.toReal value)
  fun usage (result : result)=Json.Object [("seconds",time (#wall result)),("user_seconds",time (#user result)),
       ("system_seconds",time (#system result)),("max_rss_kib",Json.Number (Int.toString (#residentKB result))),("stderr",Json.String (#errors result))]
end

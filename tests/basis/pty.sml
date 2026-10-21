(* requires: Pty Subprocess Posix OS List SysWord *)
(* Rune's owned pseudo-terminals: every session has borrowed numeric
   descriptors and an ordinary child, which its caller reaps. *)
structure TestPty =
struct
  val windows=List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
  val shell=if windows then valOf (OS.Process.getEnv "COMSPEC") else "/bin/sh"
  val args=if windows then [shell,"/d","/c","exit 0"] else ["sh","-c","exit 0"]
  fun start ()=Pty.spawn {program=shell,args=args,env=NONE,dir=NONE,columns=80,rows=24}
  fun withSession f=let val s=start () val result=(f s handle e => (Pty.close s;ignore (Subprocess.wait (SOME (Pty.process s)));raise e))
                   in ignore (Subprocess.wait (SOME (Pty.process s)));Pty.close s;result end
  val ()=T.check ("Pty.spawn/dimensions",fn () =>
       (ignore (Pty.spawn {program=shell,args=args,env=NONE,dir=NONE,columns=0,rows=24});false) handle Domain => true)
  val ()=T.check ("Pty.input/borrowed-number",fn () => withSession (fn s => Pty.input s>=0))
  val ()=T.check ("Pty.output/borrowed-number",fn () => withSession (fn s => Pty.output s>=0))
  val ()=T.check ("Pty.process/ordinary-child",fn () => withSession (fn s => Pty.process s>0))
  val ()=T.check ("Pty.resize/new-window",fn () => withSession (fn s => (Pty.resize (s,{columns=100,rows=30});true)))
  fun closed () =
       let val s=start () val _=Subprocess.wait (SOME (Pty.process s))
           val ()=(Pty.close s;Pty.close s)
       in s end
  val ()=T.check ("Pty.close/idempotent",fn () => (ignore (closed ());true))
  val ()=T.check ("Pty.Closed/input-after-close",fn () =>
       (ignore (Pty.input (closed ()));false) handle Pty.Closed => true)
end

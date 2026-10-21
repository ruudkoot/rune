(* Bounded full-duplex protocol transport. SML owns descriptor layout,
   framing, draining and child lifecycle; peers share this implementation. *)
structure ProtocolIO =
struct
  exception Failed of string
  type child={pid:int,input:Posix.FileSys.file_desc,channel:Posix.FileSys.file_desc,
              stdout:Posix.FileSys.file_desc option,stderr:Posix.FileSys.file_desc,
              reader:Framing.reader ref,messages:string list ref,inputClosed:bool ref,closed:Posix.FileSys.file_desc list ref}
  fun spawn {args,directory,environment,engine,framing} : child =
    let val toChild=Posix.IO.pipe ()
        val fromChild=Posix.IO.pipe ()
        val out=Posix.IO.pipe ()
        val err=Posix.IO.pipe ()
        val originals=[#infd toChild,#outfd toChild,#infd fromChild,#outfd fromChild,#infd out,#outfd out,#infd err,#outfd err]
        fun close fd=Posix.IO.close fd handle OS.SysErr _ => ()
        fun run ()=
          let val input=Posix.IO.dup (#infd toChild)
              val channel=Posix.IO.dup (#outfd fromChild)
              val output=Posix.IO.dup (if engine then #outfd out else #outfd fromChild)
              val errors=Posix.IO.dup (#outfd err)
              val null=Posix.FileSys.openf ("/dev/null",Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
              val ()=List.app close originals
              val ()=Posix.IO.dup2 {old=if engine then null else input,new=Posix.FileSys.stdin}
              val ()=Posix.IO.dup2 {old=output,new=Posix.FileSys.stdout}
              val ()=Posix.IO.dup2 {old=errors,new=Posix.FileSys.stderr}
              val three=Posix.FileSys.wordToFD 0w3
              val four=Posix.FileSys.wordToFD 0w4
              val ()=if not engine then () else
                    (Posix.IO.dup2 {old=input,new=three};Posix.IO.dup2 {old=channel,new=four};
                     Posix.IO.setfd (three,Posix.IO.FD.flags []);Posix.IO.setfd (four,Posix.IO.FD.flags []))
              val ()=List.app (fn fd => if fd=Posix.FileSys.stdin orelse fd=Posix.FileSys.stdout orelse fd=Posix.FileSys.stderr
                          orelse (engine andalso (fd=three orelse fd=four)) then () else close fd) [input,channel,output,errors,null]
              val ()=OS.FileSys.chDir directory
          in Posix.Process.exece (hd args,args,environment) end
        val pid=if not engine then
                 Subprocess.spawn {program=hd args,args=args,env=SOME environment,search=false,dir=SOME directory,
                   stdin=SOME (SysWord.toInt (Posix.FileSys.fdToWord (#infd toChild))),
                   stdout=SOME (SysWord.toInt (Posix.FileSys.fdToWord (#outfd fromChild))),
                   stderr=SOME (SysWord.toInt (Posix.FileSys.fdToWord (#outfd err))),group=false,limits=Subprocess.unlimited}
                else case Posix.Process.fork () of NONE =>
                 ((run () handle _ => Posix.Process.exit 0w126);raise Failed "exec returned")
               | SOME pid => SysWord.toInt (Posix.Process.pidToWord pid)
        val ()=(close (#infd toChild);close (#outfd fromChild);close (#outfd out);close (#outfd err))
        val ()=if engine then () else close (#infd out)
    in {pid=pid,input= #outfd toChild,channel= #infd fromChild,stdout=if engine then SOME (#infd out) else NONE,stderr= #infd err,
        reader=ref (Framing.reader framing),messages=ref [],inputClosed=ref false,closed=ref []} end
  fun sendRaw (child : child) text =
    let fun write slice=if Word8VectorSlice.length slice=0 then () else
          let val n=Posix.IO.writeVec (#input child,slice)
          in if n=0 then raise Failed "protocol write made no progress" else write (Word8VectorSlice.subslice (slice,n,NONE)) end
    in if !(#inputClosed child) then raise Failed "protocol input is closed" else write (Word8VectorSlice.full (Byte.stringToBytes text)) end
  fun send child framing text=sendRaw child (Framing.frame (framing,text))
  fun ready fd timeout=case OS.IO.pollDesc (Posix.FileSys.fdToIOD fd) of NONE => raise Failed "descriptor cannot be polled"
             | SOME descriptor => not (null (OS.IO.poll ([OS.IO.pollIn descriptor],SOME timeout)))
  fun read (child : child) fd =
    let val data=Posix.IO.readVec (fd,65536)
    in if Word8Vector.length data=0 then (#closed child := fd :: !(#closed child);NONE) else SOME (Byte.bytesToString data) end
  fun live (child : child) fd=not (List.exists (fn closed => closed=fd) (!(#closed child)))
  fun drain (child : child) output =
    let fun channel name fd=if not (live child fd) orelse not (ready fd Time.zeroTime) then () else
               (case read child fd of NONE => () | SOME text => (output (name,text);channel name fd))
    in case #stdout child of SOME fd => channel "stdout" fd | NONE => ();channel "stderr" (#stderr child) end
  fun receiveTime (child : child) duration output =
    let val start=Runtime.clock ()
        fun next ()=
          (drain child output;
           case !(#messages child) of text :: rest => (#messages child:=rest;SOME text) | [] =>
             if not (live child (#channel child)) then NONE else
             if Time.>= (Time.- (Runtime.clock (),start),duration) then raise Failed "protocol response timed out" else
             let val descriptors= #channel child :: #stderr child :: (case #stdout child of SOME fd => [fd] | NONE => [])
                 val descriptors=List.filter (live child) descriptors
                 val polls=List.mapPartial (fn fd => Option.map OS.IO.pollIn (OS.IO.pollDesc (Posix.FileSys.fdToIOD fd))) descriptors
                 val _=OS.IO.poll (polls,SOME (Time.fromMilliseconds 100))
                 val ()=drain child output
             in if ready (#channel child) Time.zeroTime then
                  (case read child (#channel child) of NONE => NONE | SOME text =>
                    let val (messages,reader)=Framing.feed (!(#reader child),text)
                    in #reader child:=reader;#messages child:= !(#messages child) @ messages;next () end)
                else next () end)
    in next () end
  fun receive child seconds output=receiveTime child (Time.fromSeconds seconds) output
  fun signal (child : child) signal=Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt (#pid child))),signal)
  fun closeInput (child : child)=if !(#inputClosed child) then () else (Posix.IO.close (#input child);#inputClosed child:=true)
  fun wait (child : child) seconds =
    let val start=Runtime.clock ()
        fun poll ()=case Subprocess.poll (SOME (#pid child)) of SOME ended => ended | NONE =>
             if Time.>= (Time.- (Runtime.clock (),start),Time.fromSeconds seconds) then
                  (signal child Posix.Signal.kill;ignore (Subprocess.wait (SOME (#pid child)));raise Failed "protocol child did not exit")
             else (OS.Process.sleep (Time.fromMilliseconds 10);poll ())
    in poll () end
  fun close (child : child)=
    (closeInput child handle OS.SysErr _ => ();
     List.app (fn fd => Posix.IO.close fd handle OS.SysErr _ => ()) (#channel child :: #stderr child :: (case #stdout child of SOME fd => [fd] | NONE => [])))
end

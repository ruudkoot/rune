(* Portable supervised pipes. Neither reading nor writing the worker blocks
   the protocol loop; process creation uses Subprocess.spawn on every platform. *)
structure RuneLspWorkerProcess =
struct
  structure W=RuneLspWorkerWire
  datatype event=Message of W.value | Ended | Failed of string
  datatype t=Process of {pid:Subprocess.pid,input:Posix.FileSys.file_desc,output:Posix.FileSys.file_desc,
    reader:Framing.reader ref,queue:(string*int) list ref,bytes:int ref,closed:bool ref,
    status:Subprocess.ended option ref}
  fun closeFd fd=Posix.IO.close fd handle OS.SysErr _ => ()
  fun nonblocking fd=let val (flags,_)=Posix.IO.getfl fd
    in Posix.IO.setfl (fd,Posix.IO.O.flags [flags,Posix.IO.O.nonblock]) end
  fun start {command,args,limits} =
    let val {infd=readOutput,outfd=childOutput}=Posix.IO.pipe ()
        val {infd=childInput,outfd=writeInput}=Posix.IO.pipe ()
          handle error => (closeFd readOutput;closeFd childOutput;raise error)
        fun clean ()=List.app closeFd [readOutput,childOutput,childInput,writeInput]
        fun number fd=SysWord.toInt (Posix.FileSys.fdToWord fd)
        fun launch () =
          let val ()=Posix.IO.setfd (readOutput,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (writeInput,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (childInput,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (childOutput,Posix.IO.FD.cloexec)
              val ()=nonblocking writeInput
              val ()=nonblocking readOutput
              val pid=Subprocess.spawn {program=command,args=command :: args,env=NONE,search=false,dir=NONE,
                stdin=SOME (number childInput),stdout=SOME (number childOutput),stderr=NONE,group=true,limits=limits}
              val ()=(closeFd childInput;closeFd childOutput)
          in Process {pid=pid,input=writeInput,output=readOutput,
            reader=ref (Framing.bounded {framing=Framing.ContentLength,maxHeaderBytes=8192,maxBodyBytes=W.maximum}),
            queue=ref [],bytes=ref 0,closed=ref false,status=ref NONE} end
    in launch () handle error => (clean ();raise error) end
  fun closed (Process {closed,...})= !closed
  fun reap (Process {pid,status,...}) =
    case !status of SOME value => SOME value | NONE =>
      (case Subprocess.poll (SOME pid) of NONE => NONE
       | SOME value => (status:=SOME value;SOME value))
  fun terminate (process as Process {pid,input,output,closed,queue,bytes,...}) =
    (if !closed then () else
       (closed:=true;queue:=[];bytes:=0;closeFd input;closeFd output;
        Subprocess.kill (pid,Posix.Signal.kill) handle OS.SysErr _ => ());
     ignore (reap process) handle OS.SysErr _ => ())
  fun enqueue (Process {queue,bytes,closed,...},value) =
    if !closed then raise W.Invalid "analysis worker is closed" else
      let val (count,pieces)=W.chunks value
          val header="Content-Length: " ^ Int.toString count ^ "\r\n\r\n"
          val total=count+size header
          val ()=if total>W.maximum+8192- !bytes then raise W.Invalid "worker output queue exceeds byte limit" else ()
      in queue:= !queue @ List.map (fn piece => (piece,0)) (header :: pieces);bytes:= !bytes+total end
  fun descriptor fd=valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD fd))
  fun descriptors (Process {input,output,queue,closed,...}) =
    if !closed then [] else OS.IO.pollIn (descriptor output) ::
      (if null (!queue) then [] else [OS.IO.pollOut (descriptor input)])
  fun ready (info,fd)=OS.IO.compare (OS.IO.pollToIODesc (OS.IO.infoToPollDesc info),Posix.FileSys.fdToIOD fd)=EQUAL
  fun again (SOME error)=error=Posix.Error.again orelse error=Posix.Error.intr | again NONE=false
  fun pump (process as Process {input,output,reader,queue,bytes,closed,...},events) =
    if !closed then [] else
    let fun readable info=ready (info,output) andalso OS.IO.isIn info
        fun writable info=ready (info,input) andalso OS.IO.isOut info
        fun write ()=case !queue of [] => () | (text,offset) :: rest =>
          if offset=size text then (queue:=rest;write ()) else
          let val count=Int.min (4096,size text-offset)
              val written=Posix.IO.writeVec (input,Word8VectorSlice.slice (Byte.stringToBytes text,offset,SOME count))
          in if written=0 then () else
             (bytes:= !bytes-written;queue:=(if offset+written=size text then rest else (text,offset+written)::rest)) end
        fun receive () =
          let val chunk=Posix.IO.readVec (output,16384)
          in if Word8Vector.length chunk=0 then
               let val partial=Framing.pending (!reader)
                   val ()=terminate process
               in [if partial then Failed "analysis worker ended inside a frame" else Ended] end
             else let val (messages,next)=Framing.feed (!reader,Byte.bytesToString chunk)
                  in reader:=next;List.map (Message o W.decode) messages end end
        val ()=if List.exists writable events then (write () handle OS.SysErr (_,error) =>
          if again error then () else raise OS.SysErr ("analysis worker write failed",error)) else ()
    in if List.exists readable events then (receive () handle OS.SysErr (_,error) => if again error then []
         else raise OS.SysErr ("analysis worker read failed",error)) else [] end
    handle error => (terminate process;[Failed (case error of W.Invalid message => message
      | Framing.Header message => message | Framing.Limit message => message | _ => General.exnMessage error)])
end

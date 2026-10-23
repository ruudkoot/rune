(* Portable supervised pipes. Neither reading nor writing the worker blocks
   the protocol loop; process creation uses Subprocess.spawn on every platform. *)
structure RuneLspWorkerProcess =
struct
  structure W=RuneLspWorkerWire
  datatype event=Message of W.value | Ended | Failed of string
  datatype t=Process of {pid:Subprocess.pid,input:Posix.FileSys.file_desc,output:Posix.FileSys.file_desc,
    errors:Posix.FileSys.file_desc,errorText:string ref,errorBytes:int ref,errorEnded:bool ref,
    reader:Framing.reader ref,queue:(string*int) list ref,bytes:int ref,closed:bool ref,
    status:Subprocess.ended option ref}
  fun closeFd fd=Posix.IO.close fd handle OS.SysErr _ => ()
  fun nonblocking fd=let val (flags,_)=Posix.IO.getfl fd
    in Posix.IO.setfl (fd,Posix.IO.O.flags [flags,Posix.IO.O.nonblock]) end
  fun start {command,args,limits} =
    let val {infd=readOutput,outfd=childOutput}=Posix.IO.pipe ()
        val {infd=childInput,outfd=writeInput}=Posix.IO.pipe ()
          handle error => (closeFd readOutput;closeFd childOutput;raise error)
        val {infd=readError,outfd=childError}=Posix.IO.pipe ()
          handle error => (List.app closeFd [readOutput,childOutput,childInput,writeInput];raise error)
        fun clean ()=List.app closeFd [readOutput,childOutput,childInput,writeInput,readError,childError]
        fun number fd=SysWord.toInt (Posix.FileSys.fdToWord fd)
        fun launch () =
          let val ()=Posix.IO.setfd (readOutput,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (writeInput,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (childInput,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (childOutput,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (readError,Posix.IO.FD.cloexec)
              val ()=Posix.IO.setfd (childError,Posix.IO.FD.cloexec)
              val ()=nonblocking writeInput
              val ()=nonblocking readOutput
              val ()=nonblocking readError
              val pid=Subprocess.spawn {program=command,args=command :: args,env=NONE,search=false,dir=NONE,
                stdin=SOME (number childInput),stdout=SOME (number childOutput),stderr=SOME(number childError),group=true,limits=limits}
              val ()=(closeFd childInput;closeFd childOutput;closeFd childError)
          in Process {pid=pid,input=writeInput,output=readOutput,
            errors=readError,errorText=ref "",errorBytes=ref 0,errorEnded=ref false,
            reader=ref (Framing.bounded {framing=Framing.ContentLength,maxHeaderBytes=8192,maxBodyBytes=W.maximum}),
            queue=ref [],bytes=ref 0,closed=ref false,status=ref NONE} end
    in launch () handle error => (clean ();raise error) end
  fun closed (Process {closed,...})= !closed
  fun reap (Process {pid,status,...}) =
    case !status of SOME value => SOME value | NONE =>
      (case Subprocess.poll (SOME pid) of NONE => NONE
       | SOME value => (status:=SOME value;SOME value))
  fun terminate (process as Process {pid,input,output,errors,closed,queue,bytes,...}) =
    (if !closed then () else
       (closed:=true;queue:=[];bytes:=0;closeFd input;closeFd output;closeFd errors;
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
  fun descriptors (Process {input,output,errors,errorEnded,queue,closed,...}) =
    if !closed then [] else OS.IO.pollIn (descriptor output) ::
      ((if !errorEnded then [] else [OS.IO.pollIn(descriptor errors)]) @
       (if null (!queue) then [] else [OS.IO.pollOut (descriptor input)]))
  fun ready (info,fd)=OS.IO.compare (OS.IO.pollToIODesc (OS.IO.infoToPollDesc info),Posix.FileSys.fdToIOD fd)=EQUAL
  fun again (SOME error)=error=Posix.Error.again orelse error=Posix.Error.intr | again NONE=false
  fun pump (process as Process {input,output,errors,errorText,errorBytes,errorEnded,reader,queue,bytes,closed,...},events) =
    if !closed then [] else
    let fun readable info=ready (info,output) andalso OS.IO.isIn info
        fun writable info=ready (info,input) andalso OS.IO.isOut info
        fun drain ()=if !errorEnded then () else
          let val chunk=Byte.bytesToString(Posix.IO.readVec(errors,4096))
              val count=size chunk
              val ()=if count=0 then errorEnded:=true else ()
              val ()=errorBytes:=Int.min(65536,!errorBytes+count)
              val ()=if size(!errorText)<4096 then
                errorText:= !errorText ^ String.substring(chunk,0,Int.min(count,4096-size(!errorText))) else ()
          in () end handle OS.SysErr(_,error)=>if again error then () else errorEnded:=true
        fun reason ()=if String.isSubstring "heap limit exceeded" (!errorText) then "analysis worker exhausted its heap budget"
          else if !errorBytes>=65536 then "analysis worker exceeded its stderr budget"
          else "analysis worker exited"
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
               in [if partial then Failed "analysis worker ended inside a frame"
                   else if !errorBytes>0 then Failed(reason()) else Ended] end
             else let val (messages,next)=Framing.feed (!reader,Byte.bytesToString chunk)
                  in reader:=next;List.map (Message o W.decode) messages end end
        val ()=if List.exists(fn info=>ready(info,errors) andalso OS.IO.isIn info)events then drain() else ()
        val fatal=String.isSubstring "heap limit exceeded" (!errorText) orelse !errorBytes>=65536
        val ()=if fatal then () else if List.exists writable events then (write () handle OS.SysErr (_,error) =>
          if again error then () else raise OS.SysErr ("analysis worker write failed",error)) else ()
    in if fatal then (terminate process;[Failed(reason())])
       else if List.exists readable events then (receive () handle OS.SysErr (_,error) => if again error then []
         else raise OS.SysErr ("analysis worker read failed",error)) else [] end
    handle error => (terminate process;[Failed (case error of W.Invalid message => message
      | Framing.Header message => message | Framing.Limit message => message | _ => General.exnMessage error)])
end

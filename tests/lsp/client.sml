(* Independent framed client: no server framing or LSP codec is used. *)
structure RuneLspTestClient =
struct
  datatype t=Client of {pid:Subprocess.pid,input:Posix.FileSys.file_desc,output:Posix.FileSys.file_desc,
    bytes:string ref,messages:Json.value list ref,closed:bool ref}
  fun field (value,name)=case Json.member (name,value) of SOME value => value | NONE => raise Fail ("missing client field " ^ name)
  fun start (program,args) =
    let val incoming=Posix.IO.pipe () val outgoing=Posix.IO.pipe ()
        val handles=[#infd incoming,#outfd incoming,#infd outgoing,#outfd outgoing]
        val ()=List.app (fn fd => Posix.IO.setfd (fd,Posix.IO.FD.cloexec)) handles
        fun number fd=SysWord.toInt (Posix.FileSys.fdToWord fd)
        val pid=Subprocess.spawn {program=program,args=program::args,env=NONE,search=false,dir=NONE,
          stdin=SOME (number (#infd incoming)),stdout=SOME (number (#outfd outgoing)),stderr=NONE,group=true,limits=Subprocess.unlimited}
        val ()=(Posix.IO.close (#infd incoming);Posix.IO.close (#outfd outgoing))
    in Client {pid=pid,input= #outfd incoming,output= #infd outgoing,bytes=ref "",messages=ref [],closed=ref false} end
  fun send (Client {input,...},value) =
    let val text=Json.encode value
        val bytes=Byte.stringToBytes ("Content-Length: " ^ Int.toString (size text) ^ "\r\n\r\n" ^ text)
        fun write offset=if offset=Word8Vector.length bytes then () else
          let val count=Posix.IO.writeVec (input,Word8VectorSlice.slice (bytes,offset,SOME (Int.min (257,Word8Vector.length bytes-offset))))
          in if count=0 then raise Fail "client output closed" else write (offset+count) end
    in write 0 end
  fun request (client,id,method,params)=send (client,Json.Object ([("jsonrpc",Json.String "2.0"),
    ("id",Json.int id),("method",Json.String method)] @ (case params of Json.Null => [] | _ => [("params",params)])))
  fun notify (client,method,params)=send (client,Json.Object ([("jsonrpc",Json.String "2.0"),("method",Json.String method)] @
    (case params of Json.Null => [] | _ => [("params",params)])))
  fun take text =
    let val (header,suffix)=Substring.position "\r\n\r\n" (Substring.full text)
    in if Substring.isEmpty suffix then NONE else
      let val head=Substring.string header
          val prefix="Content-Length: "
          val ()=if String.isPrefix prefix head then () else raise Fail "invalid server frame header"
          val digits=String.extract (head,size prefix,NONE)
          val ()=if digits<>"" andalso CharVector.all Char.isDigit digits then () else raise Fail "invalid server frame count"
          val count=valOf (Int.fromString digits)
          val body=Substring.string (Substring.triml 4 suffix)
      in if size body<count then NONE else SOME (Json.decode (String.substring (body,0,count)),String.extract (body,count,NONE)) end
    end
  fun receiveWithin (Client {output,bytes,messages,...},predicate,timeout) =
    let val until=Time.+ (Time.now (),timeout)
        fun buffer ()=case take (!bytes) of NONE => () | SOME (value,rest) =>
          (bytes:=rest;messages:= !messages @ [value];buffer ())
        fun loop () =
          let val ()=buffer ()
          in case List.find predicate (!messages) of SOME value =>
               (messages:=List.filter (fn prior => prior<>value) (!messages);value)
           | NONE => if Time.> (Time.now (),until) then raise Fail "LSP response timeout" else
               let val descriptor=OS.IO.pollIn (valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD output)))
               in if null (OS.IO.poll ([descriptor],SOME (Time.fromMilliseconds 20))) then loop () else
                 let val chunk=Posix.IO.readVec (output,4096)
                 in if Word8Vector.length chunk=0 then raise Fail "LSP server exited" else
                    (bytes:= !bytes ^ Byte.bytesToString chunk;loop ()) end end end
    in loop () end
  fun receive (client,predicate)=receiveWithin(client,predicate,Time.fromSeconds 20)
  fun response (client,id)=receive (client,fn value => Json.member ("id",value)=SOME (Json.int id))
  fun result response=case Json.member ("result",response) of SOME value => value
    | NONE => raise Fail (Json.encode (field (response,"error")))
  fun awaitExit (Client {pid,input,output,closed,...},timeout)=
    let val until=Time.+(Time.now(),timeout)
        fun loop()=case Subprocess.poll(SOME pid) of SOME ended=>
            (closed:=true;Posix.IO.close input;Posix.IO.close output;
             case #status ended of Posix.Process.W_EXITED=>() | _=>raise Fail "LSP exited unsuccessfully")
          | NONE=>if Time.>(Time.now(),until) then raise Fail "LSP shutdown timeout"
              else (ignore(OS.IO.poll([],SOME(Time.fromMilliseconds 10)));loop())
    in loop() end
  fun close (Client {pid,input,output,closed,...}) = if !closed then () else
    (closed:=true;(Posix.IO.close input handle _ => ());(Posix.IO.close output handle _ => ());
     (Subprocess.kill (pid,Posix.Signal.kill) handle _ => ());ignore (Subprocess.wait (SOME pid)) handle _ => ())
end

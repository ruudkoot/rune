structure RuneLspWorkerEcho =
struct
  structure W=RuneLspWorkerWire
  fun raw text =
    let val bytes=Byte.stringToBytes text
        fun write offset=if offset=size text then () else
          write (offset+Posix.IO.writeVec (Posix.FileSys.stdout,Word8VectorSlice.slice (bytes,offset,NONE)))
    in write 0 end
  fun send value=raw (Framing.frame (Framing.ContentLength,W.encode value))
  fun handleValue value = case value of
    W.Bytes "hold" => (send (W.Bytes "holding");Posix.Process.sleep (Time.fromSeconds 10);())
  | W.Bytes "truncate" => (raw "Content-Length: 20\r\n\r\nx";OS.Process.exit OS.Process.success)
  | _ => send value
  fun loop reader =
    let val bytes=Posix.IO.readVec (Posix.FileSys.stdin,4096)
    in if Word8Vector.length bytes=0 then () else
      let val (messages,reader)=Framing.feed (reader,Byte.bytesToString bytes)
      in List.app (handleValue o W.decode) messages;loop reader end end
  fun main ()=(send (W.Bytes "ready");loop (Framing.bounded {framing=Framing.ContentLength,maxHeaderBytes=8192,maxBodyBytes=W.maximum}))
end
val ()=RuneLspWorkerEcho.main ()

(* Socket: a loopback echo on a port the system picks, and a datagram to
   ourselves. *)
val server : Socket.passive INetSock.stream_sock = INetSock.TCP.socket ()
val () = Socket.Ctl.setREUSEADDR (server, true)
val () = Socket.bind (server, INetSock.any 0)
val () = Socket.listen (server, 4)
val (_, port) = INetSock.fromAddr (Socket.Ctl.getSockName server)
val () = print ("port chosen: " ^ Bool.toString (port > 0) ^ "\n")
val () = print ("acceptNB with nobody waiting: "
                ^ (case Socket.acceptNB server of NONE => "NONE" | SOME _ => "SOME") ^ "\n")
val client : Socket.active INetSock.stream_sock = INetSock.TCP.socket ()
val loopback = valOf (NetHostDB.fromString "127.0.0.1")   (* an in_addr is abstract *)
val () = Socket.connect (client, INetSock.toAddr (loopback, port))
val (session, from) = Socket.accept server
val (host, _) = INetSock.fromAddr from
val () = print ("from: " ^ NetHostDB.toString host ^ "\n")
val () = print ("same address as the client's own: "
                ^ Bool.toString (Socket.sameAddr (from, Socket.Ctl.getSockName client)) ^ "\n")
val () = print ("recvVecNB with nothing sent: "
                ^ (case Socket.recvVecNB (session, 16) of NONE => "NONE" | SOME _ => "SOME") ^ "\n")
val sent = Socket.sendVec (client, Word8VectorSlice.full (Byte.stringToBytes "ping"))
val got = Socket.recvVec (session, 16)
val () = print ("server got: " ^ Byte.bytesToString got ^ " (" ^ Int.toString sent ^ " bytes)\n")
val _ = Socket.sendVec (session, Word8VectorSlice.full (Byte.stringToBytes "pong"))
val () = print ("client got: " ^ Byte.bytesToString (Socket.recvVec (client, 16)) ^ "\n")
val () = Socket.shutdown (client, Socket.NO_SENDS)
val {rds, ...} = Socket.select {rds = [Socket.sockDesc session], wrs = [], exs = [],
                                timeout = SOME (Time.fromSeconds 5)}
val () = print ("select: " ^ Int.toString (length rds) ^ " readable\n")
val () = print ("after the client's shutdown: "
                ^ (case Socket.recvVecNB (session, 16) of
                     NONE => "NONE"
                   | SOME v => "SOME \"" ^ Byte.bytesToString v ^ "\"") ^ "\n")
val () = (Socket.close client; Socket.close session; Socket.close server)
val udp : INetSock.dgram_sock = INetSock.UDP.socket ()
val () = Socket.bind (udp, INetSock.any 0)
val (_, uport) = INetSock.fromAddr (Socket.Ctl.getSockName udp)
val () = Socket.sendVecTo (udp, INetSock.toAddr (loopback, uport),
                           Word8VectorSlice.full (Byte.stringToBytes "datagram"))
val (bytes, whence) = Socket.recvVecFrom (udp, 32)
val () = print ("datagram: " ^ Byte.bytesToString bytes ^ " from port "
                ^ Bool.toString (#2 (INetSock.fromAddr whence) = uport) ^ "\n")
val () = print ("recvVecFromNB with nothing sent: "
                ^ (case Socket.recvVecFromNB (udp, 32) of NONE => "NONE" | SOME _ => "SOME") ^ "\n")
val () = Socket.close udp

(* Socket: a loopback echo on a port the system picks, and a datagram to
   ourselves. *)
val server : Socket.passive INetSock.stream_sock = INetSock.TCP.socket ()
val () = Socket.setREUSEADDR (server, true)
val () = Socket.bind (server, INetSock.any 0)
val () = Socket.listen (server, 4)
val (_, port) = INetSock.fromAddr (Socket.getSockName server)
val () = print ("port chosen: " ^ Bool.toString (port > 0) ^ "\n")
val client : Socket.active INetSock.stream_sock = INetSock.TCP.socket ()
val () = Socket.connect (client, INetSock.toAddr ("127.0.0.1", port))
val (session, from) = Socket.accept server
val (host, _) = INetSock.fromAddr from
val () = print ("from: " ^ host ^ "\n")
val sent = Socket.sendVec (client, Word8VectorSlice.full (Byte.stringToBytes "ping"))
val got = Socket.recvVec (session, 16)
val () = print ("server got: " ^ Byte.bytesToString got ^ " (" ^ Int.toString sent ^ " bytes)\n")
val _ = Socket.sendVec (session, Word8VectorSlice.full (Byte.stringToBytes "pong"))
val () = print ("client got: " ^ Byte.bytesToString (Socket.recvVec (client, 16)) ^ "\n")
val () = List.app Socket.close [client, session, server]
val udp : INetSock.dgram_sock = INetSock.UDP.socket ()
val () = Socket.bind (udp, INetSock.any 0)
val (_, uport) = INetSock.fromAddr (Socket.getSockName udp)
val _ = Socket.sendVecTo (udp, INetSock.toAddr ("127.0.0.1", uport),
                              Word8VectorSlice.full (Byte.stringToBytes "datagram"))
val (bytes, whence) = Socket.recvVecFrom (udp, 32)
val () = print ("datagram: " ^ Byte.bytesToString bytes ^ " from port "
                ^ Bool.toString (#2 (INetSock.fromAddr whence) = uport) ^ "\n")
val () = Socket.close udp

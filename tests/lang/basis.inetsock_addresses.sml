(* INetSock and UnixSock: making addresses and taking them apart, and a pair
   of connected sockets in the file system's family. *)
(* an in_addr is abstract: NetHostDB reads and writes the dotted text *)
val a : INetSock.sock_addr = INetSock.toAddr (valOf (NetHostDB.fromString "192.0.2.7"), 8080)
val (host, port) = INetSock.fromAddr a
val () = print (NetHostDB.toString host ^ ":" ^ Int.toString port ^ " family is INET: "
                ^ Bool.toString (Socket.familyOfAddr a = INetSock.inetAF) ^ "\n")
val (anyHost, anyPort) = INetSock.fromAddr (INetSock.any 0)
val () = print ("any: " ^ NetHostDB.toString anyHost ^ " " ^ Int.toString anyPort ^ "\n")
val path = OS.FileSys.tmpName ()
val u : UnixSock.sock_addr = UnixSock.toAddr path
val () = print ("unix address round trip: " ^ Bool.toString (UnixSock.fromAddr u = path)
                ^ " family is UNIX: " ^ Bool.toString (Socket.familyOfAddr u = UnixSock.unixAF) ^ "\n")
val () = OS.FileSys.remove path
val (one, two) : Socket.active UnixSock.stream_sock * Socket.active UnixSock.stream_sock =
  UnixSock.Strm.socketPair ()
val _ = Socket.sendVec (one, Word8VectorSlice.full (Byte.stringToBytes "paired"))
val () = print ("pair: " ^ Byte.bytesToString (Socket.recvVec (two, 16)) ^ "\n")
val () = (Socket.close one; Socket.close two)

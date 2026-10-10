val l = INetSock.TCP.socket () : (INetSock.inet, Socket.passive Socket.stream) Socket.sock;
val () = (Socket.bind (l, INetSock.toAddr (valOf (NetHostDB.fromString "127.0.0.1"), 0)); Socket.listen (l, 4));
val (_, p) = INetSock.fromAddr (Socket.Ctl.getSockName l);
val c = INetSock.TCP.socket () : (INetSock.inet, Socket.active Socket.stream) Socket.sock;
val () = Socket.connect (c, INetSock.toAddr (valOf (NetHostDB.fromString "127.0.0.1"), p));
val a = case Socket.acceptNB l of SOME (a, _) => a | NONE => raise Fail "no connection";
val () = print "accepted\n";
val r = Socket.recvVecNB (a, 100);
val () = print (case r of NONE => "NONE: would block\n" | SOME v => "SOME " ^ Int.toString (Word8Vector.length v) ^ "\n");

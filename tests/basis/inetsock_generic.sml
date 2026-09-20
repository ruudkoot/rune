(* requires: GenericSock Socket INetSock UnixSock Byte OS *)
(* uses: fn/sockets.sml *)
(* GenericSock (signature GENERIC_SOCK): sockets of any family and type.
   Expected values follow https://smlfamily.github.io/Basis/generic-sock.html.
   The sockets it makes are used as those of INetSock and UnixSock would be:
   on the loopback interface, or with names in the current directory
   (fn/sockets.sml). 6 and 17 are the protocol numbers of TCP and UDP. *)
structure TestGenericSock =
struct
  structure S = Sockets
  val eqS = T.eq T.string
  val inet = INetSock.inetAF
  val unix = UnixSock.unixAF
  val stream = Socket.SOCK.stream
  val dgram = Socket.SOCK.dgram

  (* c works as a TCP client *)
  fun tcpClient (c : S.tcp) : string =
    S.withListener (fn l =>
      (Socket.connect (c, Socket.Ctl.getSockName l);
       S.using (fn () => #1 (Socket.accept l), S.quietly Socket.close) (fn s =>
         (ignore (S.send (c, "ping")); ignore (S.send (s, "pong"));
          Socket.SOCK.toString (Socket.Ctl.getTYPE c) ^ " " ^ S.recvAll (s, 4) ^ " " ^ S.recvAll (c, 4)))))
  (* s works as a UDP socket *)
  fun udpSocket (s : S.udp) : string =
    (Socket.bind (s, INetSock.toAddr (S.loopback (), 0));
     Socket.sendVecTo (s, Socket.Ctl.getSockName s, S.vslice "to myself");
     Socket.SOCK.toString (Socket.Ctl.getTYPE s) ^ " "
     ^ (if S.readable s then
          case Socket.recvVecFromNB (s, 100) of SOME (v, _) => S.text v | NONE => "NONE"
        else "nothing"))
  (* s works as a Unix-domain socket with a name *)
  fun unixNamed (path : string) (s : ('st) UnixSock.sock) : string =
    S.withPath path (fn p =>
      (Socket.bind (s, UnixSock.toAddr p);
       Socket.SOCK.toString (Socket.Ctl.getTYPE s) ^ " " ^ UnixSock.fromAddr (Socket.Ctl.getSockName s)))
  (* a and b are connected stream sockets *)
  fun strmPair (a : S.strm, b : S.strm) : string =
    (ignore (S.send (a, "ping")); ignore (S.send (b, "pong"));
     Socket.SOCK.toString (Socket.Ctl.getTYPE a) ^ " " ^ S.recvAll (b, 4) ^ " " ^ S.recvAll (a, 4))
  (* a and b are datagram sockets connected to each other *)
  fun dgrmPair (a : S.dgrm, b : S.dgrm) : string =
    Socket.SOCK.toString (Socket.Ctl.getTYPE a) ^ " " ^ Socket.SOCK.toString (Socket.Ctl.getTYPE b) ^ " "
    ^ Bool.toString (Socket.sameAddr (Socket.Ctl.getPeerName a, Socket.Ctl.getSockName b))
  fun pair (make : unit -> ('af, 'st) Socket.sock * ('af, 'st) Socket.sock) f =
    S.using (make, fn (a, b) => S.closeAll [a, b]) f

  (*<< socket *)
  (* socket (af, st) "creates a socket in the address family specified by af
     and the socket type specified by st, with the default protocol" *)
  val () = eqS ("GenericSock.socket/inet-stream", "STREAM ping pong",
                fn () => S.withSocket (fn () => GenericSock.socket (inet, stream)) tcpClient)
  val () = eqS ("GenericSock.socket/inet-dgram", "DGRAM to myself",
                fn () => S.withSocket (fn () => GenericSock.socket (inet, dgram)) udpSocket)
  val () = eqS ("GenericSock.socket/unix-stream", "STREAM generic-strm.sock",
                fn () => S.withSocket (fn () => GenericSock.socket (unix, stream))
                                      (fn (s : S.strm) => unixNamed "generic-strm.sock" s))
  val () = eqS ("GenericSock.socket/unix-dgram", "DGRAM generic-dgrm.sock",
                fn () => S.withSocket (fn () => GenericSock.socket (unix, dgram))
                                      (fn (s : S.dgrm) => unixNamed "generic-dgrm.sock" s))
  (* socket' (af, st, i): "with protocol number i" *)
  val () = eqS ("GenericSock.socket'/inet-stream-0", "STREAM ping pong",
                fn () => S.withSocket (fn () => GenericSock.socket' (inet, stream, 0)) tcpClient)
  val () = eqS ("GenericSock.socket'/inet-stream-tcp", "STREAM ping pong",
                fn () => S.withSocket (fn () => GenericSock.socket' (inet, stream, 6)) tcpClient)
  val () = eqS ("GenericSock.socket'/inet-dgram-udp", "DGRAM to myself",
                fn () => S.withSocket (fn () => GenericSock.socket' (inet, dgram, 17)) udpSocket)
  val () = eqS ("GenericSock.socket'/unix-stream-0", "STREAM generic-strm0.sock",
                fn () => S.withSocket (fn () => GenericSock.socket' (unix, stream, 0))
                                      (fn (s : S.strm) => unixNamed "generic-strm0.sock" s))
  (*>> socket *)

  (*<< socketPair *)
  (* socketPair (af, st) "creates an unnamed pair of connected sockets in the
     address family specified by af and the socket type specified by st" *)
  val () = eqS ("GenericSock.socketPair/unix-stream", "STREAM ping pong",
                fn () => pair (fn () => GenericSock.socketPair (unix, stream)) strmPair)
  val () = eqS ("GenericSock.socketPair/unix-dgram", "DGRAM DGRAM true",
                fn () => pair (fn () => GenericSock.socketPair (unix, dgram)) dgrmPair)
  val () = eqS ("GenericSock.socketPair'/unix-stream-0", "STREAM ping pong",
                fn () => pair (fn () => GenericSock.socketPair' (unix, stream, 0)) strmPair)
  val () = eqS ("GenericSock.socketPair'/unix-dgram-0", "DGRAM DGRAM true",
                fn () => pair (fn () => GenericSock.socketPair' (unix, dgram, 0)) dgrmPair)
  (*>> socketPair *)
end

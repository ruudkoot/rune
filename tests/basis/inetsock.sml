(* requires: INetSock Socket NetHostDB Byte *)
(* uses: fn/sockets.sml *)
(* INetSock (signature INET_SOCK): addresses of the Internet domain and its
   UDP and TCP sockets. Expected values follow
   https://smlfamily.github.io/Basis/inet-sock.html. Sockets are bound to
   the loopback interface, on ports the system picks (fn/sockets.sml), or,
   for `any`, to a port the system picks and no address in particular. *)
structure TestINetSock =
struct
  structure S = Sockets
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  fun inAddr s = valOf (NetHostDB.fromString s)
  fun addr (host, port) = INetSock.toAddr (inAddr host, port)
  fun parts a = let val (h, p) = INetSock.fromAddr a in NetHostDB.toString h ^ ":" ^ Int.toString p end
  fun udp f = S.withSocket INetSock.UDP.socket (fn (s : S.udp) => f s)
  fun tcp f = S.withSocket INetSock.TCP.socket (fn (s : S.tcp) => f s)
  (* s works as a datagram socket: bound to the loopback interface, it gets
     what it sends to itself *)
  fun datagrams (s : S.udp) : string =
    (Socket.bind (s, INetSock.toAddr (S.loopback (), 0));
     Socket.sendVecTo (s, Socket.Ctl.getSockName s, S.vslice "to myself");
     if S.readable s then
       case Socket.recvVecFromNB (s, 100) of SOME (v, _) => S.text v | NONE => "NONE"
     else "nothing")
  (* c works as a TCP client: it connects to a listener, and bytes go both ways *)
  fun streams (c : S.tcp) : string =
    S.withListener (fn l =>
      (Socket.connect (c, Socket.Ctl.getSockName l);
       S.using (fn () => #1 (Socket.accept l), S.quietly Socket.close) (fn s =>
         (ignore (S.send (c, "ping")); ignore (S.send (s, "pong")); S.recvAll (s, 4) ^ " " ^ S.recvAll (c, 4)))))

  (*<< inetAF *)
  (* "The address family value that represents the Internet domain"; the
     family's name is "INET" (socket.html) *)
  val () = eqS ("INetSock.inetAF/named-INET", "INET", fn () => Socket.AF.toString INetSock.inetAF)
  val () = T.check ("INetSock.inetAF/fromString-INET", fn () => Socket.AF.fromString "INET" = SOME INetSock.inetAF)
  (*>> inetAF *)

  (*<< addresses *)
  (* toAddr (ia, i) "converts an Internet address ia and a port number i into
     a socket address"; fromAddr converts it back into "a pair (ia,i)" *)
  val () = eqS ("INetSock.toAddr/fromAddr", "127.0.0.1:80", fn () => parts (addr ("127.0.0.1", 80)))
  val () = T.eq (T.list T.string) ("INetSock.fromAddr/ports", ["10.0.0.1:0", "10.0.0.1:1", "10.0.0.1:255", "10.0.0.1:256",
                                                              "10.0.0.1:8080", "10.0.0.1:65535"],
                                   fn () => List.map (fn p => parts (addr ("10.0.0.1", p))) [0, 1, 255, 256, 8080, 65535])
  val () = T.eq (T.list T.string) ("INetSock.fromAddr/hosts", ["0.0.0.0:7", "10.1.2.3:7", "192.0.2.255:7", "255.255.255.255:7"],
                                   fn () => List.map (fn h => parts (addr (h, 7))) ["0.0.0.0", "10.1.2.3", "192.0.2.255", "255.255.255.255"])
  val () = T.check ("INetSock.toAddr/round-trip",
                    fn () => (T.seed 17;
                              List.all (fn _ =>
                                          let
                                            val host = String.concatWith "." (List.tabulate (4, fn _ => Int.toString (T.range (0, 255))))
                                            val port = T.range (0, 65535)
                                            val (h, p) = INetSock.fromAddr (INetSock.toAddr (inAddr host, port))
                                          in h = inAddr host andalso p = port end)
                                       (List.tabulate (200, fn i => i))))
  val () = eqS ("INetSock.fromAddr/bound-socket", "127.0.0.1 true",
                fn () => S.withListener (fn l =>
                           let val (h, p) = INetSock.fromAddr (Socket.Ctl.getSockName l)
                           in NetHostDB.toString h ^ " " ^ Bool.toString (p > 0) end))
  val () = eqS ("INetSock.toAddr/connect-to-it", "connected",
                fn () => S.withListener (fn l =>
                           S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                             (Socket.connect (c, INetSock.toAddr (S.loopback (), S.portOf l));
                              let val (s, _) = Socket.accept l in Socket.close s; "connected" end))))
  (* any port "creates a socket address that fixes the port to port, but
     leaves the Internet address unspecified. This function corresponds to
     the INADDR_ANY constant", the address 0.0.0.0 *)
  val () = eqS ("INetSock.any/fromAddr", "0.0.0.0:7", fn () => parts (INetSock.any 7))
  val () = eqS ("INetSock.any/port-0", "0.0.0.0:0", fn () => parts (INetSock.any 0))
  val () = T.check ("INetSock.any/is-0.0.0.0", fn () => Socket.sameAddr (INetSock.any 9, addr ("0.0.0.0", 9)))
  (* "The values created by this function are used to bind a socket to a
     specific port." *)
  val () = eqS ("INetSock.any/bind", "0.0.0.0 true",
                fn () => udp (fn s =>
                          (Socket.bind (s, INetSock.any 0);
                           let val (h, p) = INetSock.fromAddr (Socket.Ctl.getSockName s)
                           in NetHostDB.toString h ^ " " ^ Bool.toString (p > 0) end)))
  val () = eqS ("INetSock.any/reached-through-loopback", "hello",
                fn () => udp (fn r =>
                          (Socket.bind (r, INetSock.any 0);
                           S.withSocket S.udpBound (fn s =>
                             (Socket.sendVecTo (s, INetSock.toAddr (S.loopback (), S.portOf r), S.vslice "hello");
                              if S.readable r then
                                case Socket.recvVecFromNB (r, 100) of SOME (v, _) => S.text v | NONE => "NONE"
                              else "nothing")))))
  (*>> addresses *)

  (*<< UDP *)
  (* "creates a datagram socket in the INet address family with the default
     protocol"; socket' prot: "a value of 0 is equivalent to socket()"; 17 is
     the number of UDP *)
  val () = T.check ("INetSock.UDP.socket/dgram", fn () => udp (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.dgram))
  val () = eqS ("INetSock.UDP.socket/works", "to myself", fn () => udp datagrams)
  val () = T.check ("INetSock.UDP.socket/new-each-time",
                    fn () => udp (fn a => udp (fn b => not (Socket.sameDesc (Socket.sockDesc a, Socket.sockDesc b)))))
  val () = T.check ("INetSock.UDP.socket'/zero-dgram",
                    fn () => S.withSocket (fn () => INetSock.UDP.socket' 0) (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.dgram))
  val () = eqS ("INetSock.UDP.socket'/zero-works", "to myself", fn () => S.withSocket (fn () => INetSock.UDP.socket' 0) datagrams)
  val () = eqS ("INetSock.UDP.socket'/udp-protocol", "to myself", fn () => S.withSocket (fn () => INetSock.UDP.socket' 17) datagrams)
  (*>> UDP *)

  (*<< TCP *)
  val () = T.check ("INetSock.TCP.socket/stream", fn () => tcp (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.stream))
  val () = eqS ("INetSock.TCP.socket/works", "ping pong", fn () => tcp streams)
  val () = T.check ("INetSock.TCP.socket'/zero-stream",
                    fn () => S.withSocket (fn () => INetSock.TCP.socket' 0) (fn (s : S.tcp) => Socket.Ctl.getTYPE s = Socket.SOCK.stream))
  val () = eqS ("INetSock.TCP.socket'/zero-works", "ping pong", fn () => S.withSocket (fn () => INetSock.TCP.socket' 0) streams)
  val () = eqS ("INetSock.TCP.socket'/tcp-protocol", "ping pong", fn () => S.withSocket (fn () => INetSock.TCP.socket' 6) streams)
  (* "When set to false (the default) ... When set to true, packets are sent
     as fast as possible." *)
  val () = eqB ("INetSock.TCP.getNODELAY/default", false, fn () => tcp INetSock.TCP.getNODELAY)
  val () = eqB ("INetSock.TCP.getNODELAY/listener-default", false, fn () => S.withListener INetSock.TCP.getNODELAY)
  val () = eqB ("INetSock.TCP.setNODELAY/on", true, fn () => tcp (fn s => (INetSock.TCP.setNODELAY (s, true); INetSock.TCP.getNODELAY s)))
  val () = eqB ("INetSock.TCP.setNODELAY/off-again", false,
                fn () => tcp (fn s => (INetSock.TCP.setNODELAY (s, true); INetSock.TCP.setNODELAY (s, false);
                                       INetSock.TCP.getNODELAY s)))
  val () = eqS ("INetSock.TCP.setNODELAY/connected", "true pong",
                fn () => S.withTcp (fn (c, s) =>
                           (INetSock.TCP.setNODELAY (c, true);
                            ignore (S.send (c, "pong"));
                            Bool.toString (INetSock.TCP.getNODELAY c) ^ " " ^ S.recvAll (s, 4))))
  (*>> TCP *)
end

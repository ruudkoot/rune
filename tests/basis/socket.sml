(* requires: Socket INetSock UnixSock NetHostDB Byte OS *)
(* uses: fn/sockets.sml *)
(* Socket (signature SOCKET): the address families and socket types,
   addresses, making and ending connections, and waiting for sockets.
   Expected values follow https://smlfamily.github.io/Basis/socket.html.

   Sockets are on the loopback interface, on ports the system picks, or
   pairs in the Unix domain (fn/sockets.sml); every blocking call is made
   when what it waits for is there already, so that a check that goes wrong
   fails instead of waiting. Sending and receiving are in socket_io.sml
   (streams) and socket_dgram.sml (datagrams), the options (Ctl) in
   socket_ctl.sml. *)
structure TestSocket =
struct
  structure S = Sockets
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  fun lo () = S.loopback ()

  (*<< AF *)
  val () = T.check ("Socket.AF.list/has-INET",
                    fn () => List.exists (fn (n, af) => n = "INET" andalso af = INetSock.inetAF) (Socket.AF.list ()))
  val () = T.check ("Socket.AF.list/has-UNIX",
                    fn () => List.exists (fn (n, af) => n = "UNIX" andalso af = UnixSock.unixAF) (Socket.AF.list ()))
  (* "If a pair (name,af) is in the list returned by list, then it is the
     case that name is equal to toString(af)." *)
  val () = T.check ("Socket.AF.list/names-are-toString",
                    fn () => List.all (fn (n, af) => Socket.AF.toString af = n) (Socket.AF.list ()))
  val () = T.check ("Socket.AF.fromString/inverts-list",
                    fn () => List.all (fn (n, af) => Socket.AF.fromString n = SOME af) (Socket.AF.list ()))
  (* "the expression toString (INetSock.inetAF) returns the string "INET"";
     "the Unix-domain address family is named "UNIX"" *)
  val () = eqS ("Socket.AF.toString/inet", "INET", fn () => Socket.AF.toString INetSock.inetAF)
  val () = eqS ("Socket.AF.toString/unix", "UNIX", fn () => Socket.AF.toString UnixSock.unixAF)
  val () = T.check ("Socket.AF.fromString/INET", fn () => Socket.AF.fromString "INET" = SOME INetSock.inetAF)
  val () = T.check ("Socket.AF.fromString/UNIX", fn () => Socket.AF.fromString "UNIX" = SOME UnixSock.unixAF)
  (* "fromString returns NONE if no family value corresponds to the given
     name"; the names are the C constants without the leading "AF_" *)
  val () = T.check ("Socket.AF.fromString/unknown", fn () => Socket.AF.fromString "NO_SUCH_FAMILY" = NONE)
  val () = T.check ("Socket.AF.fromString/empty", fn () => Socket.AF.fromString "" = NONE)
  val () = T.check ("Socket.AF.fromString/with-AF_-prefix", fn () => Socket.AF.fromString "AF_INET" = NONE)
  val () = T.check ("Socket.AF.list/inet-is-not-unix", fn () => INetSock.inetAF <> UnixSock.unixAF)
  (*>> AF *)

  (*<< SOCK *)
  val () = T.check ("Socket.SOCK.list/has-STREAM",
                    fn () => List.exists (fn (n, t) => n = "STREAM" andalso t = Socket.SOCK.stream) (Socket.SOCK.list ()))
  val () = T.check ("Socket.SOCK.list/has-DGRAM",
                    fn () => List.exists (fn (n, t) => n = "DGRAM" andalso t = Socket.SOCK.dgram) (Socket.SOCK.list ()))
  val () = T.check ("Socket.SOCK.list/names-are-toString",
                    fn () => List.all (fn (n, t) => Socket.SOCK.toString t = n) (Socket.SOCK.list ()))
  val () = T.check ("Socket.SOCK.fromString/inverts-list",
                    fn () => List.all (fn (n, t) => Socket.SOCK.fromString n = SOME t) (Socket.SOCK.list ()))
  val () = eqS ("Socket.SOCK.toString/stream", "STREAM", fn () => Socket.SOCK.toString Socket.SOCK.stream)
  val () = eqS ("Socket.SOCK.toString/dgram", "DGRAM", fn () => Socket.SOCK.toString Socket.SOCK.dgram)
  val () = T.check ("Socket.SOCK.fromString/STREAM", fn () => Socket.SOCK.fromString "STREAM" = SOME Socket.SOCK.stream)
  val () = T.check ("Socket.SOCK.fromString/DGRAM", fn () => Socket.SOCK.fromString "DGRAM" = SOME Socket.SOCK.dgram)
  val () = T.check ("Socket.SOCK.fromString/unknown", fn () => Socket.SOCK.fromString "NO_SUCH_TYPE" = NONE)
  val () = T.check ("Socket.SOCK.fromString/with-SOCK_-prefix", fn () => Socket.SOCK.fromString "SOCK_STREAM" = NONE)
  val () = T.check ("Socket.SOCK.stream/is-not-dgram", fn () => Socket.SOCK.stream <> Socket.SOCK.dgram)
  val () = T.check ("Socket.SOCK.stream/type-of-a-TCP-socket",
                    fn () => S.withSocket INetSock.TCP.socket (fn (s : S.tcp) => Socket.Ctl.getTYPE s = Socket.SOCK.stream))
  val () = T.check ("Socket.SOCK.dgram/type-of-a-UDP-socket",
                    fn () => S.withSocket INetSock.UDP.socket (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.dgram))
  (*>> SOCK *)

  (*<< addresses *)
  (* "tests whether two socket addresses are the same address" *)
  val () = T.check ("Socket.sameAddr/equal-addresses",
                    fn () => Socket.sameAddr (INetSock.toAddr (lo (), 80), INetSock.toAddr (lo (), 80)))
  val () = eqB ("Socket.sameAddr/other-port", false,
                fn () => Socket.sameAddr (INetSock.toAddr (lo (), 80), INetSock.toAddr (lo (), 81)))
  val () = eqB ("Socket.sameAddr/other-host", false,
                fn () => Socket.sameAddr (INetSock.toAddr (lo (), 80),
                                          INetSock.toAddr (valOf (NetHostDB.fromString "127.0.0.2"), 80)))
  val () = eqB ("Socket.sameAddr/any-is-not-loopback", false,
                fn () => Socket.sameAddr (INetSock.any 80, INetSock.toAddr (lo (), 80)))
  val () = T.check ("Socket.sameAddr/sockname-and-its-parts",
                    fn () => S.withListener (fn l => Socket.sameAddr (Socket.Ctl.getSockName l,
                                                                      INetSock.toAddr (lo (), S.portOf l))))
  val () = T.check ("Socket.sameAddr/unix-same-path",
                    fn () => Socket.sameAddr (UnixSock.toAddr "a.sock", UnixSock.toAddr "a.sock"))
  val () = eqB ("Socket.sameAddr/unix-other-path", false,
                fn () => Socket.sameAddr (UnixSock.toAddr "a.sock", UnixSock.toAddr "b.sock"))
  val () = T.check ("Socket.familyOfAddr/inet-toAddr",
                    fn () => Socket.familyOfAddr (INetSock.toAddr (lo (), 80)) = INetSock.inetAF)
  val () = T.check ("Socket.familyOfAddr/inet-any", fn () => Socket.familyOfAddr (INetSock.any 0) = INetSock.inetAF)
  val () = T.check ("Socket.familyOfAddr/inet-sockname",
                    fn () => S.withListener (fn l => Socket.familyOfAddr (Socket.Ctl.getSockName l) = INetSock.inetAF))
  val () = T.check ("Socket.familyOfAddr/unix-toAddr",
                    fn () => Socket.familyOfAddr (UnixSock.toAddr "a.sock") = UnixSock.unixAF)
  val () = T.check ("Socket.familyOfAddr/unix-sockname",
                    fn () => S.withStrm (fn (a, _) => Socket.familyOfAddr (Socket.Ctl.getSockName a) = UnixSock.unixAF))
  (*>> addresses *)

  (*<< bind-listen *)
  (* "binds the address sa to the passive socket sock": port 0 lets the
     system pick one *)
  val () = T.check ("Socket.bind/port-0-picks-a-port", fn () => S.withListener (fn l => S.portOf l > 0))
  val () = eqS ("Socket.bind/bound-host", "127.0.0.1", fn () => S.withListener (fn l => S.hostOf (Socket.Ctl.getSockName l)))
  (* "This function raises SysErr when the address sa is already in use, when
     sock is already bound to an address, or when sock has been closed." *)
  val () = T.raises ("Socket.bind/address-in-use", S.isSysErr,
                     fn () => S.withListener (fn l =>
                                S.withSocket INetSock.TCP.socket (fn (s : S.tcpListener) =>
                                  Socket.bind (s, Socket.Ctl.getSockName l))))
  val () = T.raises ("Socket.bind/already-bound", S.isSysErr,
                     fn () => S.withListener (fn l => Socket.bind (l, INetSock.toAddr (lo (), 0))))
  val () = T.raises ("Socket.bind/closed", S.isSysErr,
                     fn () => Socket.bind (S.closedTcp (), INetSock.toAddr (lo (), 0)))
  (* "requesting a queue size larger than the limit does not cause an error" *)
  val () = T.check ("Socket.listen/backlog-above-the-limit",
                    fn () => S.withSocket INetSock.TCP.socket (fn (l : S.tcpListener) =>
                               (Socket.bind (l, INetSock.toAddr (lo (), 0)); Socket.listen (l, 100000); true)))
  val () = T.check ("Socket.listen/then-connections-are-accepted",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                 (Socket.connect (c, Socket.Ctl.getSockName l);
                                  let val (s, _) = Socket.accept l in Socket.close s; true end))))
  (* "This function raises the SysErr exception if sock has been closed." *)
  val () = T.raises ("Socket.listen/closed", S.isSysErr, fn () => Socket.listen (S.closedListener (), 5))
  (*>> bind-listen *)

  (*<< accept *)
  (* "returns a pair (s,sa) consisting of a new active socket s with the same
     properties as sock and the address sa of the connecting entity" *)
  val () = T.check ("Socket.accept/address-of-the-client",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                 (Socket.connect (c, Socket.Ctl.getSockName l);
                                  let val (s, from) = Socket.accept l
                                  in Socket.close s; Socket.sameAddr (from, Socket.Ctl.getSockName c) end))))
  val () = T.check ("Socket.accept/new-socket-like-the-listener",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                 (Socket.connect (c, Socket.Ctl.getSockName l);
                                  S.using (fn () => #1 (Socket.accept l), S.quietly Socket.close) (fn s =>
                                    Socket.Ctl.getTYPE s = Socket.SOCK.stream
                                    andalso Socket.sameAddr (Socket.Ctl.getSockName s, Socket.Ctl.getSockName l)
                                    andalso Socket.sameAddr (Socket.Ctl.getPeerName s, Socket.Ctl.getSockName c))))))
  val () = eqS ("Socket.accept/new-socket-is-connected", "both ways",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "both ")); ignore (S.send (s, "ways"));
                            S.recvAll (s, 5) ^ S.recvAll (c, 4))))
  (* "extracts the first connection request from the queue" *)
  val () = T.check ("Socket.accept/first-in-the-queue",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c1 : S.tcp) =>
                                 S.withSocket INetSock.TCP.socket (fn (c2 : S.tcp) =>
                                   (Socket.connect (c1, Socket.Ctl.getSockName l);
                                    Socket.connect (c2, Socket.Ctl.getSockName l);
                                    let
                                      val (s1, from1) = Socket.accept l
                                      val (s2, from2) = Socket.accept l
                                    in
                                      S.closeAll [s1, s2];
                                      Socket.sameAddr (from1, Socket.Ctl.getSockName c1)
                                      andalso Socket.sameAddr (from2, Socket.Ctl.getSockName c2)
                                    end)))))
  (* "This function raises the SysErr exception if sock has not been properly
     bound and enabled, or it sock has been closed." *)
  val () = T.raises ("Socket.accept/not-listening", S.isSysErr,
                     fn () => S.withSocket INetSock.TCP.socket (fn (l : S.tcpListener) =>
                                (Socket.bind (l, INetSock.toAddr (lo (), 0)); ignore (Socket.accept l))))
  val () = T.raises ("Socket.accept/closed", S.isSysErr, fn () => Socket.accept (S.closedListener ()))

  (* "If there are no pending connections, then this function returns NONE." *)
  val () = eqB ("Socket.acceptNB/nothing-pending", false, fn () => S.withListener (fn l => isSome (Socket.acceptNB l)))
  val () = T.check ("Socket.acceptNB/pending",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                 (Socket.connect (c, Socket.Ctl.getSockName l);
                                  case S.eventually (fn () => Socket.acceptNB l) of
                                    SOME (s, from) => (Socket.close s; Socket.sameAddr (from, Socket.Ctl.getSockName c))
                                  | NONE => false))))
  val () = T.check ("Socket.acceptNB/queue-emptied",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                 (Socket.connect (c, Socket.Ctl.getSockName l);
                                  case S.eventually (fn () => Socket.acceptNB l) of
                                    SOME (s, _) => (Socket.close s; not (isSome (Socket.acceptNB l)))
                                  | NONE => false))))
  val () = T.raises ("Socket.acceptNB/not-listening", S.isSysErr,
                     fn () => S.withSocket INetSock.TCP.socket (fn (l : S.tcpListener) =>
                                (Socket.bind (l, INetSock.toAddr (lo (), 0)); ignore (Socket.acceptNB l))))
  val () = T.raises ("Socket.acceptNB/closed", S.isSysErr, fn () => Socket.acceptNB (S.closedListener ()))
  (*>> accept *)

  (*<< connect *)
  (* "raises the SysErr exception when ... the connection is refused ...,
     when sock is already connected, or when sock has been closed": a port
     that is bound but not listening refuses. *)
  val () = T.raises ("Socket.connect/refused", S.isSysErr,
                     fn () => S.withSocket INetSock.TCP.socket (fn (b : S.tcpListener) =>
                                (Socket.bind (b, INetSock.toAddr (lo (), 0));
                                 S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                   Socket.connect (c, Socket.Ctl.getSockName b)))))
  val () = T.raises ("Socket.connect/already-connected", S.isSysErr,
                     fn () => S.withTcp (fn (c, _) => Socket.connect (c, Socket.Ctl.getPeerName c)))
  val () = T.raises ("Socket.connect/closed", S.isSysErr, fn () => Socket.connect (S.closedTcp (), INetSock.toAddr (lo (), 9)))
  val () = T.check ("Socket.connect/peer-is-the-listener",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                 (Socket.connect (c, Socket.Ctl.getSockName l);
                                  let val (s, _) = Socket.accept l
                                  in Socket.close s; Socket.sameAddr (Socket.Ctl.getPeerName c, Socket.Ctl.getSockName l) end))))
  (* A datagram socket: "sa is the address to which datagrams are to be sent,
     and the only address from which datagrams are to be received". *)
  val () = T.check ("Socket.connect/dgram-peer",
                    fn () => S.withUdp (fn (a, b) =>
                               (Socket.connect (a, Socket.Ctl.getSockName b);
                                Socket.sameAddr (Socket.Ctl.getPeerName a, Socket.Ctl.getSockName b))))
  val () = eqS ("Socket.connect/dgram-receives-from-the-peer-only", "from b",
                fn () => S.withUdp (fn (a, b) =>
                           S.withSocket S.udpBound (fn c =>
                             (Socket.connect (a, Socket.Ctl.getSockName b);
                              Socket.sendVecTo (c, Socket.Ctl.getSockName a, S.vslice "from c");
                              Socket.sendVecTo (b, Socket.Ctl.getSockName a, S.vslice "from b");
                              S.text (#1 (Socket.recvVecFrom (a, 100)))))))

  (* "If the connection can be established without blocking the caller ...,
     then true is returned. Otherwise, false is returned and the connection
     attempt is started; one can test for the completion of the connection by
     testing the socket for writing using the select function." *)
  val () = eqS ("Socket.connectNB/stream", "up",
                fn () => S.withListener (fn l =>
                           S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                             if Socket.connectNB (c, Socket.Ctl.getSockName l) orelse S.writable c then
                               S.using (fn () => #1 (Socket.accept l), S.quietly Socket.close) (fn s =>
                                 (ignore (S.send (s, "up")); S.recvAll (c, 2)))
                             else "not connected")))
  (* "which is typically true for datagram sockets" *)
  val () = eqB ("Socket.connectNB/dgram", true, fn () => S.withUdp (fn (a, b) => Socket.connectNB (a, Socket.Ctl.getSockName b)))
  val () = T.raises ("Socket.connectNB/closed", S.isSysErr, fn () => Socket.connectNB (S.closedTcp (), INetSock.toAddr (lo (), 9)))
  (*>> connect *)

  (*<< close *)
  (* "raises the SysErr exception if the socket has already been closed" *)
  val () = T.raises ("Socket.close/twice", S.isSysErr, fn () => Socket.close (S.closedTcp ()))
  val () = T.raises ("Socket.close/twice-unix", S.isSysErr,
                     fn () => let val (a, b) = S.strmPair () in Socket.close b; Socket.close a; Socket.close a end)
  (* the other end sees the end of the stream: "If the connection has been
     closed at the other end ..., then the empty vector will be returned." *)
  val () = eqS ("Socket.close/peer-sees-the-end", "",
                fn () => S.withTcp (fn (c, s) => (Socket.close c; S.text (Socket.recvVec (s, 10)))))
  val () = eqS ("Socket.close/peer-gets-the-data-then-the-end", "last|",
                fn () => S.withStrm (fn (a, b) =>
                           (ignore (S.send (a, "last")); Socket.close a;
                            S.recvAll (b, 4) ^ "|" ^ S.text (Socket.recvVec (b, 10)))))
  val () = T.raises ("Socket.close/listener-stops-listening", S.isSysErr,
                     fn () => let
                                val l = S.tcpListener ()
                                val a = Socket.Ctl.getSockName l
                              in
                                Socket.close l;
                                S.withSocket INetSock.TCP.socket (fn (c : S.tcp) => Socket.connect (c, a))
                              end)
  (*>> close *)

  (*<< shutdown *)
  (* "If mode is NO_RECVS, further receives will be disallowed. If mode is
     NO_SENDS, further sends will be disallowed. If mode is
     NO_RECVS_OR_SENDS, further sends and receives will be disallowed." The
     other end of a socket that sends no more sees the end of the stream. *)
  val () = eqS ("Socket.shutdown/NO_SENDS-peer-sees-the-end", "",
                fn () => S.withTcp (fn (c, s) => (Socket.shutdown (c, Socket.NO_SENDS); S.text (Socket.recvVec (s, 10)))))
  val () = eqS ("Socket.NO_SENDS/data-sent-before-arrives", "data|",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (S.send (c, "data")); Socket.shutdown (c, Socket.NO_SENDS);
                            S.recvAll (s, 4) ^ "|" ^ S.text (Socket.recvVec (s, 10)))))
  val () = eqS ("Socket.NO_SENDS/still-receives", "after",
                fn () => S.withTcp (fn (c, s) =>
                           (Socket.shutdown (c, Socket.NO_SENDS); ignore (S.send (s, "after")); S.recvAll (c, 5))))
  val () = T.check ("Socket.NO_RECVS/receives-disallowed",
                    fn () => S.withTcp (fn (_, s) =>
                               (Socket.shutdown (s, Socket.NO_RECVS);
                                (case Socket.recvVecNB (s, 10) of SOME v => Word8Vector.length v = 0 | NONE => false)
                                handle OS.SysErr _ => true)))
  val () = eqS ("Socket.NO_RECVS/still-sends", "out",
                fn () => S.withTcp (fn (c, s) =>
                           (Socket.shutdown (s, Socket.NO_RECVS); ignore (S.send (s, "out")); S.recvAll (c, 3))))
  val () = eqS ("Socket.NO_RECVS_OR_SENDS/peer-sees-the-end", "",
                fn () => S.withTcp (fn (c, s) =>
                           (Socket.shutdown (s, Socket.NO_RECVS_OR_SENDS); S.text (Socket.recvVec (c, 10)))))
  val () = T.check ("Socket.NO_RECVS_OR_SENDS/receives-disallowed",
                    fn () => S.withTcp (fn (_, s) =>
                               (Socket.shutdown (s, Socket.NO_RECVS_OR_SENDS);
                                (case Socket.recvVecNB (s, 10) of SOME v => Word8Vector.length v = 0 | NONE => false)
                                handle OS.SysErr _ => true)))
  val () = eqS ("Socket.shutdown/unix-NO_SENDS", "",
                fn () => S.withStrm (fn (a, b) => (Socket.shutdown (a, Socket.NO_SENDS); S.text (Socket.recvVec (b, 10)))))
  (* "This function raises the SysErr exception if the socket is not
     connected or has been closed." *)
  val () = T.raises ("Socket.shutdown/not-connected", S.isSysErr,
                     fn () => S.withSocket INetSock.TCP.socket (fn (s : S.tcp) => Socket.shutdown (s, Socket.NO_SENDS)))
  val () = T.raises ("Socket.shutdown/closed", S.isSysErr,
                     fn () => Socket.shutdown (S.closedTcp (), Socket.NO_RECVS_OR_SENDS))
  (*>> shutdown *)

  (*<< descriptors *)
  (* "the expression sameDesc(sockDesc sock, sockDesc sock) will always
     return true for any socket sock" *)
  val () = T.check ("Socket.sockDesc/sameDesc-of-itself",
                    fn () => S.withListener (fn l => Socket.sameDesc (Socket.sockDesc l, Socket.sockDesc l)))
  val () = T.check ("Socket.sameDesc/same-socket",
                    fn () => S.withStrm (fn (a, _) => let val d = Socket.sockDesc a in Socket.sameDesc (d, Socket.sockDesc a) end))
  val () = eqB ("Socket.sameDesc/different-sockets", false,
                fn () => S.withTcp (fn (c, s) => Socket.sameDesc (Socket.sockDesc c, Socket.sockDesc s)))
  val () = eqB ("Socket.sameDesc/pair", false,
                fn () => S.withStrm (fn (a, b) => Socket.sameDesc (Socket.sockDesc a, Socket.sockDesc b)))

  (* "returns the I/O descriptor corresponding to socket sock. This
     descriptor can be used to poll the socket via pollDesc and poll in the
     OS.IO structure." *)
  val () = T.check ("Socket.ioDesc/kind-is-socket",
                    fn () => S.withTcp (fn (c, _) => OS.IO.kind (Socket.ioDesc c) = OS.IO.Kind.socket))
  val () = T.check ("Socket.ioDesc/kind-is-socket-unix",
                    fn () => S.withStrm (fn (a, _) => OS.IO.kind (Socket.ioDesc a) = OS.IO.Kind.socket))
  val () = T.check ("Socket.ioDesc/same-socket",
                    fn () => S.withTcp (fn (c, _) => OS.IO.compare (Socket.ioDesc c, Socket.ioDesc c) = EQUAL))
  val () = T.check ("Socket.ioDesc/different-sockets",
                    fn () => S.withTcp (fn (c, s) => OS.IO.compare (Socket.ioDesc c, Socket.ioDesc s) <> EQUAL))
  val () = T.check ("Socket.ioDesc/poll",
                    fn () => S.withTcp (fn (c, s) =>
                               (ignore (S.send (c, "x"));
                                case OS.IO.pollDesc (Socket.ioDesc s) of
                                  SOME pd => (case OS.IO.poll ([OS.IO.pollIn pd], SOME S.patience) of
                                                [info] => OS.IO.isIn info
                                              | _ => false)
                                | NONE => false)))
  (*>> descriptors *)

  (*<< select *)
  fun select (rds, wrs, exs, timeout) = Socket.select {rds = rds, wrs = wrs, exs = exs, timeout = timeout}
  fun sizes {rds, wrs, exs} = (length rds, length wrs, length exs)
  val eqSizes = T.eq (T.triple (T.int, T.int, T.int))
  fun desc s = Socket.sockDesc s
  (* ds names the sockets ss, in their order *)
  fun names (ds, ss) = length ds = length ss andalso ListPair.all (fn (d, s) => Socket.sameDesc (d, desc s)) (ds, ss)

  (* "A timeout is signified by a result of three empty lists." *)
  val () = eqSizes ("Socket.select/timeout", (0, 0, 0),
                    fn () => S.withTcp (fn (_, s) => sizes (select ([desc s], [], [desc s], SOME (Time.fromReal 0.1)))))
  (* "The calling program is blocked until either one or more of the named
     sockets is "ready" or the specified timeout expires" *)
  val () = T.check ("Socket.select/timeout-waits",
                    fn () => S.withTcp (fn (_, s) =>
                               let val start = Time.now ()
                               in
                                 ignore (select ([desc s], [], [], SOME (Time.fromReal 0.2)));
                                 Time.>= (Time.- (Time.now (), start), Time.fromReal 0.15)
                               end))
  val () = eqSizes ("Socket.select/zero-timeout", (0, 0, 0),
                    fn () => S.withTcp (fn (_, s) => sizes (select ([desc s], [], [], SOME Time.zeroTime))))
  val () = eqSizes ("Socket.select/no-sockets", (0, 0, 0), fn () => sizes (select ([], [], [], SOME (Time.fromReal 0.01))))
  val () = T.check ("Socket.select/readable",
                    fn () => S.withTcp (fn (c, s) =>
                               (ignore (S.send (c, "x")); names (#rds (select ([desc s], [], [], SOME S.patience)), [s]))))
  (* "a timeout of NONE never expires": a socket that is ready ends the wait *)
  val () = T.check ("Socket.select/no-timeout",
                    fn () => S.withStrm (fn (a, b) => (ignore (S.send (a, "x")); names (#rds (select ([desc b], [], [], NONE)), [b]))))
  val () = T.check ("Socket.select/writable",
                    fn () => S.withTcp (fn (c, _) => names (#wrs (select ([], [desc c], [], SOME Time.zeroTime)), [c])))
  val () = T.check ("Socket.select/only-the-ready-ones",
                    fn () => S.withStrm (fn (a, b) =>
                               S.withStrm (fn (_, y) =>
                                 (ignore (S.send (a, "x"));
                                  names (#rds (select ([desc y, desc b], [], [], SOME S.patience)), [b])))))
  val () = T.check ("Socket.select/in-two-lists",
                    fn () => S.withStrm (fn (a, b) =>
                               (ignore (S.send (a, "x"));
                                let val r = select ([desc b], [desc b], [], SOME S.patience)
                                in names (#rds r, [b]) andalso names (#wrs r, [b]) end)))
  (* "The order in which socket descriptors appear in the argument lists is
     preserved in the result lists." *)
  val () = T.check ("Socket.select/order-preserved",
                    fn () => S.withStrm (fn (a1, b1) =>
                               S.withStrm (fn (a2, b2) =>
                                 S.withStrm (fn (a3, b3) =>
                                   (List.app (fn a => ignore (S.send (a, "x"))) [a1, a2, a3];
                                    names (#rds (select (map desc [b2, b3, b1], [], [], SOME Time.zeroTime)), [b2, b3, b1])
                                    andalso names (#rds (select (map desc [b1, b3, b2], [], [], SOME Time.zeroTime)), [b1, b3, b2])
                                    andalso names (#wrs (select ([], map desc [a3, a1, b2], [], SOME Time.zeroTime)), [a3, a1, b2]))))))
  (* "one can test for pending connection requests by using the select
     function to test the socket for reading" *)
  val () = T.check ("Socket.select/listener-readable-when-a-connection-is-pending",
                    fn () => S.withListener (fn l =>
                               S.withSocket INetSock.TCP.socket (fn (c : S.tcp) =>
                                 let val idle = sizes (select ([desc l], [], [], SOME Time.zeroTime))
                                 in Socket.connect (c, Socket.Ctl.getSockName l); idle = (0, 0, 0) andalso S.readable l end)))
  (* "This function raises SysErr if any of the argument sockets have been
     closed or if the timeout value is negative." The socket is readable, so
     that a negative timeout taken for "no timeout" does not wait. *)
  val () = T.raises ("Socket.select/closed", S.isSysErr,
                     fn () => select ([desc (S.closedTcp ())], [], [], SOME Time.zeroTime))
  val () = T.raises ("Socket.select/negative-timeout", S.isSysErr,
                     fn () => S.withStrm (fn (a, b) =>
                                (ignore (S.send (a, "x")); select ([desc b], [], [], SOME (Time.fromReal ~1.0)))))
  (*>> select *)
end

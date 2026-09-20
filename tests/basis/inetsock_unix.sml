(* requires: UnixSock Socket Byte OS *)
(* uses: fn/sockets.sml *)
(* UnixSock (signature UNIX_SOCK): addresses in the file system and the
   sockets of the Unix domain. Expected values follow
   https://smlfamily.github.io/Basis/unix-sock.html. Names are relative to
   the current directory and removed before and after use
   (fn/sockets.sml). *)
structure TestUnixSock =
struct
  structure S = Sockets
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  fun exists path = OS.FileSys.access (path, [])
  fun strm f = S.withSocket UnixSock.Strm.socket (fn (s : S.strm) => f s)
  fun dgrm f = S.withSocket UnixSock.DGrm.socket (fn (s : S.dgrm) => f s)
  (* both ways over a connected pair *)
  fun exchange (a : S.strm, b : S.strm) : string =
    (ignore (S.send (a, "ping")); ignore (S.send (b, "pong")); S.recvAll (b, 4) ^ " " ^ S.recvAll (a, 4))
  (* the next message r receives, once it is readable *)
  fun message (r : S.dgrm) : string =
    if S.readable r then
      case Socket.recvVecFromNB (r, 100) of SOME (v, _) => S.text v | NONE => "NONE"
    else "nothing"

  (*<< unixAF *)
  (* "The Unix address family value", named "UNIX" (socket.html) *)
  val () = eqS ("UnixSock.unixAF/named-UNIX", "UNIX", fn () => Socket.AF.toString UnixSock.unixAF)
  val () = T.check ("UnixSock.unixAF/fromString-UNIX", fn () => Socket.AF.fromString "UNIX" = SOME UnixSock.unixAF)
  (*>> unixAF *)

  (*<< addresses *)
  (* toAddr s "converts a pathname s into a socket address (in the Unix
     address family); it does not check the validity of the path s";
     fromAddr "returns the Unix file system path corresponding to the
     Unix-domain socket address addr" *)
  val () = eqS ("UnixSock.toAddr/fromAddr", "some/dir/x.sock", fn () => UnixSock.fromAddr (UnixSock.toAddr "some/dir/x.sock"))
  val () = eqS ("UnixSock.toAddr/not-checked", "/no/such/directory/x.sock",
                fn () => UnixSock.fromAddr (UnixSock.toAddr "/no/such/directory/x.sock"))
  val () = eqS ("UnixSock.fromAddr/bound-socket", "bound.sock",
                fn () => S.withPath "bound.sock" (fn path =>
                           strm (fn s => (Socket.bind (s, UnixSock.toAddr path); UnixSock.fromAddr (Socket.Ctl.getSockName s)))))
  (* "Binding a name to a Unix-domain socket with bind causes a socket file to
     be created in the filesystem. This file is not removed when the socket is
     closed; OS.FileSys.remove must be used to remove the file." *)
  val () = eqS ("UnixSock.toAddr/bind-creates-the-file", "false true true false",
                fn () => S.withPath "file.sock" (fn path =>
                           let
                             val before' = exists path
                             val s : S.strm = UnixSock.Strm.socket ()
                             val bound = (Socket.bind (s, UnixSock.toAddr path); exists path)
                                         handle e => (Socket.close s; raise e)
                             val () = Socket.close s
                             val closed = exists path
                             val () = OS.FileSys.remove path
                           in String.concatWith " " (List.map Bool.toString [before', bound, closed, exists path]) end))
  (*>> addresses *)

  (*<< Strm *)
  (* "This function creates a stream socket in the Unix address family." *)
  val () = T.check ("UnixSock.Strm.socket/stream", fn () => strm (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.stream))
  val () = eqS ("UnixSock.Strm.socket/listen-connect-accept", "ping pong strm.sock",
                fn () => S.withPath "strm.sock" (fn path =>
                           S.withSocket UnixSock.Strm.socket (fn (l : Socket.passive UnixSock.stream_sock) =>
                             (Socket.bind (l, UnixSock.toAddr path);
                              Socket.listen (l, 4);
                              strm (fn c =>
                                (Socket.connect (c, UnixSock.toAddr path);
                                 S.using (fn () => #1 (Socket.accept l), S.quietly Socket.close) (fn s =>
                                   exchange (c, s) ^ " " ^ UnixSock.fromAddr (Socket.Ctl.getPeerName c))))))))
  (* "creates an unnamed pair of connected stream sockets ... unlike pipe, the
     sockets are bidirectional" *)
  val () = eqS ("UnixSock.Strm.socketPair/bidirectional", "ping pong", fn () => S.withStrm exchange)
  val () = T.check ("UnixSock.Strm.socketPair/stream",
                    fn () => S.withStrm (fn (a, b) => Socket.Ctl.getTYPE a = Socket.SOCK.stream
                                                      andalso Socket.Ctl.getTYPE b = Socket.SOCK.stream))
  val () = T.check ("UnixSock.Strm.socketPair/two-sockets",
                    fn () => S.withStrm (fn (a, b) => not (Socket.sameDesc (Socket.sockDesc a, Socket.sockDesc b))))
  val () = T.check ("UnixSock.Strm.socketPair/connected-to-each-other",
                    fn () => S.withStrm (fn (a, b) => Socket.sameAddr (Socket.Ctl.getPeerName a, Socket.Ctl.getSockName b)))
  (*>> Strm *)

  (*<< DGrm *)
  (* "This function creates a datagram socket in the Unix address family." *)
  val () = T.check ("UnixSock.DGrm.socket/dgram", fn () => dgrm (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.dgram))
  val () = eqS ("UnixSock.DGrm.socket/to-a-name", "hi",
                fn () => S.withPath "dgrm.sock" (fn path =>
                           dgrm (fn r =>
                             dgrm (fn s =>
                               (Socket.bind (r, UnixSock.toAddr path);
                                Socket.sendVecTo (s, UnixSock.toAddr path, S.vslice "hi");
                                message r)))))
  val () = eqS ("UnixSock.fromAddr/sender-of-a-message", "sender.sock",
                fn () => S.withPath "receiver.sock" (fn rpath =>
                           S.withPath "sender.sock" (fn spath =>
                             dgrm (fn r =>
                               dgrm (fn s =>
                                 (Socket.bind (r, UnixSock.toAddr rpath); Socket.bind (s, UnixSock.toAddr spath);
                                  Socket.sendVecTo (s, UnixSock.toAddr rpath, S.vslice "hi");
                                  if S.readable r then
                                    case Socket.recvVecFromNB (r, 100) of
                                      SOME (_, from) => UnixSock.fromAddr from
                                    | NONE => "NONE"
                                  else "nothing"))))))
  (* "creates an unnamed pair of connected datagram sockets" *)
  val () = T.check ("UnixSock.DGrm.socketPair/dgram",
                    fn () => S.withDgrm (fn (a, b) => Socket.Ctl.getTYPE a = Socket.SOCK.dgram
                                                      andalso Socket.Ctl.getTYPE b = Socket.SOCK.dgram))
  val () = T.check ("UnixSock.DGrm.socketPair/connected-to-each-other",
                    fn () => S.withDgrm (fn (a, b) => Socket.sameAddr (Socket.Ctl.getPeerName a, Socket.Ctl.getSockName b)))
  (* once one of them has a name, the other can send to it *)
  val () = eqS ("UnixSock.DGrm.socketPair/named-peer", "pair.sock hello",
                fn () => S.withPath "pair.sock" (fn path =>
                           S.withDgrm (fn (a, b) =>
                             (Socket.bind (b, UnixSock.toAddr path);
                              Socket.sendVecTo (a, UnixSock.toAddr path, S.vslice "hello");
                              UnixSock.fromAddr (Socket.Ctl.getPeerName a) ^ " " ^ message b))))
  (*>> DGrm *)
end

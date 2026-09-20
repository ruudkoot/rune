(* requires: Socket INetSock UnixSock NetHostDB Byte *)
(* uses: fn/sockets.sml *)
(* Socket.Ctl (the substructure Ctl of signature SOCKET): the options of a
   socket and its addresses. Expected values follow
   https://smlfamily.github.io/Basis/socket.html; the defaults are those of
   the C socket interface, where every flag starts off.

   setDEBUG is only tried with false: turning SO_DEBUG on needs privileges
   (Linux answers EACCES to anyone else). The buffer sizes are only checked
   to be at least what was asked for, since a system may add room for its
   own use (Linux doubles them). *)
structure TestSocketCtl =
struct
  structure S = Sockets
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqI = T.eq T.int
  val eqOS = T.eq (T.option T.string)
  fun tcp f = S.withSocket INetSock.TCP.socket (fn (s : S.tcp) => f s)
  fun udp f = S.withSocket INetSock.UDP.socket (fn (s : S.udp) => f s)
  fun linger (t : Time.time option) : string option = Option.map Time.toString t
  fun set (setter, getter) v s = (setter (s, v); getter s)

  (*<< flags *)
  val () = eqB ("Socket.Ctl.getDEBUG/default", false, fn () => tcp Socket.Ctl.getDEBUG)
  val () = eqB ("Socket.Ctl.setDEBUG/off", false, fn () => tcp (set (Socket.Ctl.setDEBUG, Socket.Ctl.getDEBUG) false))
  (* "When true, this flag instructs the system to allow reuse of local
     socket addresses in bind calls." *)
  val () = eqB ("Socket.Ctl.getREUSEADDR/default", false, fn () => tcp Socket.Ctl.getREUSEADDR)
  val () = eqB ("Socket.Ctl.setREUSEADDR/on", true, fn () => tcp (set (Socket.Ctl.setREUSEADDR, Socket.Ctl.getREUSEADDR) true))
  val () = eqB ("Socket.Ctl.setREUSEADDR/off-again", false,
                fn () => tcp (fn s => (Socket.Ctl.setREUSEADDR (s, true); set (Socket.Ctl.setREUSEADDR, Socket.Ctl.getREUSEADDR) false s)))
  val () = eqB ("Socket.Ctl.getKEEPALIVE/default", false, fn () => tcp Socket.Ctl.getKEEPALIVE)
  val () = eqB ("Socket.Ctl.setKEEPALIVE/on", true, fn () => tcp (set (Socket.Ctl.setKEEPALIVE, Socket.Ctl.getKEEPALIVE) true))
  val () = eqB ("Socket.Ctl.setKEEPALIVE/off-again", false,
                fn () => tcp (fn s => (Socket.Ctl.setKEEPALIVE (s, true); set (Socket.Ctl.setKEEPALIVE, Socket.Ctl.getKEEPALIVE) false s)))
  val () = eqB ("Socket.Ctl.getDONTROUTE/default", false, fn () => udp Socket.Ctl.getDONTROUTE)
  val () = eqB ("Socket.Ctl.setDONTROUTE/on", true, fn () => udp (set (Socket.Ctl.setDONTROUTE, Socket.Ctl.getDONTROUTE) true))
  val () = eqB ("Socket.Ctl.setDONTROUTE/off-again", false,
                fn () => udp (fn s => (Socket.Ctl.setDONTROUTE (s, true); set (Socket.Ctl.setDONTROUTE, Socket.Ctl.getDONTROUTE) false s)))
  val () = eqB ("Socket.Ctl.getBROADCAST/default", false, fn () => udp Socket.Ctl.getBROADCAST)
  val () = eqB ("Socket.Ctl.setBROADCAST/on", true, fn () => udp (set (Socket.Ctl.setBROADCAST, Socket.Ctl.getBROADCAST) true))
  val () = eqB ("Socket.Ctl.setBROADCAST/off-again", false,
                fn () => udp (fn s => (Socket.Ctl.setBROADCAST (s, true); set (Socket.Ctl.setBROADCAST, Socket.Ctl.getBROADCAST) false s)))
  val () = eqB ("Socket.Ctl.getOOBINLINE/default", false, fn () => tcp Socket.Ctl.getOOBINLINE)
  val () = eqB ("Socket.Ctl.setOOBINLINE/on", true, fn () => tcp (set (Socket.Ctl.setOOBINLINE, Socket.Ctl.getOOBINLINE) true))
  val () = eqB ("Socket.Ctl.setOOBINLINE/off-again", false,
                fn () => tcp (fn s => (Socket.Ctl.setOOBINLINE (s, true); set (Socket.Ctl.setOOBINLINE, Socket.Ctl.getOOBINLINE) false s)))
  (* "When set, this indicates that out-of-band data should be placed in the
     normal input queue of the socket." *)
  val () = eqS ("Socket.Ctl.setOOBINLINE/urgent-byte-in-the-stream", "abc",
                fn () => S.withTcp (fn (c, s) =>
                           (Socket.Ctl.setOOBINLINE (s, true);
                            ignore (Socket.sendVec' (c, S.vslice "abc", {don't_route = false, oob = true}));
                            S.recvAll (s, 3))))
  (*>> flags *)

  (*<< buffers *)
  val () = T.check ("Socket.Ctl.getSNDBUF/positive", fn () => tcp (fn s => Socket.Ctl.getSNDBUF s > 0))
  val () = T.check ("Socket.Ctl.setSNDBUF/at-least-the-size",
                    fn () => tcp (fn s => set (Socket.Ctl.setSNDBUF, Socket.Ctl.getSNDBUF) 16384 s >= 16384))
  val () = T.check ("Socket.Ctl.setSNDBUF/larger",
                    fn () => tcp (fn s =>
                               let val small = set (Socket.Ctl.setSNDBUF, Socket.Ctl.getSNDBUF) 8192 s
                               in set (Socket.Ctl.setSNDBUF, Socket.Ctl.getSNDBUF) 65536 s > small end))
  val () = T.check ("Socket.Ctl.getRCVBUF/positive", fn () => udp (fn s => Socket.Ctl.getRCVBUF s > 0))
  val () = T.check ("Socket.Ctl.setRCVBUF/at-least-the-size",
                    fn () => udp (fn s => set (Socket.Ctl.setRCVBUF, Socket.Ctl.getRCVBUF) 16384 s >= 16384))
  val () = T.check ("Socket.Ctl.setRCVBUF/larger",
                    fn () => udp (fn s =>
                               let val small = set (Socket.Ctl.setRCVBUF, Socket.Ctl.getRCVBUF) 8192 s
                               in set (Socket.Ctl.setRCVBUF, Socket.Ctl.getRCVBUF) 65536 s > small end))
  (*>> buffers *)

  (*<< linger *)
  (* "If the flag is set to NONE, then the system will close the socket as
     quickly as possible ... If the flag is set to SOME(t) ..., then the
     system will block the close operation until the data is delivered or the
     timeout t expires. If t is negative or too large, then the Time is
     raised." *)
  val () = eqOS ("Socket.Ctl.getLINGER/default", NONE, fn () => tcp (linger o Socket.Ctl.getLINGER))
  val () = eqOS ("Socket.Ctl.setLINGER/some", SOME "5.000",
                 fn () => tcp (fn s => (Socket.Ctl.setLINGER (s, SOME (Time.fromSeconds (LargeInt.fromInt 5))); linger (Socket.Ctl.getLINGER s))))
  val () = eqOS ("Socket.Ctl.setLINGER/zero", SOME "0.000",
                 fn () => tcp (fn s => (Socket.Ctl.setLINGER (s, SOME Time.zeroTime); linger (Socket.Ctl.getLINGER s))))
  val () = eqOS ("Socket.Ctl.setLINGER/none-again", NONE,
                 fn () => tcp (fn s => (Socket.Ctl.setLINGER (s, SOME (Time.fromSeconds (LargeInt.fromInt 5)));
                                        Socket.Ctl.setLINGER (s, NONE); linger (Socket.Ctl.getLINGER s))))
  val () = T.raises ("Socket.Ctl.setLINGER/negative", fn Time.Time => true | _ => false,
                     fn () => tcp (fn s => Socket.Ctl.setLINGER (s, SOME (Time.fromReal ~1.0))))
  val () = T.raises ("Socket.Ctl.setLINGER/too-large", fn Time.Time => true | _ => false,
                     fn () => tcp (fn s => Socket.Ctl.setLINGER (s, SOME (Time.fromReal 1E15))))
  (*>> linger *)

  (*<< type-error *)
  (* "This returns the socket type of the socket." *)
  val () = T.check ("Socket.Ctl.getTYPE/tcp", fn () => tcp (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.stream))
  val () = T.check ("Socket.Ctl.getTYPE/udp", fn () => udp (fn s => Socket.Ctl.getTYPE s = Socket.SOCK.dgram))
  val () = T.check ("Socket.Ctl.getTYPE/unix-stream", fn () => S.withStrm (fn (a, _) => Socket.Ctl.getTYPE a = Socket.SOCK.stream))
  val () = T.check ("Socket.Ctl.getTYPE/unix-dgram", fn () => S.withDgrm (fn (a, _) => Socket.Ctl.getTYPE a = Socket.SOCK.dgram))
  (* "This indicates whether or not an error has occurred." A UDP socket
     connected to a port nobody listens on learns (from the ICMP answer to
     what it sends) that the port is unreachable. *)
  val () = eqB ("Socket.Ctl.getERROR/fresh", false, fn () => tcp Socket.Ctl.getERROR)
  val () = eqB ("Socket.Ctl.getERROR/port-unreachable", true,
                fn () => S.withUdp (fn (a, b) =>
                           let val to = Socket.Ctl.getSockName b
                           in
                             Socket.close b;
                             Socket.connect (a, to);
                             Socket.sendVecTo (a, to, S.vslice "anyone?");
                             isSome (S.eventually (fn () => if Socket.Ctl.getERROR a then SOME () else NONE))
                           end))
  (*>> type-error *)

  (*<< names *)
  (* getPeerName "returns the socket address to which the socket is
     connected"; getSockName "the socket address to which the socket is
     bound" *)
  val () = T.check ("Socket.Ctl.getSockName/bound",
                    fn () => S.withListener (fn l =>
                               Socket.sameAddr (Socket.Ctl.getSockName l, INetSock.toAddr (S.loopback (), S.portOf l))))
  val () = T.check ("Socket.Ctl.getSockName/client-is-peer-of-session",
                    fn () => S.withTcp (fn (c, s) => Socket.sameAddr (Socket.Ctl.getSockName c, Socket.Ctl.getPeerName s)))
  val () = T.check ("Socket.Ctl.getPeerName/session-is-peer-of-client",
                    fn () => S.withTcp (fn (c, s) => Socket.sameAddr (Socket.Ctl.getPeerName c, Socket.Ctl.getSockName s)))
  val () = eqS ("Socket.Ctl.getPeerName/loopback", "127.0.0.1", fn () => S.withTcp (fn (c, _) => S.hostOf (Socket.Ctl.getPeerName c)))
  val () = T.check ("Socket.Ctl.getPeerName/dgram-connected",
                    fn () => S.withUdp (fn (a, b) =>
                               (Socket.connect (a, Socket.Ctl.getSockName b);
                                Socket.sameAddr (Socket.Ctl.getPeerName a, Socket.Ctl.getSockName b))))
  val () = T.check ("Socket.Ctl.getPeerName/unix-pair",
                    fn () => S.withStrm (fn (a, b) => Socket.sameAddr (Socket.Ctl.getPeerName a, Socket.Ctl.getSockName b)))
  (*>> names *)

  (*<< nread-atmark *)
  (* getNREAD "returns the number of bytes available for reading on the
     socket" *)
  val () = eqI ("Socket.Ctl.getNREAD/nothing", 0, fn () => S.withTcp (fn (c, _) => Socket.Ctl.getNREAD c))
  val () = eqI ("Socket.Ctl.getNREAD/five-bytes", 5,
                fn () => S.withTcp (fn (c, s) => (ignore (S.send (c, "12345")); if S.readable s then Socket.Ctl.getNREAD s else ~1)))
  val () = eqI ("Socket.Ctl.getNREAD/after-reading-two", 3,
                fn () => S.withTcp (fn (c, s) => (ignore (S.send (c, "12345")); ignore (S.recvAll (s, 2)); Socket.Ctl.getNREAD s)))
  (* getATMARK "indicates whether or not the read pointer on the socket is
     currently at the out-of-band mark": "abc" sent with oob puts the mark
     after "ab" *)
  val () = eqS ("Socket.Ctl.getATMARK/before-and-at-the-mark", "false true",
                fn () => S.withTcp (fn (c, s) =>
                           (ignore (Socket.sendVec' (c, S.vslice "abc", {don't_route = false, oob = true}));
                            if S.readable s then
                              let val early = Socket.Ctl.getATMARK s
                              in ignore (S.recvAll (s, 2)); Bool.toString early ^ " " ^ Bool.toString (Socket.Ctl.getATMARK s) end
                            else "nothing")))
  val () = eqB ("Socket.Ctl.getATMARK/no-urgent-data", false,
                fn () => S.withTcp (fn (c, s) => (ignore (S.send (c, "x")); ignore (S.recvAll (s, 1)); Socket.Ctl.getATMARK s)))
  (*>> nread-atmark *)

  (*<< closed *)
  (* "These functions raise the SysErr exception when the argument socket has
     been closed." *)
  fun closed (label, f) = T.raises (label, S.isSysErr, fn () => f (S.closedTcp ()))
  val () = closed ("Socket.Ctl.getDEBUG/closed", Socket.Ctl.getDEBUG)
  val () = closed ("Socket.Ctl.setDEBUG/closed", (fn s => Socket.Ctl.setDEBUG (s, false)))
  val () = closed ("Socket.Ctl.getREUSEADDR/closed", Socket.Ctl.getREUSEADDR)
  val () = closed ("Socket.Ctl.setREUSEADDR/closed", (fn s => Socket.Ctl.setREUSEADDR (s, true)))
  val () = closed ("Socket.Ctl.getKEEPALIVE/closed", Socket.Ctl.getKEEPALIVE)
  val () = closed ("Socket.Ctl.setKEEPALIVE/closed", (fn s => Socket.Ctl.setKEEPALIVE (s, true)))
  val () = closed ("Socket.Ctl.getDONTROUTE/closed", Socket.Ctl.getDONTROUTE)
  val () = closed ("Socket.Ctl.setDONTROUTE/closed", (fn s => Socket.Ctl.setDONTROUTE (s, true)))
  val () = closed ("Socket.Ctl.getLINGER/closed", Socket.Ctl.getLINGER)
  val () = closed ("Socket.Ctl.setLINGER/closed", (fn s => Socket.Ctl.setLINGER (s, SOME (Time.fromSeconds (LargeInt.fromInt 1)))))
  val () = closed ("Socket.Ctl.getBROADCAST/closed", Socket.Ctl.getBROADCAST)
  val () = closed ("Socket.Ctl.setBROADCAST/closed", (fn s => Socket.Ctl.setBROADCAST (s, true)))
  val () = closed ("Socket.Ctl.getOOBINLINE/closed", Socket.Ctl.getOOBINLINE)
  val () = closed ("Socket.Ctl.setOOBINLINE/closed", (fn s => Socket.Ctl.setOOBINLINE (s, true)))
  val () = closed ("Socket.Ctl.getSNDBUF/closed", Socket.Ctl.getSNDBUF)
  val () = closed ("Socket.Ctl.setSNDBUF/closed", (fn s => Socket.Ctl.setSNDBUF (s, 16384)))
  val () = closed ("Socket.Ctl.getRCVBUF/closed", Socket.Ctl.getRCVBUF)
  val () = closed ("Socket.Ctl.setRCVBUF/closed", (fn s => Socket.Ctl.setRCVBUF (s, 16384)))
  val () = closed ("Socket.Ctl.getTYPE/closed", Socket.Ctl.getTYPE)
  val () = closed ("Socket.Ctl.getERROR/closed", Socket.Ctl.getERROR)
  val () = closed ("Socket.Ctl.getPeerName/closed", Socket.Ctl.getPeerName)
  val () = closed ("Socket.Ctl.getSockName/closed", Socket.Ctl.getSockName)
  val () = closed ("Socket.Ctl.getNREAD/closed", Socket.Ctl.getNREAD)
  val () = closed ("Socket.Ctl.getATMARK/closed", Socket.Ctl.getATMARK)
  (*>> closed *)
end

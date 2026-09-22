(* requires: INet6Sock Socket Byte *)
(* uses: fn/sockets.sml *)
(* INet6Sock (signature INET6_SOCK, Rune's own): addresses of the Internet
   domain over IPv6 and its UDP and TCP sockets. The specification has no
   IPv6, so the expectations here are those of `INET_SOCK` read for 128-bit
   addresses, and the text forms are those of `inet_ntop` and `inet_pton`.
   A machine without IPv6 is not a failure: the checks that need one are
   skipped when the loopback address cannot be bound. *)
structure TestINet6Sock =
struct
  structure S = Sockets
  type tcp6 = Socket.active INet6Sock.stream_sock
  type listener6 = Socket.passive INet6Sock.stream_sock
  type udp6 = INet6Sock.dgram_sock
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqO = T.eq (T.option T.string)
  fun addr6 s = valOf (INet6Sock.fromString s)
  fun parts a = let val (h, p) = INet6Sock.fromAddr a in INet6Sock.toString h ^ " " ^ Int.toString p end

  (* the machine has IPv6 when a socket can be bound to ::1 *)
  val works =
    (S.withSocket INet6Sock.TCP.socket
       (fn (s : listener6) => (Socket.bind (s, INet6Sock.toAddr (addr6 "::1", 0)); true)))
    handle _ => false

  (*<< text *)
  (* the text of an address is what inet_ntop writes: the longest run of
     zeros as "::", the rest in lower-case hexadecimal *)
  val () = eqO ("INet6Sock.toString/loopback", SOME "::1", fn () => Option.map INet6Sock.toString (INet6Sock.fromString "::1"))
  val () = eqO ("INet6Sock.toString/canonical", SOME "::1",
                fn () => Option.map INet6Sock.toString (INet6Sock.fromString "0:0:0:0:0:0:0:1"))
  val () = eqO ("INet6Sock.toString/unspecified", SOME "::", fn () => Option.map INet6Sock.toString (INet6Sock.fromString "::"))
  val () = eqO ("INet6Sock.toString/full", SOME "fe80::1", fn () => Option.map INet6Sock.toString (INet6Sock.fromString "fe80:0:0:0:0:0:0:1"))
  val () = eqB ("INet6Sock.fromString/same-address", true,
                fn () => INet6Sock.fromString "::1" = INet6Sock.fromString "0:0:0:0:0:0:0:1")
  val () = eqB ("INet6Sock.fromString/other-address", false,
                fn () => INet6Sock.fromString "::1" = INet6Sock.fromString "::2")
  (* an IPv4 address is no IPv6 address, but its mapped form is *)
  val () = eqO ("INet6Sock.fromString/not-an-IPv4-address", NONE,
                fn () => Option.map INet6Sock.toString (INet6Sock.fromString "127.0.0.1"))
  val () = eqO ("INet6Sock.fromString/mapped-IPv4", SOME "::ffff:127.0.0.1",
                fn () => Option.map INet6Sock.toString (INet6Sock.fromString "::ffff:127.0.0.1"))
  val () = eqO ("INet6Sock.fromString/not-an-address", NONE,
                fn () => Option.map INet6Sock.toString (INet6Sock.fromString "not an address"))
  val () = eqO ("INet6Sock.fromString/trailing-text", NONE,
                fn () => Option.map INet6Sock.toString (INet6Sock.fromString "::1 and more"))
  (*>> text *)

  (*<< af *)
  (* the family's name is "INET6", and Socket.AF knows it *)
  val () = eqS ("INet6Sock.inet6AF/named-INET6", "INET6", fn () => Socket.AF.toString INet6Sock.inet6AF)
  val () = eqB ("INet6Sock.inet6AF/fromString-INET6", true,
                fn () => Socket.AF.fromString "INET6" = SOME INet6Sock.inet6AF)
  val () = eqB ("INet6Sock.inet6AF/in-the-list", true,
                fn () => List.exists (fn (n, af) => n = "INET6" andalso af = INet6Sock.inet6AF) (Socket.AF.list ()))
  (*>> af *)

  (*<< addresses *)
  (* toAddr, any and fromAddr build and read a sockaddr, which the system
     does; the text above is read and written here. *)
  (* an address is a host and a port, and taking it apart gives them back *)
  val () = eqS ("INet6Sock.toAddr/round-trip", "::1 8080", fn () => parts (INet6Sock.toAddr (addr6 "::1", 8080)))
  val () = eqS ("INet6Sock.fromAddr/host-and-port", "fe80::1 443",
                fn () => parts (INet6Sock.toAddr (addr6 "fe80::1", 443)))
  val () = eqS ("INet6Sock.any/no-host", ":: 0", fn () => parts (INet6Sock.any 0))
  val () = eqB ("INet6Sock.toAddr/family-is-INET6", true,
                fn () => Socket.familyOfAddr (INet6Sock.toAddr (addr6 "::1", 0)) = INet6Sock.inet6AF)
  (*>> addresses *)

  (*<< sockets *)
  (* a datagram to ourselves over the loopback interface, and a stream both
     ways, as in the tests of INetSock *)
  val () = eqS ("INet6Sock.UDP.socket/datagram-to-itself", if works then "to myself" else "no ipv6",
                fn () => if not works then "no ipv6"
                         else S.withSocket INet6Sock.UDP.socket (fn (s : udp6) =>
                                (Socket.bind (s, INet6Sock.toAddr (addr6 "::1", 0));
                                 Socket.sendVecTo (s, Socket.Ctl.getSockName s, S.vslice "to myself");
                                 if S.readable s then
                                   case Socket.recvVecFromNB (s, 100) of SOME (v, _) => S.text v | NONE => "NONE"
                                 else "nothing"))
  )
  val () = eqS ("INet6Sock.TCP.socket/stream-both-ways", if works then "ping pong" else "no ipv6",
                fn () => if not works then "no ipv6"
                         else S.withSocket INet6Sock.TCP.socket (fn (c : tcp6) =>
                                S.using (fn () => let val l : listener6 = INet6Sock.TCP.socket ()
                                                  in Socket.bind (l, INet6Sock.toAddr (addr6 "::1", 0));
                                                     Socket.listen (l, 4); l end,
                                         S.quietly Socket.close) (fn l =>
                                  (Socket.connect (c, Socket.Ctl.getSockName l);
                                   S.using (fn () => #1 (Socket.accept l), S.quietly Socket.close) (fn s =>
                                     (ignore (S.send (c, "ping")); ignore (S.send (s, "pong"));
                                      S.recvAll (s, 4) ^ " " ^ S.recvAll (c, 4)))))))
  val () = eqB ("INet6Sock.TCP.getNODELAY/off-by-default", true,
                fn () => S.withSocket INet6Sock.TCP.socket (fn (s : tcp6) => not (INet6Sock.TCP.getNODELAY s)))
  val () = eqB ("INet6Sock.TCP.setNODELAY/takes", true,
                fn () => S.withSocket INet6Sock.TCP.socket (fn (s : tcp6) =>
                           (INet6Sock.TCP.setNODELAY (s, true); INet6Sock.TCP.getNODELAY s)))
  (* the primed forms take a protocol of the system's numbering; 0 is the
     one the family would have chosen *)
  val () = eqB ("INet6Sock.UDP.socket'/protocol-zero", true,
                fn () => S.withSocket (fn () => INet6Sock.UDP.socket' 0)
                           (fn (s : udp6) => Socket.Ctl.getTYPE s = Socket.SOCK.dgram))
  val () = eqB ("INet6Sock.TCP.socket'/protocol-zero", true,
                fn () => S.withSocket (fn () => INet6Sock.TCP.socket' 0)
                           (fn (s : tcp6) => Socket.Ctl.getTYPE s = Socket.SOCK.stream))
  (* the types of the signature: a socket of this family is Socket's, and an
     address of it is Socket's too *)
  val () = eqB ("INet6Sock.inet6/is-the-family-of-its-sockets", true,
                fn () => S.withSocket INet6Sock.TCP.socket (fn (s : tcp6) =>
                           let val a : INet6Sock.sock_addr = Socket.Ctl.getSockName s
                           in Socket.sameAddr (a, Socket.Ctl.getSockName s) end))
  val () = eqB ("INet6Sock.sock/is-a-Socket.sock", true,
                fn () => S.withSocket INet6Sock.TCP.socket (fn (s : tcp6) =>
                           let val d = Socket.sockDesc s in Socket.sameDesc (d, d) end))
  val () = eqB ("INet6Sock.stream_sock/is-a-stream", true,
                fn () => S.withSocket INet6Sock.TCP.socket (fn (s : tcp6) => Socket.Ctl.getTYPE s = Socket.SOCK.stream))
  val () = eqB ("INet6Sock.dgram_sock/is-a-datagram", true,
                fn () => S.withSocket INet6Sock.UDP.socket (fn (s : udp6) => Socket.Ctl.getTYPE s = Socket.SOCK.dgram))
  val () = eqB ("INet6Sock.sock_addr/is-a-Socket.sock_addr", true,
                fn () => Socket.sameAddr (INet6Sock.any 0, INet6Sock.any 0))
  val () = eqB ("INet6Sock.in6_addr/admits-equality", true, fn () => addr6 "::1" = addr6 "0:0:0:0:0:0:0:1")
  (*>> sockets *)
end

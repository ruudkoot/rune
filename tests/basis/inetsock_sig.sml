(* requires: INetSock Socket NetHostDB *)
(* uses: spec-sigs/INET_SOCK.sml *)
(* INetSock matches INET_SOCK: its sockets and addresses are those of Socket
   with the family inet (the signature says so), and its addresses are
   built from those of NetHostDB. *)
structure TestINetSockSig =
struct
  structure C : SPEC_INET_SOCK = INetSock
  val () = T.check ("INetSock:INET_SOCK/matches", fn () => true)
  val () = T.check ("INetSock:INET_SOCK/inetAF-is-an-AF",
                    fn () => Socket.AF.toString C.inetAF = Socket.AF.toString INetSock.inetAF)
  val () = T.check ("INetSock:INET_SOCK/sock_addr-is-Socket.sock_addr",
                    fn () => let val a : INetSock.inet Socket.sock_addr = C.any 7
                             in Socket.sameAddr (a, INetSock.any 7) end)
end

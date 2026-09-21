(* requires: INet6Sock Socket *)
(* INet6Sock matches INET6_SOCK, which is Rune's own signature and has no
   transcription under spec-sigs: its sockets and addresses are those of
   Socket with the family inet6, and an in6_addr is abstract. *)
structure TestINet6SockSig =
struct
  val () = T.check ("INet6Sock:INET6_SOCK/sock_addr-is-Socket.sock_addr",
                    fn () => let val a : INet6Sock.inet6 Socket.sock_addr = INet6Sock.any 7
                             in Socket.sameAddr (a, INet6Sock.any 7) end)
  val () = T.check ("INet6Sock:INET6_SOCK/inet6AF-is-an-AF",
                    fn () => Socket.AF.toString INet6Sock.inet6AF = "INET6")
  val () = T.check ("INet6Sock:INET6_SOCK/in6_addr-admits-equality",
                    fn () => INet6Sock.fromString "::1" = INet6Sock.fromString "::1")
end

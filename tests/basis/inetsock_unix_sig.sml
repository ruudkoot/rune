(* requires: UnixSock Socket *)
(* uses: spec-sigs/UNIX_SOCK.sml *)
(* UnixSock matches UNIX_SOCK: its sockets and addresses are those of Socket
   with the family unix (the signature says so). *)
structure TestUnixSockSig =
struct
  structure C : SPEC_UNIX_SOCK = UnixSock
  val () = T.check ("UnixSock:UNIX_SOCK/matches", fn () => true)
  val () = T.check ("UnixSock:UNIX_SOCK/unixAF-is-an-AF",
                    fn () => Socket.AF.toString C.unixAF = Socket.AF.toString UnixSock.unixAF)
  val () = T.check ("UnixSock:UNIX_SOCK/sock_addr-is-Socket.sock_addr",
                    fn () => let val a : UnixSock.unix Socket.sock_addr = C.toAddr "x.sock"
                             in Socket.sameAddr (a, UnixSock.toAddr "x.sock") end)
end

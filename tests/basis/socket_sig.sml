(* requires: Socket NetHostDB OS *)
(* uses: spec-sigs/SOCKET.sml *)
(* Socket matches SOCKET: its address families are those of NetHostDB and
   its I/O descriptors those of OS.IO (the signature says so), and the
   constructors and substructures seen through the signature are the
   structure's. *)
structure TestSocketSig =
struct
  structure C : SPEC_SOCKET = Socket
  val () = T.check ("Socket:SOCKET/matches", fn () => true)
  val () = T.check ("Socket:SOCKET/addr_family-is-NetHostDB.addr_family",
                    fn () => let val af : NetHostDB.addr_family option = C.AF.fromString "INET"
                             in af = Socket.AF.fromString "INET" end)
  val () = T.check ("Socket:SOCKET/sock_type-is-an-eqtype", fn () => C.SOCK.stream <> C.SOCK.dgram)
  val () = T.check ("Socket:SOCKET/same-shutdown_mode",
                    fn () => List.map (fn Socket.NO_RECVS => 0 | Socket.NO_SENDS => 1 | Socket.NO_RECVS_OR_SENDS => 2)
                                      [C.NO_RECVS, C.NO_SENDS, C.NO_RECVS_OR_SENDS] = [0, 1, 2])
  val () = T.check ("Socket:SOCKET/flags-are-records",
                    fn () => let
                               val out : C.out_flags = {don't_route = false, oob = true}
                               val inf : C.in_flags = {peek = true, oob = false}
                             in #oob out andalso #peek inf end)
end

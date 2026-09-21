(* What a program sees of the structures of socket.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
(* `sock_desc` is abstract: no other signature names it. The other types are
   those that the signatures of the socket families and of `GenericSock`
   name, and stay what they are. *)
structure Socket :> SOCKET
  where type ('af, 'sock_type) sock = ('af, 'sock_type) Socket.sock
  where type 'af sock_addr = 'af Socket.sock_addr
  where type dgram = Socket.dgram
  where type 'mode stream = 'mode Socket.stream
  where type passive = Socket.passive
  where type active = Socket.active
  where type SOCK.sock_type = Socket.SOCK.sock_type
  where type shutdown_mode = Socket.shutdown_mode = Socket

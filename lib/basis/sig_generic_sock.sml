(* Making a socket of any family the system has, when the family is not known
   until the program runs.

   `INET_SOCK` and `UNIX_SOCK` make sockets of one family and give them the
   type of it; these take the family as a value, so the type variables of
   what they give are free and the program has to say what it means them to
   be. That is the price of choosing the family at run time.

   Area: The operating system

   Status: optional

   See also: `SOCKET`, `INET_SOCK`, `UNIX_SOCK`

   Implementation: `GenericSock.socket'/protocol-numbers`. The protocol
   numbers are IANA's, so 6 is TCP and 17 is UDP.

   Pinned by: `GenericSock.socket'/*` *)
signature GENERIC_SOCK =
sig
  (* `socket (af, st)` is a new socket of the family `af` and the kind `st`.

     Raises: `OS.SysErr` if the system has no such socket. *)
  val socket : Socket.AF.addr_family * Socket.SOCK.sock_type -> ('af, 'sock_type) Socket.sock

  (* `socketPair (af, st)` is two sockets of that family and kind, already connected to each other.

     Raises: `OS.SysErr` if the family does not allow it, as the internet
     family does not. *)
  val socketPair : Socket.AF.addr_family * Socket.SOCK.sock_type
                   -> ('af, 'sock_type) Socket.sock * ('af, 'sock_type) Socket.sock

  (* `socket' (af, st, n)` is `socket (af, st)` using the protocol numbered `n`; 0 lets the system choose.

     Raises: `OS.SysErr` if the system has no such socket. *)
  val socket' : Socket.AF.addr_family * Socket.SOCK.sock_type * int -> ('af, 'sock_type) Socket.sock

  (* `socketPair' (af, st, n)` is `socketPair (af, st)` using the protocol numbered `n`.

     Raises: `OS.SysErr` if the family does not allow it. *)
  val socketPair' : Socket.AF.addr_family * Socket.SOCK.sock_type * int
                    -> ('af, 'sock_type) Socket.sock * ('af, 'sock_type) Socket.sock
end

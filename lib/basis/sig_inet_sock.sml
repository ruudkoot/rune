(* Sockets of the internet family: an address is a host and a port.

   This is `SOCKET` with the address family fixed, so `('mode) stream_sock`
   and `dgram_sock` are the sockets of it and `sock_addr` its addresses.
   `toAddr` builds one from a host address and a port number, and `any` an
   address on every interface of this machine.

   `UDP` makes sockets that send messages, `TCP` sockets that carry a stream.

   Area: The operating system

   Status: optional

   See also: `SOCKET`, `NET_HOST_DB`, `UNIX_SOCK`, `GENERIC_SOCK`

   Implementation: `INET_SOCK/ipv4-only`. This signature is the
   specification's, and the specification's Internet sockets are IPv4: an
   address here is an `in_addr` of `NetHostDB` and a port. IPv6 is in
   `INET6_SOCK`, which is Rune's own and has the same shape for 128-bit
   addresses.

   See also: `INET6_SOCK` *)
signature INET_SOCK =
sig
  (* The type that marks the internet family, and holds nothing. *)
  type inet

  (* The type of a socket of this family. *)
  type 'sock_type sock = (inet, 'sock_type) Socket.sock

  (* The type of a stream socket of this family, listening or connected. *)
  type 'mode stream_sock = 'mode Socket.stream sock

  (* The type of a message socket of this family. *)
  type dgram_sock = Socket.dgram sock

  (* The type of an address of this family: a host and a port. *)
  type sock_addr = inet Socket.sock_addr

  (* The address family of the internet sockets, for `Socket.familyOfAddr` to give back. *)
  val inetAF : Socket.AF.addr_family

  (* `toAddr (a, port)` is the address of the port `port` at the host address `a`. *)
  val toAddr : NetHostDB.in_addr * int -> sock_addr

  (* `fromAddr a` is the host address and the port that `a` names.

     Example: `(fn (a, p) => (NetHostDB.toString a, p)) (fromAddr (toAddr
     (valOf (NetHostDB.fromString "127.0.0.1"), 80))) = ("127.0.0.1", 80)` *)
  val fromAddr : sock_addr -> NetHostDB.in_addr * int

  (* `any port` is the address of `port` on every interface of this machine.

     It is what a program binds to when it will answer on whichever
     interface a connection arrives at; a port of 0 asks the system to choose
     one. *)
  val any : int -> sock_addr

  (* Sockets that send messages, over UDP. *)
  structure UDP :
  sig
    (* `socket ()` is a new message socket, with the protocol the system picks for messages.

       Raises: `OS.SysErr` if no socket can be made. *)
    val socket : unit -> dgram_sock

    (* `socket' n` is a new message socket using the protocol numbered `n`.

       Raises: `OS.SysErr` if no socket can be made.

       Implementation: `INetSock.UDP.socket'/protocol-numbers`. The numbers
       are IANA's, so 17 is UDP; 0 asks the system to choose, which makes it
       the same as `socket ()`.

       Pinned by: `INetSock.UDP.socket'/*` *)
    val socket' : int -> dgram_sock
  end

  (* Sockets that carry a stream, over TCP. *)
  structure TCP :
  sig
    (* `socket ()` is a new stream socket, with the protocol the system picks for streams.

       Raises: `OS.SysErr` if no socket can be made. *)
    val socket : unit -> 'mode stream_sock

    (* `socket' n` is a new stream socket using the protocol numbered `n`; 6 is TCP.

       Raises: `OS.SysErr` if no socket can be made. *)
    val socket' : int -> 'mode stream_sock

    (* `getNODELAY sock` is `true` when small writes go out at once rather than being gathered. *)
    val getNODELAY : 'mode stream_sock -> bool

    (* `setNODELAY (sock, b)` sends small writes at once, or lets them be gathered. *)
    val setNODELAY : 'mode stream_sock * bool -> unit
  end
end

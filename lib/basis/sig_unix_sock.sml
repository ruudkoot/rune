(* Sockets of the Unix family: an address is a path in the file system, and
   the connection never leaves the machine.

   This is `SOCKET` with the address family fixed. An address is made from a
   path with `toAddr`; binding to it creates that entry in the file system,
   and removing the entry is the program's own business.

   `Strm` and `DGrm` also offer `socketPair`, which makes two sockets already
   connected to each other -- the usual way to give a child process a channel
   to its parent.

   Area: The operating system

   Status: optional

   See also: `SOCKET`, `INET_SOCK`, `GENERIC_SOCK`, `UNIX` *)
signature UNIX_SOCK =
sig
  (* The type that marks the Unix family, and holds nothing. *)
  type unix

  (* The type of a socket of this family. *)
  type 'sock_type sock = (unix, 'sock_type) Socket.sock

  (* The type of a stream socket of this family, listening or connected. *)
  type 'mode stream_sock = 'mode Socket.stream sock

  (* The type of a message socket of this family. *)
  type dgram_sock = Socket.dgram sock

  (* The type of an address of this family: a path. *)
  type sock_addr = unix Socket.sock_addr

  (* The address family of the Unix sockets, for `Socket.familyOfAddr` to give back. *)
  val unixAF : Socket.AF.addr_family

  (* `toAddr p` is the address of the socket at the path `p`. *)
  val toAddr : string -> sock_addr

  (* `fromAddr a` is the path that `a` names. *)
  val fromAddr : sock_addr -> string

  (* Sockets of this family that carry a stream. *)
  structure Strm :
  sig
    (* `socket ()` is a new stream socket of this family.

       Raises: `OS.SysErr` if no socket can be made. *)
    val socket : unit -> 'mode stream_sock

    (* `socketPair ()` is two stream sockets already connected to each other.

       Raises: `OS.SysErr` if no pair can be made. *)
    val socketPair : unit -> 'mode stream_sock * 'mode stream_sock
  end

  (* Sockets of this family that send messages. *)
  structure DGrm :
  sig
    (* `socket ()` is a new message socket of this family.

       Raises: `OS.SysErr` if no socket can be made. *)
    val socket : unit -> dgram_sock

    (* `socketPair ()` is two message sockets already connected to each other.

       Raises: `OS.SysErr` if no pair can be made. *)
    val socketPair : unit -> dgram_sock * dgram_sock
  end
end

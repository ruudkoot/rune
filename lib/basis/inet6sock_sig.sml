(* Sockets of the Internet protocol version 6, as `INET_SOCK` describes them
   for version 4.

   The specification knows nothing of IPv6: it was written when the protocol
   was new, and its `NetHostDB` is an IPv4 database whose `toString` is
   defined to give the four dotted numbers. So this signature is Rune's own,
   and a program that uses it is not portable. It is as close to `INET_SOCK`
   as it can be -- the same names, in the same order, for the same things --
   so that the two read alike.

   An address of this family is an `in6_addr` and a port. `toString` and
   `fromString` write and read the text of `inet_ntop` and `inet_pton` --
   eight groups of up to four hexadecimal digits, at most one `::` for the
   longest run of zeros, a dotted quad in place of the last two groups, and
   no scope after `%` -- and they do it here rather than asking the system,
   as `NetHostDB` does for IPv4, so that a host compiling this library can
   read and write addresses although it has no sockets. On 300 addresses
   drawn at random the text is the same as `inet_ntop`'s, character for
   character. The addresses of a host are not looked up here; `NetHostDB`
   answers for IPv4 only.

   Area: The operating system

   Status: extension

   Deviation: `INET6_SOCK/not-in-the-specification`. This signature is not in
   the specification, which has no IPv6 at all: it was written before the
   protocol, its `NetHostDB` is defined to give the four dotted numbers of
   IPv4, and it names no structure for anything else. A program that uses
   this one does not port. What the specification does allow is the family:
   AF.list "returns a list of all the available address families", so
   `Socket.AF` knowing `INET6` is not a departure and this signature is.

   See also: `INET_SOCK`, `SOCKET`, `NET_HOST_DB`, `MONO_VECTOR_EQ` *)
signature INET6_SOCK =
sig
  (* The type that says a socket or an address is of this family. *)
  type inet6

  (* A socket of this family, carrying what it is. *)
  type 'sock_type sock = (inet6, 'sock_type) Socket.sock

  (* A stream socket of this family, passive or active. *)
  type 'mode stream_sock = 'mode Socket.stream sock

  (* A datagram socket of this family. *)
  type dgram_sock = Socket.dgram sock

  (* An address of this family. *)
  type sock_addr = inet6 Socket.sock_addr

  (* The address of a host, 128 bits.

     Two are equal when they are the same address, whatever text each was
     read from: `fromString "::1"` and `fromString "0:0:0:0:0:0:0:1"` are
     one address. *)
  eqtype in6_addr

  (* `toString a` is the text of `a` as `inet_ntop` writes it.

     Example: `toString (valOf (fromString "0:0:0:0:0:0:0:1")) = "::1"` *)
  val toString : in6_addr -> string

  (* `fromString s` is the address that the whole of `s` names, or `NONE`.

     The forms are those of `inet_pton`, so `"::1"`, `"fe80::1"` and
     `"::ffff:127.0.0.1"` are addresses and `"127.0.0.1"` is not.

     Example: `fromString "not an address" = NONE` *)
  val fromString : string -> in6_addr option

  (* The address family of these sockets, `Socket.AF.fromString "INET6"`. *)
  val inet6AF : Socket.AF.addr_family

  (* `toAddr (a, port)` is the address of that host and port.

     Raises: `SysErr` if the system will not make it. *)
  val toAddr : in6_addr * int -> sock_addr

  (* `any port` is the address of that port on every interface of the machine. *)
  val any : int -> sock_addr

  (* `fromAddr addr` is the host and the port of `addr`.

     Law: `fromAddr (toAddr (a, p)) = (a, p)` *)
  val fromAddr : sock_addr -> in6_addr * int

  (* Datagram sockets of this family. *)
  structure UDP :
  sig
    (* `socket ()` is a new datagram socket. *)
    val socket : unit -> dgram_sock

    (* `socket' protocol` is the same for a protocol of the system's numbering. *)
    val socket' : int -> dgram_sock
  end

  (* Stream sockets of this family. *)
  structure TCP :
  sig
    (* `socket ()` is a new stream socket. *)
    val socket : unit -> 'mode stream_sock

    (* `socket' protocol` is the same for a protocol of the system's numbering. *)
    val socket' : int -> 'mode stream_sock

    (* `getNODELAY sock` is whether small writes go out at once (`TCP_NODELAY`). *)
    val getNODELAY : 'mode stream_sock -> bool

    (* `setNODELAY (sock, b)` sets it. *)
    val setNODELAY : 'mode stream_sock * bool -> unit
  end
end

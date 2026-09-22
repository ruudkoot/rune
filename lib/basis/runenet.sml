(* The types of the network that `NetHostDB` and `Socket` share, made
   abstract where they are declared, because the specification leaves them
   abstract and `SOCKET` says that `AF.addr_family` is `NetHostDB`'s.

   An address is the dotted text, which is what the system takes; an address
   family and a socket type are the numbers of the system. The library turns
   them into and out of those with the conversions here; a program cannot,
   which is what makes them abstract. `socket.sml` is compiled before
   `netdb.sml`, so neither file can be the one that declares them. *)
structure RuneNet :>
sig
  eqtype in_addr
  eqtype addr_family
  eqtype sock_type
  val toText : in_addr -> string
  val ofText : string -> in_addr
  val familyToInt : addr_family -> int
  val familyFromInt : int -> addr_family
  val typeToInt : sock_type -> int
  val typeFromInt : int -> sock_type
end =
struct
  type in_addr = string
  type addr_family = int
  type sock_type = int
  fun toText (a : in_addr) = a
  fun ofText (s : string) : in_addr = s
  fun familyToInt (af : addr_family) = af
  fun familyFromInt (n : int) : addr_family = n
  fun typeToInt (t : sock_type) = t
  fun typeFromInt (n : int) : sock_type = n
end

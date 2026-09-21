(* What a program sees of INet6Sock: the members INET6_SOCK names. `inet6`
   stays what it is, because the signature writes the socket and address
   types in terms of it and of Socket's; `in6_addr` is abstract. *)
structure INet6Sock :> INET6_SOCK where type inet6 = INet6Sock.inet6 = INet6Sock

(* The arbitraries of Rune's IPv6 sockets and addresses (docs/plans/quickcheck.md,
   M6), apart from `SYSTEM_ARB` because `INet6Sock` is Rune's own.

   Area: Property testing *)
signature INET6_SOCK_ARB =
sig
  (* The arbitrary of IPv6 addresses: eight groups of 16 bits, each drawn as
     `Gen.wordBits 16` draws one. *)
  val inAddr : INet6Sock.in6_addr Arb.arb

  (* `streamSock ()` is the arbitrary of new TCP sockets over IPv6, closed
     when the case is over. *)
  val streamSock : unit -> 'mode INet6Sock.stream_sock Arb.arb
end

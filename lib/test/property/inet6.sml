(* The arbitraries of Rune's IPv6 sockets and addresses (docs/plans/quickcheck.md, M6). *)

(* Implements: INET6_SOCK_ARB *)
structure INet6SockArb :> INET6_SOCK_ARB =
struct
  val inAddr : INet6Sock.in6_addr Arb.arb =
    {gen = Gen.map (fn ws => valOf (INet6Sock.fromString (String.concatWith ":" (List.map (Word64.fmt StringCvt.HEX) ws))))
                   (Gen.listOf (Gen.return 8) (Gen.wordBits 16)),
     show = fn a => "valOf (INet6Sock.fromString " ^ Show.string (INet6Sock.toString a) ^ ")",
     co = fn a => Random.hashString (INet6Sock.toString a), eq = SOME (op =)}

  fun streamSock () : 'mode INet6Sock.stream_sock Arb.arb =
    {gen = Gen.resource (Gen.primitive (fn _ => INet6Sock.TCP.socket ()), fn s => Socket.close s handle _ => ()),
     show = fn _ => "(* a new TCP socket over IPv6 *)", co = fn _ => 0w0, eq = NONE}
end

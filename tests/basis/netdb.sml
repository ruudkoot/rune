(* requires: NetHostDB NetProtDB NetServDB Substring *)
(* NetHostDB, NetProtDB and NetServDB (signatures NET_HOST_DB, NET_PROT_DB
   and NET_SERV_DB): Internet addresses as text, and the host, protocol and
   service databases. Expected values follow
   https://smlfamily.github.io/Basis/net-host-db.html,
   https://smlfamily.github.io/Basis/prot-db.html and
   https://smlfamily.github.io/Basis/serv-db.html.

   The lookups ask only for what every system has without the network: the
   host "localhost" (127.0.0.1), the protocols ip (0), tcp (6) and udp (17)
   of /etc/protocols, and the services http (80/tcp, alias www), ssh
   (22/tcp) and domain (53/udp) of /etc/services. Port 65000 is in the
   dynamic range, which no service is assigned to. *)
structure TestNetDB =
struct
  val eqS = T.eq T.string
  val eqOS = T.eq (T.option T.string)
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  fun text s = Option.map NetHostDB.toString (NetHostDB.fromString s)
  fun scanned (s : string) : string option =
    Option.map (fn (a, rest) => NetHostDB.toString a ^ "|" ^ Substring.string rest)
               (NetHostDB.scan Substring.getc (Substring.full s))
  fun loopback () = valOf (NetHostDB.fromString "127.0.0.1")

  (*<< text *)
  (* toString ia "returns a string representation of the Internet address ia
     in the form "a.b.c.d"" *)
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.toString/dotted",
                 List.map SOME ["127.0.0.1", "0.0.0.0", "255.255.255.255", "192.0.2.1", "10.20.30.40"],
                 fn () => List.map text ["127.0.0.1", "0.0.0.0", "255.255.255.255", "192.0.2.1", "10.20.30.40"])
  val () = T.check ("NetHostDB.toString/round-trip",
                    fn () => (T.seed 29;
                              List.all (fn _ =>
                                          let val s = String.concatWith "." (List.tabulate (4, fn _ => Int.toString (T.range (0, 255))))
                                          in text s = SOME s end)
                                       (List.tabulate (300, fn i => i))))
  (* "Addresses in this notation have one of the following forms: a ... a.b
     ... a.b.c ... a.b.c.d": a single part is 32 bits, the last of two parts
     24 bits, the last of three 16 bits *)
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.fromString/one-part",
                 [SOME "127.0.0.1", SOME "0.0.0.0", SOME "255.255.255.255", SOME "0.0.1.0"],
                 fn () => List.map text ["2130706433", "0", "4294967295", "256"])
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.fromString/two-parts",
                 [SOME "127.0.0.1", SOME "10.1.0.0", SOME "10.255.255.255"],
                 fn () => List.map text ["127.1", "10.65536", "10.16777215"])
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.fromString/three-parts",
                 [SOME "127.0.0.1", SOME "10.1.1.2", SOME "10.1.255.255"],
                 fn () => List.map text ["127.0.1", "10.1.258", "10.1.65535"])
  (* "The integer constants may be decimal, octal, or hexadecimal, as
     specified in the C language": 0x or 0X begins a hexadecimal constant, 0
     an octal one *)
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.fromString/hexadecimal",
                 [SOME "127.0.0.1", SOME "127.0.0.1", SOME "192.168.0.1", SOME "127.0.0.1"],
                 fn () => List.map text ["0x7f.0.0.1", "0X7F.0x0.0x0.0x1", "0xc0.0xA8.0.1", "0x7f000001"])
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.fromString/octal",
                 [SOME "127.0.0.1", SOME "8.8.8.8", SOME "127.0.0.1", SOME "8.0.0.1"],
                 fn () => List.map text ["0177.0.0.01", "010.010.010.010", "017700000001", "010.0.0.1"])
  val () = eqOS ("NetHostDB.fromString/zeros", SOME "127.0.0.1", fn () => text "127.000.000.001")
  (* "after skipping initial whitespace" *)
  val () = eqOS ("NetHostDB.fromString/initial-whitespace", SOME "127.0.0.1", fn () => text " \t\n127.0.0.1")
  (* "if an Internet address ia can be parsed from a prefix of string s" *)
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.fromString/prefix",
                 [SOME "10.0.0.1", SOME "10.0.0.1", SOME "10.0.0.1"],
                 fn () => List.map text ["10.0.0.1 rest", "10.0.0.1:80", "10.0.0.1/8"])
  val () = T.eq (T.list (T.option T.string)) ("NetHostDB.fromString/not-an-address",
                 [NONE, NONE, NONE, NONE, NONE],
                 fn () => List.map text ["x", "", "   ", ".1.2.3", "-1.2.3.4"])
  (* in_addr is an equality type: the same address written differently *)
  val () = eqB ("NetHostDB.fromString/same-address", true,
                fn () => NetHostDB.fromString "127.0.0.1" = NetHostDB.fromString "127.1"
                         andalso NetHostDB.fromString "0x7f.1" = NetHostDB.fromString "2130706433")
  val () = eqB ("NetHostDB.fromString/other-address", false,
                fn () => NetHostDB.fromString "127.0.0.1" = NetHostDB.fromString "127.0.0.2")
  (* scan getc strm "returns SOME(ia,rest) if an Internet address can be
     parsed from a prefix of the character stream strm after skipping initial
     whitespace. ia is the resulting address, and rest is the remainder of
     the character stream." *)
  val () = eqOS ("NetHostDB.scan/rest", SOME "1.2.3.4|:80", fn () => scanned "1.2.3.4:80")
  val () = eqOS ("NetHostDB.scan/whitespace-then-rest", SOME "5.6.7.8| x", fn () => scanned "  5.6.7.8 x")
  val () = eqOS ("NetHostDB.scan/one-part-rest", SOME "127.0.0.1| x", fn () => scanned "2130706433 x")
  val () = eqOS ("NetHostDB.scan/nothing-left", SOME "9.8.7.6|", fn () => scanned "9.8.7.6")
  val () = eqOS ("NetHostDB.scan/char-list", SOME "10.0.0.2|!",
                 fn () => Option.map (fn (a, rest) => NetHostDB.toString a ^ "|" ^ implode rest)
                                     (NetHostDB.scan List.getItem (explode "10.0.0.2!")))
  val () = eqOS ("NetHostDB.scan/not-an-address", NONE, fn () => scanned "abc")
  val () = eqOS ("NetHostDB.scan/empty", NONE, fn () => scanned "")
  (*>> text *)

  (*<< hosts *)
  (* getByName s "reads the network host data base for a host with name s.
     If successful, it returns SOME(en) where en is the corresponding data
     base entry" *)
  fun localhost () = valOf (NetHostDB.getByName "localhost")
  fun namedLocalhost e =
    NetHostDB.name e = "localhost" orelse List.exists (fn a => a = "localhost") (NetHostDB.aliases e)
  val () = eqB ("NetHostDB.getByName/localhost", true, fn () => isSome (NetHostDB.getByName "localhost"))
  (* name en "returns the official name of the host"; aliases en "the alias
     list" *)
  val () = T.check ("NetHostDB.name/localhost", fn () => String.isPrefix "localhost" (NetHostDB.name (localhost ())))
  val () = T.check ("NetHostDB.aliases/localhost",
                    fn () => let val e = localhost () in namedLocalhost e andalso List.all (fn a => a <> "") (NetHostDB.aliases e) end)
  (* addr en "returns the main Internet address of the host described by
     entry en. This is the first address of the list returned by addrs";
     addrs: "The list is guaranteed to be non-empty." *)
  val () = eqS ("NetHostDB.addr/localhost", "127.0.0.1", fn () => NetHostDB.toString (NetHostDB.addr (localhost ())))
  val () = T.check ("NetHostDB.addrs/localhost",
                    fn () => let val e = localhost ()
                             in
                               case NetHostDB.addrs e of
                                 first :: _ => first = NetHostDB.addr e andalso List.exists (fn a => a = loopback ()) (NetHostDB.addrs e)
                               | [] => false
                             end)
  val () = T.check ("NetHostDB.getByAddr/loopback",
                    fn () => case NetHostDB.getByAddr (loopback ()) of
                               SOME e => namedLocalhost e andalso NetHostDB.addr e = loopback ()
                             | NONE => false)
  (* "The standard hostname for the current processor." *)
  val () = T.check ("NetHostDB.getHostName/not-empty", fn () => NetHostDB.getHostName () <> "")
  val () = T.check ("NetHostDB.getHostName/stable", fn () => NetHostDB.getHostName () = NetHostDB.getHostName ())
  (*>> hosts *)

  (*<< host-family *)
  (* addrType en "returns the address family of the host" *)
  val () = T.check ("NetHostDB.addrType/localhost", fn () => NetHostDB.addrType (localhost ()) = INetSock.inetAF)
  (*>> host-family *)

  (*<< host-name *)
  (* the name uname gives the node *)
  val () = T.check ("NetHostDB.getHostName/uname",
                    fn () => SOME (NetHostDB.getHostName ())
                             = Option.map #2 (List.find (fn (k, _) => k = "nodename") (Posix.ProcEnv.uname ())))
  (*>> host-name *)

  (*<< protocols *)
  (* getByName s "reads the network protocol data base for a protocol with
     name s"; getByNumber i "for a protocol with protocol number i";
     "otherwise, it returns NONE" *)
  fun proto (e : NetProtDB.entry) = NetProtDB.name e ^ " " ^ Int.toString (NetProtDB.protocol e)
  val () = eqOS ("NetProtDB.getByName/tcp", SOME "tcp 6", fn () => Option.map proto (NetProtDB.getByName "tcp"))
  val () = eqOS ("NetProtDB.getByName/udp", SOME "udp 17", fn () => Option.map proto (NetProtDB.getByName "udp"))
  val () = eqOS ("NetProtDB.getByName/alias", SOME "tcp 6", fn () => Option.map proto (NetProtDB.getByName "TCP"))
  val () = eqOS ("NetProtDB.getByName/unknown", NONE, fn () => Option.map proto (NetProtDB.getByName "no-such-protocol"))
  val () = eqOS ("NetProtDB.getByNumber/6", SOME "tcp 6", fn () => Option.map proto (NetProtDB.getByNumber 6))
  val () = eqOS ("NetProtDB.getByNumber/17", SOME "udp 17", fn () => Option.map proto (NetProtDB.getByNumber 17))
  val () = eqOS ("NetProtDB.getByNumber/unknown", NONE, fn () => Option.map proto (NetProtDB.getByNumber 99999))
  (* name en: "the official name of the protocol described by entry en
     (e.g., "ip")" *)
  val () = eqOS ("NetProtDB.name/ip", SOME "ip", fn () => Option.map NetProtDB.name (NetProtDB.getByNumber 0))
  val () = eqOS ("NetProtDB.name/tcp", SOME "tcp", fn () => Option.map NetProtDB.name (NetProtDB.getByName "tcp"))
  val () = eqB ("NetProtDB.aliases/tcp", true,
                fn () => List.exists (fn a => a = "TCP") (NetProtDB.aliases (valOf (NetProtDB.getByName "tcp"))))
  val () = eqI ("NetProtDB.protocol/udp", 17, fn () => NetProtDB.protocol (valOf (NetProtDB.getByName "udp")))
  (*>> protocols *)

  (*<< services *)
  (* getByName (s, prot) "reads the network service data base for a service
     with name s. If prot is SOME(protname), the protocol of the service must
     also match protname; if prot is NONE, no protocol restriction is
     imposed." getByPort likewise, by port number. *)
  fun serv (e : NetServDB.entry) = NetServDB.name e ^ " " ^ Int.toString (NetServDB.port e) ^ "/" ^ NetServDB.protocol e
  val () = eqOS ("NetServDB.getByName/http-tcp", SOME "http 80/tcp", fn () => Option.map serv (NetServDB.getByName ("http", SOME "tcp")))
  val () = eqOS ("NetServDB.getByName/ssh-tcp", SOME "ssh 22/tcp", fn () => Option.map serv (NetServDB.getByName ("ssh", SOME "tcp")))
  val () = eqOS ("NetServDB.getByName/domain-udp", SOME "domain 53/udp",
                 fn () => Option.map serv (NetServDB.getByName ("domain", SOME "udp")))
  val () = eqOS ("NetServDB.getByName/alias", SOME "http 80/tcp", fn () => Option.map serv (NetServDB.getByName ("www", SOME "tcp")))
  val () = T.eq (T.option T.int) ("NetServDB.getByName/any-protocol", SOME 80,
                                  fn () => Option.map NetServDB.port (NetServDB.getByName ("http", NONE)))
  val () = eqOS ("NetServDB.getByName/other-protocol", NONE,
                 fn () => Option.map serv (NetServDB.getByName ("http", SOME "no-such-protocol")))
  val () = eqOS ("NetServDB.getByName/unknown", NONE, fn () => Option.map serv (NetServDB.getByName ("no-such-service", NONE)))
  val () = eqOS ("NetServDB.getByPort/80-tcp", SOME "http 80/tcp", fn () => Option.map serv (NetServDB.getByPort (80, SOME "tcp")))
  val () = eqOS ("NetServDB.getByPort/22-tcp", SOME "ssh 22/tcp", fn () => Option.map serv (NetServDB.getByPort (22, SOME "tcp")))
  val () = eqOS ("NetServDB.getByPort/53-udp", SOME "domain 53/udp", fn () => Option.map serv (NetServDB.getByPort (53, SOME "udp")))
  val () = T.eq (T.option T.int) ("NetServDB.getByPort/any-protocol", SOME 80,
                                  fn () => Option.map NetServDB.port (NetServDB.getByPort (80, NONE)))
  val () = eqOS ("NetServDB.getByPort/other-protocol", NONE,
                 fn () => Option.map serv (NetServDB.getByPort (80, SOME "no-such-protocol")))
  val () = eqOS ("NetServDB.getByPort/unassigned", NONE, fn () => Option.map serv (NetServDB.getByPort (65000, NONE)))
  (* name, aliases, port and protocol of an entry: "(e.g., "tcp" or "udp")" *)
  val () = eqOS ("NetServDB.name/http", SOME "http", fn () => Option.map NetServDB.name (NetServDB.getByPort (80, SOME "tcp")))
  val () = eqB ("NetServDB.aliases/http", true,
                fn () => List.exists (fn a => a = "www") (NetServDB.aliases (valOf (NetServDB.getByName ("http", SOME "tcp")))))
  val () = eqI ("NetServDB.port/ssh", 22, fn () => NetServDB.port (valOf (NetServDB.getByName ("ssh", SOME "tcp"))))
  val () = eqS ("NetServDB.protocol/domain-udp", "udp", fn () => NetServDB.protocol (valOf (NetServDB.getByName ("domain", SOME "udp"))))
  (*>> services *)
end

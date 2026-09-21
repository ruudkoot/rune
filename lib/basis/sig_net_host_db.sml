(* The host database: turning a host name into an address, and back.

   `getByName` and `getByAddr` ask the system what it knows about a host --
   from `/etc/hosts`, from the domain name service, from whatever the machine
   is set up to use. What comes back is an `entry`, which the functions above
   it take apart: a host may have several names and several addresses.

   `fromString` and `toString` do no lookup at all; they read and write the
   dotted form of an address.

   Area: The operating system

   Status: optional

   See also: `SOCKET`, `INET_SOCK`, `NET_SERV_DB`, `NET_PROT_DB`

   Implementation: `NetHostDB.in_addr/is-dotted-text`. An address is the
   canonical dotted text of an IPv4 address, so `=` compares addresses and
   not the text they were written as; there is no IPv6 here.

   Implementation: `NetHostDB.in_addr/abstract`. The specification leaves
   `in_addr` and `addr_family` abstract, and so are they here: `toString` and
   `fromString` are the way in and out of an address, and `Socket.AF` names
   the families. *)
signature NET_HOST_DB =
sig
  (* The type of the address of a host.

     Two are equal when they are the same address. *)
  eqtype in_addr

  (* The type of an address family, the one of `Socket.AF`. *)
  eqtype addr_family

  (* The type of what the database records about one host. *)
  type entry

  (* `name e` is the official name of the host. *)
  val name : entry -> string

  (* `aliases e` is the other names the host answers to. *)
  val aliases : entry -> string list

  (* `addrType e` is the address family of the host's addresses. *)
  val addrType : entry -> addr_family

  (* `addr e` is the first of the host's addresses. *)
  val addr : entry -> in_addr

  (* `addrs e` is every address the host has. *)
  val addrs : entry -> in_addr list

  (* `getByName name` is `SOME` of what the database records about the host `name`, or `NONE`. *)
  val getByName : string -> entry option

  (* `getByAddr a` is `SOME` of what the database records about the host at `a`, or `NONE`. *)
  val getByAddr : in_addr -> entry option

  (* `getHostName ()` is the name of this machine.

     Implementation: `NetHostDB.getHostName/is-the-nodename`. The "standard
     hostname" is the `nodename` that `Posix.ProcEnv.uname` reports.

     Pinned by: `NetHostDB.getHostName/uname` *)
  val getHostName : unit -> string

  (* `toString a` is `a` in the dotted form, four decimal numbers separated by points. *)
  val toString : in_addr -> string

  (* `scan getc src` reads an address and is it and what is left.

     Reading: `NetHostDB.scan/inet_aton-forms`. One number, two, three or
     four may be written, as the C library's `inet_aton` allows: a single
     part fills all 32 bits, the last of two parts the low 24, the last of
     three the low 16. "As specified in the C language" fixes how each part
     is written: `0x` or `0X` begins a hexadecimal number and a leading `0`
     an octal one.

     Pinned by: `NetHostDB.fromString/one-part`,
     `NetHostDB.fromString/two-parts`, `NetHostDB.fromString/three-parts`,
     `NetHostDB.fromString/hexadecimal`, `NetHostDB.fromString/octal` *)
  val scan : (char, 'a) StringCvt.reader -> (in_addr, 'a) StringCvt.reader

  (* `fromString s` is `SOME` of the address that `s` begins with, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s`

     Example: `Option.map toString (fromString "127.1") = SOME "127.0.0.1"`

     Example: `Option.map toString (fromString "0x7f000001") = SOME
     "127.0.0.1"` *)
  val fromString : string -> in_addr option
end

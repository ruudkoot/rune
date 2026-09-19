(* NetHostDB, NetProtDB and NetServDB: the databases of the network. *)
structure RuneNetHostDB =
struct
  local
    val byname = _prim "netdb_host_byname" : string -> string list
    val byaddr = _prim "netdb_host_byaddr" : string -> string list
    val hostname = _prim "netdb_hostname" : unit -> string
    val inetAddr = _prim "socket_inet_addr" : string * int -> string
    val inetParts = _prim "socket_inet_parts" : string -> string list
    val const = _prim "posix_const" : string -> int
  in
    (* An address is the dotted text, which is what the system takes. *)
    type in_addr = string
    type addr_family = int
    type entry = {name : string, aliases : string list, addrType : addr_family, addrs : in_addr list}

    fun name (e : entry) = #name e
    fun aliases (e : entry) = #aliases e
    fun addrType (e : entry) = #addrType e
    fun addrs (e : entry) = #addrs e
    fun addr (e : entry) = case #addrs e of a :: _ => a | [] => raise Empty

    fun toString (a : in_addr) = a

    (* The notation of inet_addr in C: "a", "a.b", "a.b.c" or "a.b.c.d", where
       the last number fills the bytes the others leave (32, 24, 16 or 8
       bits), and a number is decimal, octal after 0, or hexadecimal after 0x
       or 0X. The address is the prefix with the most numbers that fit, and
       its text the four bytes in decimal, so that equal addresses are equal
       strings. A number is kept as its four bytes, the least significant
       first, so that no int needs more than a few bits. *)
    fun scan getc src =
      let
        val zero = [0, 0, 0, 0]
        fun digitValue c =
          if Char.isDigit c then SOME (ord c - ord #"0")
          else if c >= #"a" andalso c <= #"f" then SOME (ord c - ord #"a" + 10)
          else if c >= #"A" andalso c <= #"F" then SOME (ord c - ord #"A" + 10)
          else NONE
        (* bytes * base + d, or NONE past 32 bits *)
        fun mulAdd (bytes, base, d) =
          let
            fun go ([], carry) = if carry = 0 then SOME [] else NONE
              | go (b :: rest, carry) =
                  let val v = b * base + carry
                  in case go (rest, v div 256) of SOME r => SOME (v mod 256 :: r) | NONE => NONE end
          in go (bytes, d) end
        (* the digits of a number; an 8 or 9 spoils an octal one *)
        fun digits (base, src, bytes, any) =
          let val stop = if any then SOME (bytes, src) else NONE
          in
            case getc src of
              SOME (c, rest) =>
                (case digitValue c of
                   SOME d =>
                     if d < base then
                       (case mulAdd (bytes, base, d) of
                          SOME more => digits (base, rest, more, true)
                        | NONE => NONE)
                     else if base = 8 andalso d < 10 then NONE
                     else stop
                 | NONE => stop)
            | NONE => stop
          end
        fun number src =
          case getc src of
            SOME (#"0", rest) =>
              (case getc rest of
                 SOME (x, rest') =>
                   if x = #"x" orelse x = #"X" then digits (16, rest', zero, false)
                   else digits (8, rest, zero, true)
               | NONE => SOME (zero, rest))
          | SOME (c, _) => if Char.isDigit c then digits (10, src, zero, false) else NONE
          | NONE => NONE
        (* up to four numbers, each with what follows it, the last first *)
        fun numbers (found, count, src) =
          if count = 4 then found
          else
            case getc src of
              SOME (#".", rest) =>
                (case number rest of
                   SOME (n, after) => numbers ((n, after) :: found, count + 1, after)
                 | NONE => found)
            | _ => found
        (* the value is below 256^k *)
        fun below ([], _) = true
          | below (b :: rest, k) = (k > 0 orelse b = 0) andalso below (rest, k - 1)
        fun byte (b :: _) = b
          | byte [] = 0
        fun bytes ([b0, b1, b2, b3], k) = if k = 4 then [b3, b2, b1, b0] else if k = 3 then [b2, b1, b0] else [b1, b0]
          | bytes _ = []
        (* the address the first k numbers make, if they fit *)
        fun address [(d, _)] = SOME (bytes (d, 4))
          | address [(c, _), (a, _)] =
              if below (a, 1) andalso below (c, 3) then SOME (byte a :: bytes (c, 3)) else NONE
          | address [(c, _), (b, _), (a, _)] =
              if below (a, 1) andalso below (b, 1) andalso below (c, 2) then SOME (byte a :: byte b :: bytes (c, 2)) else NONE
          | address [(d, _), (c, _), (b, _), (a, _)] =
              if below (a, 1) andalso below (b, 1) andalso below (c, 1) andalso below (d, 1)
              then SOME [byte a, byte b, byte c, byte d]
              else NONE
          | address _ = NONE
        fun longest [] = NONE
          | longest (found as (_, after) :: shorter) =
              case address found of
                SOME quad => SOME (String.concatWith "." (map Int.toString quad), after)
              | NONE => longest shorter
      in
        case number (StringCvt.skipWS getc src) of
          SOME (n, after) => longest (numbers ([(n, after)], 1, after))
        | NONE => NONE
      end
    fun fromString s = StringCvt.scanString scan s

    fun entryOf l =
      case l of
        name :: address :: others =>
          SOME ({name = name, aliases = others, addrType = const "AF_INET",
                 addrs = if address = "" then [] else [address]} : entry)
      | _ => NONE

    fun getByName name = entryOf (byname name)
    fun getByAddr (a : in_addr) = entryOf (byaddr a)
    fun getHostName () = hostname ()
  end
end

structure RuneNetProtDB =
struct
  local
    val byname = _prim "netdb_proto_byname" : string -> string list
    val bynumber = _prim "netdb_proto_bynumber" : int -> string list
    fun number s = case Int.fromString s of SOME n => n | NONE => 0
  in
    type entry = {name : string, aliases : string list, protocol : int}
    fun name (e : entry) = #name e
    fun aliases (e : entry) = #aliases e
    fun protocol (e : entry) = #protocol e

    fun entryOf l =
      case l of
        name :: number' :: others => SOME ({name = name, aliases = others, protocol = number number'} : entry)
      | _ => NONE

    fun getByName n = entryOf (byname n)
    fun getByNumber n = entryOf (bynumber n)
  end
end

structure RuneNetServDB =
struct
  local
    val byname = _prim "netdb_serv_byname" : string * string -> string list
    val byport = _prim "netdb_serv_byport" : int * string -> string list
    fun number s = case Int.fromString s of SOME n => n | NONE => 0
  in
    type entry = {name : string, aliases : string list, port : int, protocol : string}
    fun name (e : entry) = #name e
    fun aliases (e : entry) = #aliases e
    fun port (e : entry) = #port e
    fun protocol (e : entry) = #protocol e

    fun entryOf l =
      case l of
        name :: port' :: protocol :: others =>
          SOME ({name = name, aliases = others, port = number port', protocol = protocol} : entry)
      | _ => NONE

    fun getByName (n, NONE) = entryOf (byname (n, ""))
      | getByName (n, SOME p) = entryOf (byname (n, p))
    fun getByPort (p, NONE) = entryOf (byport (p, ""))
      | getByPort (p, SOME protocol) = entryOf (byport (p, protocol))
  end
end

structure NetHostDB = RuneNetHostDB
structure NetProtDB = RuneNetProtDB
structure NetServDB = RuneNetServDB

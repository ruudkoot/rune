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
    type net_addr_family = int
    type entry = {name : string, aliases : string list, addrType : net_addr_family, addrs : in_addr list}

    fun name (e : entry) = #name e
    fun aliases (e : entry) = #aliases e
    fun addrType (e : entry) = #addrType e
    fun addrs (e : entry) = #addrs e
    fun addr (e : entry) = case #addrs e of a :: _ => a | [] => raise Empty

    fun toString (a : in_addr) = a
    fun scan getc src =
      let
        fun digits (src, acc, n) =
          case getc src of
            SOME (c, rest) => if Char.isDigit c then digits (rest, acc ^ String.str c, n + 1) else (acc, n, src)
          | NONE => (acc, n, src)
        fun dot (src, k, acc) =
          if k = 0 then SOME (acc, src)
          else
            case digits (src, "", 0) of
              (_, 0, _) => NONE
            | (part, _, after) =>
                if k = 1 then dot (after, 0, acc ^ part)
                else
                  (case getc after of
                     SOME (#".", rest) => dot (rest, k - 1, acc ^ part ^ ".")
                   | _ => NONE)
      in dot (StringCvt.skipWS getc src, 4, "") end
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

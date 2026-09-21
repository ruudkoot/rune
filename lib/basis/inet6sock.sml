(* INet6Sock: the sockets of the Internet protocol version 6 (Rune's own, not
   of the specification). An address is the bytes of a `sockaddr_in6`, which
   only this structure takes apart. *)
structure RuneINet6Sock =
struct
  local
    val inet6Addr = _prim "socket_inet6_addr" : string * int -> string
    val inet6Parts = _prim "socket_inet6_parts" : string -> string list
    val const = _prim "posix_const" : string -> int
    val getopt' = _prim "socket_getopt" : int * int * int -> int
    val setopt' = _prim "socket_setopt" : int * int * int * int -> int
    fun named name = case const name of ~1 => 0 | v => v
    fun number s = case Int.fromString s of SOME n => n | NONE => 0
    datatype inet6' = Inet6Family
  in
    type inet6 = inet6'
    type 'sock_type sock = (inet6, 'sock_type) RuneSocket.sock
    type 'mode stream_sock = 'mode RuneSocket.stream sock
    type dgram_sock = RuneSocket.dgram sock
    type sock_addr = inet6 RuneSocket.sock_addr

    (* An address is its canonical text, so that two addresses written
       differently are one string and `=` compares addresses. Reading and
       writing are done here and not by the system, as `NetHostDB` does them
       for IPv4: then a host that compiles this library can run the checks
       even though it has no sockets. *)
    type in6_addr = string

    fun toString (a : in6_addr) = a

    local
      val digits = "0123456789abcdef"
      fun hex 0 = "0"
        | hex n =
            let fun go (0, acc) = acc
                  | go (k, acc) = go (Int.div (k, 16), String.str (String.sub (digits, Int.mod (k, 16))) ^ acc)
            in go (n, "") end
      fun digitOf c =
        if Char.isDigit c then SOME (Char.ord c - Char.ord #"0")
        else if c >= #"a" andalso c <= #"f" then SOME (Char.ord c - Char.ord #"a" + 10)
        else if c >= #"A" andalso c <= #"F" then SOME (Char.ord c - Char.ord #"A" + 10)
        else NONE
      (* up to four hexadecimal digits, and what is left *)
      fun group cs =
        let
          fun go (n, k, rest) =
            if k = 4 then SOME (n, rest)
            else
              case rest of
                c :: more => (case digitOf c of
                                SOME d => go (n * 16 + d, k + 1, more)
                              | NONE => if k = 0 then NONE else SOME (n, rest))
              | [] => if k = 0 then NONE else SOME (n, rest)
        in go (0, 0, cs) end
      (* a dotted quad, which fills the last two groups *)
      fun quad cs =
        let
          fun byte rest =
            let
              fun go (n, k, rest) =
                if k = 3 then (if n <= 255 then SOME (n, rest) else NONE)
                else
                  case rest of
                    c :: more => if Char.isDigit c then go (n * 10 + (Char.ord c - Char.ord #"0"), k + 1, more)
                                 else if k = 0 then NONE else SOME (n, rest)
                  | [] => if k = 0 then NONE else SOME (n, rest)
            in go (0, 0, rest) end
          fun dot (#"." :: rest) = SOME rest
            | dot _ = NONE
        in
          case byte cs of
            SOME (a, r1) =>
              (case Option.mapPartial byte (dot r1) of
                 SOME (b, r2) =>
                   (case Option.mapPartial byte (dot r2) of
                      SOME (c, r3) =>
                        (case Option.mapPartial byte (dot r3) of
                           SOME (d, []) => if a <= 255 andalso b <= 255 andalso c <= 255 andalso d <= 255
                                           then SOME [a * 256 + b, c * 256 + d] else NONE
                         | _ => NONE)
                    | NONE => NONE)
               | NONE => NONE)
          | NONE => NONE
        end
      (* the groups before and after a "::", if there is one *)
      fun parts cs =
        let
          fun go (cs, acc) =
            case quad cs of
              SOME two => SOME (List.rev acc @ two, [])
            | NONE =>
                case group cs of
                  NONE => NONE
                | SOME (n, rest) =>
                    (case rest of
                       [] => SOME (List.rev (n :: acc), [])
                     | #":" :: #":" :: more => SOME (List.rev (n :: acc), more)
                     | #":" :: more => go (more, n :: acc)
                     | _ => NONE)
        in go (cs, []) end
      fun after cs = case parts cs of SOME (front, []) => SOME front | _ => NONE
      (* glibc writes the dotted tail for a mapped or a compatible address *)
      fun dotted (base, len, g : int list) =
        base = 0 andalso (len = 6
                          orelse (len = 7 andalso List.nth (g, 7) <> 1)
                          orelse (len = 5 andalso List.nth (g, 5) = 65535))
      (* the longest run of zero groups, leftmost on a tie, of two or more *)
      fun longestZeros g =
        let
          fun go (i, bestBase, bestLen, base, len) =
            if i = 8 then
              let val (b, l) = if len > bestLen then (base, len) else (bestBase, bestLen)
              in if l >= 2 then (b, l) else (~1, 0) end
            else if List.nth (g, i) = 0 then
              go (i + 1, bestBase, bestLen, if len = 0 then i else base, len + 1)
            else
              let val (b, l) = if len > bestLen then (base, len) else (bestBase, bestLen)
              in go (i + 1, b, l, ~1, 0) end
        in go (0, ~1, 0, ~1, 0) end
      fun render g =
        let
          val (base, len) = longestZeros g
          fun colon i = if i > 0 andalso not (base >= 0 andalso i = base + len) then [":"] else []
          fun tail i =
            if dotted (base, len, g) andalso i = 6 then
              colon 6 @
              [Int.toString (Int.div (List.nth (g, 6), 256)), ".", Int.toString (Int.mod (List.nth (g, 6), 256)),
               ".", Int.toString (Int.div (List.nth (g, 7), 256)), ".", Int.toString (Int.mod (List.nth (g, 7), 256))]
            else if i = 8 then []
            else if base = i then "::" :: tail (i + len)
            else colon i @ hex (List.nth (g, i)) :: tail (i + 1)
        in String.concat (tail 0) end
    in
      (* The forms of inet_pton: eight groups of up to four hexadecimal
         digits, at most one "::" for a run of zeros, and a dotted quad in
         place of the last two groups. A scope after "%" is not taken. *)
      fun fromString s =
        let
          val cs = String.explode s
          fun whole g = if List.length g = 8 then SOME (render g) else NONE
          (* the groups before the "::", if the text begins with one *)
          fun split (#":" :: #":" :: rest) = SOME ([], SOME rest)
            | split (#":" :: _) = NONE
            | split cs =
                case parts cs of
                  NONE => NONE
                | SOME (front, []) => SOME (front, NONE)
                | SOME (front, rest) => SOME (front, SOME rest)
          fun joined (front, NONE) = whole front
            | joined (front, SOME rest) =
                case (if rest = [] then SOME [] else after rest) of
                  NONE => NONE
                | SOME back =>
                    let val fill = 8 - List.length front - List.length back
                    in if fill < 1 then NONE
                       else whole (front @ List.tabulate (fill, fn _ => 0) @ back)
                    end
        in
          if s = "" then NONE else Option.mapPartial joined (split cs)
        end
    end

    val inet6AF = RuneNet.familyFromInt (named "AF_INET6")

    fun toAddr (host : in6_addr, port) : sock_addr =
      case inet6Addr (host, port) of
        "" => raise RuneError.lastError ()
      | a => RuneSocket.ADDR a

    fun any port : sock_addr =
      case inet6Addr ("", port) of "" => raise RuneError.lastError () | a => RuneSocket.ADDR a

    fun fromAddr (RuneSocket.ADDR a : sock_addr) =
      case inet6Parts a of
        [host, port] => (host, number port)
      | _ => raise RuneError.lastError ()

    structure UDP =
    struct
      fun socket () : dgram_sock = RuneSocket.socket (inet6AF, RuneSocket.SOCK.dgram)
      fun socket' protocol : dgram_sock = RuneSocket.socket' (inet6AF, RuneSocket.SOCK.dgram, protocol)
    end

    structure TCP =
    struct
      fun 'mode socket () : 'mode stream_sock = RuneSocket.socket (inet6AF, RuneSocket.SOCK.stream)
      fun 'mode socket' protocol : 'mode stream_sock =
        RuneSocket.socket' (inet6AF, RuneSocket.SOCK.stream, protocol)
      fun 'mode getNODELAY (RuneSocket.SOCK fd : 'mode stream_sock) =
        getopt' (fd, named "IPPROTO_TCP", named "TCP_NODELAY") <> 0
      fun 'mode setNODELAY (RuneSocket.SOCK fd : 'mode stream_sock, v) =
        ignore (setopt' (fd, named "IPPROTO_TCP", named "TCP_NODELAY", if v then 1 else 0))
    end
  end
end

(* Implements: INET6_SOCK

   Status: extension *)
structure INet6Sock = RuneINet6Sock

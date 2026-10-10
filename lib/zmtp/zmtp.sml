(* Zmtp: ZeroMQ's sockets over the Basis's TCP sockets.

   Implements: ZMTP *)
structure Zmtp :> ZMTP =
struct
  datatype kind = Router | Dealer | Rep | Req | Pub | Sub
  exception Error of string

  fun kindName k =
    case k of Router => "ROUTER" | Dealer => "DEALER" | Rep => "REP" | Req => "REQ" | Pub => "PUB" | Sub => "SUB"

  type active = (INetSock.inet, Socket.active Socket.stream) Socket.sock
  type passive = (INetSock.inet, Socket.passive Socket.stream) Socket.sock

  datatype state = Greeting | Handshake | Ready | Closed

  type peer = {sock : active, inbuf : string ref, out : string ref, state : state ref,
               reader : ZmtpWire.reader ref, identity : string ref, topics : string list ref,
               parts : string list ref}

  type socket = {kind : kind, listener : passive option, peers : peer list ref,
                 inbox : string list list ref, counter : int ref, subscriptions : string list ref,
                 last : (peer * string list) option ref, turn : int ref, identity : string option,
                 port : int}

  fun fail (what, e) = raise Error (what ^ ": " ^ General.exnMessage e)

  fun bytes s = Word8VectorSlice.full (Byte.stringToBytes s)

  fun address (host, port) =
    if host = "*" orelse host = "" then INetSock.any port
    else
      case NetHostDB.fromString host of
        SOME a => INetSock.toAddr (a, port)
      | NONE =>
          case NetHostDB.getByName host of
            SOME e => INetSock.toAddr (NetHostDB.addr e, port)
          | NONE => raise Error ("no such host: " ^ host)

  fun newPeer (s : socket, sock : active) : peer =
    let
      val props = [("Socket-Type", kindName (#kind s))]
                  @ (case #identity s of SOME i => [("Identity", i)] | NONE => [])
      val p = {sock = sock, inbuf = ref "", state = ref Greeting, reader = ref ZmtpWire.reader,
               out = ref (ZmtpWire.greeting {mechanism = "NULL", server = false}
                          ^ ZmtpWire.encode (ZmtpWire.ready props)
                          ^ (if #kind s = Sub
                             then String.concat (map (fn t => ZmtpWire.encode (ZmtpWire.Command {name = "SUBSCRIBE", data = t}))
                                                     (!(#subscriptions s)))
                             else "")),
               identity = ref "", topics = ref [], parts = ref []}
    in
      (INetSock.TCP.setNODELAY (sock, true) handle _ => ());
      #peers s := !(#peers s) @ [p];
      p
    end

  fun bind (k, {host, port}) =
    let
      val l = INetSock.TCP.socket ()
      val () = (Socket.Ctl.setREUSEADDR (l, true); Socket.bind (l, address (host, port)); Socket.listen (l, 16))
               handle Error m => raise Error m | e => fail ("bind", e)
      val (_, p) = INetSock.fromAddr (Socket.Ctl.getSockName l)
    in
      {kind = k, listener = SOME l, peers = ref [], inbox = ref [], counter = ref 0, subscriptions = ref [],
       last = ref NONE, turn = ref 0, identity = NONE, port = p}
    end

  fun connect (k, {host, port}, {identity}) =
    let
      val sock = INetSock.TCP.socket ()
      val () = Socket.connect (sock, address (host, port)) handle Error m => raise Error m | e => fail ("connect", e)
      val s = {kind = k, listener = NONE, peers = ref [], inbox = ref [], counter = ref 0, subscriptions = ref [],
               last = ref NONE, turn = ref 0, identity = identity, port = port}
    in
      ignore (newPeer (s, sock));
      s
    end

  fun port (s : socket) = #port s

  fun queue (p : peer, bytes) = #out p := !(#out p) ^ bytes

  fun subscribe (s : socket, prefix) =
    if #kind s <> Sub then raise Error "subscribe: not a SUB socket"
    else
      (#subscriptions s := !(#subscriptions s) @ [prefix];
       List.app (fn p => queue (p, ZmtpWire.encode (ZmtpWire.Command {name = "SUBSCRIBE", data = prefix}))) (!(#peers s)))

  fun live (s : socket) = List.filter (fn p => !(#state p) <> Closed) (!(#peers s))

  fun send (s : socket, parts) =
    case #kind s of
      Router =>
        (case parts of
           id :: rest =>
             (case List.find (fn p => !(#identity p) = id) (live s) of
                SOME p => queue (p, ZmtpWire.message rest)
              | NONE => ())
         | [] => ())
    | Dealer =>
        (case live s of
           [] => ()
         | ps => let val p = List.nth (ps, !(#turn s) mod List.length ps)
                 in #turn s := !(#turn s) + 1; queue (p, ZmtpWire.message parts) end)
    | Req =>
        (case live s of
           p :: _ => queue (p, ZmtpWire.message ("" :: parts))
         | [] => ())
    | Rep =>
        (case !(#last s) of
           SOME (p, envelope) => (#last s := NONE; queue (p, ZmtpWire.message (envelope @ parts)))
         | NONE => raise Error "send: a REP socket has no request to answer")
    | Pub =>
        let val first = case parts of x :: _ => x | [] => ""
        in
          List.app (fn p => if List.exists (fn t => String.isPrefix t first) (!(#topics p))
                            then queue (p, ZmtpWire.message parts) else ())
                   (live s)
        end
    | Sub => raise Error "send: a SUB socket does not send"

  fun receive (s : socket) =
    case !(#inbox s) of
      [] => NONE
    | m :: rest => (#inbox s := rest; SOME m)

  fun shut (p : peer) = (#state p := Closed; Socket.close (#sock p) handle _ => ())

  (* a whole message from a peer, as the socket's kind receives it *)
  fun deliver (s : socket, p : peer, parts) =
    let fun put m = #inbox s := !(#inbox s) @ [m]
    in
      case #kind s of
        Router => put (!(#identity p) :: parts)
      | Rep =>
          let
            fun split ([], _) = NONE
              | split ("" :: rest, env) = SOME (rev ("" :: env), rest)
              | split (x :: rest, env) = split (rest, x :: env)
          in
            case split (parts, []) of
              SOME (envelope, body) => (#last s := SOME (p, envelope); put body)
            | NONE => (#last s := SOME (p, []); put parts)
          end
      | Req => put (case parts of "" :: rest => rest | _ => parts)
      | Pub =>
          (* a subscription of ZMTP 3.0: 1 or 0 and the prefix *)
          (case parts of
             [m] => if size m > 0 andalso String.sub (m, 0) = #"\001" then #topics p := !(#topics p) @ [String.extract (m, 1, NONE)]
                    else if size m > 0 andalso String.sub (m, 0) = #"\000"
                    then #topics p := List.filter (fn t => t <> String.extract (m, 1, NONE)) (!(#topics p))
                    else ()
           | _ => ())
      | _ => put parts
    end

  fun handle' (s : socket, p : peer, f) =
    case (!(#state p), f) of
      (Handshake, ZmtpWire.Command {name = "READY", data}) =>
        let
          val props = ZmtpWire.properties data handle ZmtpWire.Malformed _ => []
          val given = case List.find (fn (k, _) => k = "Identity") props of SOME (_, v) => v | NONE => ""
          val id = if given <> "" then given
                   else (#counter s := !(#counter s) + 1;
                         "\000" ^ CharVector.tabulate (4, fn i => Char.chr ((!(#counter s) div (case i of 0 => 16777216 | 1 => 65536 | 2 => 256 | _ => 1)) mod 256)))
        in
          #identity p := id; #state p := Ready
        end
    | (Ready, ZmtpWire.Data {more, body}) =>
        if more then #parts p := body :: !(#parts p)
        else (deliver (s, p, rev (body :: !(#parts p))); #parts p := [])
    | (Ready, ZmtpWire.Command {name = "PING", data}) =>
        let val context = if size data >= 2 then String.extract (data, 2, NONE) else ""
        in queue (p, ZmtpWire.encode (ZmtpWire.Command {name = "PONG", data = context})) end
    | (Ready, ZmtpWire.Command {name = "SUBSCRIBE", data}) => #topics p := !(#topics p) @ [data]
    | (Ready, ZmtpWire.Command {name = "CANCEL", data}) => #topics p := List.filter (fn t => t <> data) (!(#topics p))
    | (_, ZmtpWire.Command {name = "ERROR", ...}) => shut p
    | _ => ()

  (* what has come from a peer *)
  fun absorb (s : socket, p : peer) =
    (if !(#state p) = Greeting andalso size (!(#inbuf p)) >= 64 then
       case ZmtpWire.readGreeting (String.substring (!(#inbuf p), 0, 64)) of
         SOME {mechanism = "NULL", ...} => (#state p := Handshake; #inbuf p := String.extract (!(#inbuf p), 64, NONE))
       | _ => shut p
     else ();
     if !(#state p) = Handshake orelse !(#state p) = Ready then
       let val (frames, rest) = ZmtpWire.feed (!(#reader p), !(#inbuf p))
       in #reader p := rest; #inbuf p := ""; List.app (fn f => handle' (s, p, f)) frames end
       handle ZmtpWire.Malformed _ => shut p
     else ())

  fun readPeer (s : socket, p : peer) =
    let
      fun go () =
        case (Socket.recvVecNB (#sock p, 65536) handle _ => SOME (Word8Vector.fromList [])) of
          NONE => ()
        | SOME v =>
            if Word8Vector.length v = 0 then shut p
            else (#inbuf p := !(#inbuf p) ^ Byte.bytesToString v; absorb (s, p); if !(#state p) <> Closed then go () else ())
    in
      if !(#state p) <> Closed then go () else ()
    end

  fun writePeer (p : peer) =
    if !(#state p) = Closed orelse !(#out p) = "" then ()
    else
      case (Socket.sendVecNB (#sock p, bytes (!(#out p))) handle _ => (shut p; NONE)) of
        SOME n => (#out p := String.extract (!(#out p), n, NONE); if n > 0 then writePeer p else ())
      | NONE => ()

  fun accept (s : socket) =
    case #listener s of
      NONE => ()
    | SOME l =>
        case (Socket.acceptNB l handle _ => NONE) of
          SOME (sock, _) => (ignore (newPeer (s, sock)); accept s)
        | NONE => ()

  fun pump (s : socket) =
    (accept s;
     List.app (fn p => (readPeer (s, p); writePeer p)) (!(#peers s));
     #peers s := List.filter (fn p => !(#state p) <> Closed) (!(#peers s)))

  fun descriptors (ss : socket list) =
    let
      val rds = List.concat (map (fn s => (case #listener s of SOME l => [Socket.sockDesc l] | NONE => [])
                                          @ map (fn p => Socket.sockDesc (#sock p)) (!(#peers s))) ss)
      val wrs = List.concat (map (fn s => List.mapPartial (fn p => if !(#out p) <> "" then SOME (Socket.sockDesc (#sock p)) else NONE)
                                                          (!(#peers s))) ss)
    in
      (rds, wrs)
    end

  fun wait (ss, timeout) =
    let
      val deadline = Option.map (fn t => Time.+ (Time.now (), t)) timeout
      fun loop () =
        (List.app pump ss;
         case List.filter (fn s => not (null (!(#inbox s)))) ss of
           [] =>
             let
               val left = Option.map (fn d => let val now = Time.now () in if Time.< (now, d) then Time.- (d, now) else Time.zeroTime end) deadline
             in
               if left = SOME Time.zeroTime then []
               else
                 let val (rds, wrs) = descriptors ss
                 in
                   ignore (Socket.select {rds = rds, wrs = wrs, exs = [], timeout = left}) handle _ => ();
                   loop ()
                 end
             end
         | ready => ready)
    in
      loop ()
    end

  fun flush (s, timeout) =
    let
      val deadline = Option.map (fn t => Time.+ (Time.now (), t)) timeout
      fun loop () =
        (pump s;
         if List.all (fn p => !(#out p) = "") (!(#peers s)) then ()
         else
           let
             val left = Option.map (fn d => let val now = Time.now () in if Time.< (now, d) then Time.- (d, now) else Time.zeroTime end) deadline
           in
             if left = SOME Time.zeroTime then ()
             else
               let val (rds, wrs) = descriptors [s]
               in ignore (Socket.select {rds = rds, wrs = wrs, exs = [], timeout = left}) handle _ => (); loop () end
           end)
    in
      loop ()
    end

  fun close (s : socket) =
    (List.app shut (!(#peers s)); #peers s := [];
     case #listener s of SOME l => (Socket.close l handle _ => ()) | NONE => ())
end

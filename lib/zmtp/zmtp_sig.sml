(* ZeroMQ's sockets over ZMTP 3.1 with the NULL mechanism, on the Basis's
   TCP sockets: the kinds a Jupyter kernel and its clients use.

   A socket binds a port, where any number of peers connect, or connects
   to one. Nothing runs behind the program's back: `wait` reads and writes
   every connection of the sockets it is given until one of them has a
   message or the time is up, and `send` only queues what `wait` (or
   `flush`) writes. A `Router` receives each message with the identity of
   the peer that sent it first, and sends to the peer a message's first
   part names; a `Dealer` sends to its peers in turn; a `Rep` answers the
   peer of the last request with that request's envelope, and a `Req`
   puts the empty delimiter before what it sends and takes it off what it
   receives; a `Pub` sends to every peer that subscribed to a prefix of a
   message's first part, and a `Sub` subscribes.

   Area: Networking *)
signature ZMTP =
sig
  (* The kinds of socket. *)
  datatype kind = Router | Dealer | Rep | Req | Pub | Sub

  (* A socket of one of the kinds: its connections and what it has
     received. *)
  type socket

  (* What the operations raise when the system's sockets fail, or a
     socket is asked for what its kind does not do. *)
  exception Error of string

  (* `bind (k, {host, port})` is a socket of kind `k` listening at `host`
     (`"*"` for every address) and `port` (0 for one the system picks,
     which `port` tells).

     Raises: `Error` when the port cannot be bound. *)
  val bind : kind * {host : string, port : int} -> socket

  (* `connect (k, {host, port}, {identity})` is a socket of kind `k`
     connected to a socket bound at `host` and `port`, with the identity
     a `Router` there knows it by.

     Raises: `Error` when the connection is refused. *)
  val connect : kind * {host : string, port : int} * {identity : string option} -> socket

  (* `port s` is the port `s` is bound to or connected to. *)
  val port : socket -> int

  (* `subscribe (s, prefix)` asks the publishers `s` is connected to for
     the messages whose first part begins with `prefix`; `""` is all.

     Raises: `Error` when `s` is not a `Sub`. *)
  val subscribe : socket * string -> unit

  (* `send (s, parts)` queues the message of `parts` for the peers of
     `s`, as its kind sends.

     Raises: `Error` when `s` is a `Sub`, or a `Rep` that has no request
     to answer. *)
  val send : socket * string list -> unit

  (* `receive s` is the next message `s` has received, or `NONE`; it does
     not wait. *)
  val receive : socket -> string list option

  (* `wait (ss, t)` reads and writes the connections of `ss` until one of
     them has a message, or `t` has passed (`NONE`: as long as it takes),
     and is those that have one. *)
  val wait : socket list * Time.time option -> socket list

  (* `flush (s, t)` writes what is queued for the peers of `s`, waiting
     at most `t` for them to take it. *)
  val flush : socket * Time.time option -> unit

  (* `close s` closes `s` and its connections. *)
  val close : socket -> unit
end

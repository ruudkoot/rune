(* Jupyter's messaging protocol (5.4) for a kernel: the connection file,
   the signed messages of the wire, and a kernel's loop on its five
   channels, the language's part given as handlers.

   A message on the wire is the identities of the peer, the delimiter
   `<IDS|MSG>`, the HMAC-SHA256 of the next four parts in hexadecimal, the
   header, the parent's header, the metadata and the content, each JSON,
   and the binary buffers. A kernel binds the shell, control and stdin
   channels as ROUTERs, iopub as a PUB and heartbeat as a REP; it says
   `busy` on iopub before it handles a request and `idle` after, answers
   `kernel_info_request` and `shutdown_request` itself, and gives the
   other requests to the language.

   Area: Networking *)
signature JUPYTER =
sig
  (* The connection file a kernel is started with: where to bind, and the
     key and scheme of the signatures. *)
  type connection = {transport : string, ip : string, shell : int, iopub : int, stdin : int, control : int,
                     heartbeat : int, key : string, scheme : string}

  (* What `readConnection` raises for a connection file it cannot read. *)
  exception Connection of string

  (* `readConnection text` is the connection file `text`.

     Raises: `Connection` when it is not JSON with the fields of one. *)
  val readConnection : string -> connection

  (* A message's header. *)
  type header = {msgId : string, session : string, username : string, date : string, msgType : string,
                 version : string}

  (* A message, with the identities that route it. *)
  type message = {identities : string list, header : header, parent : Json.value, metadata : Json.value,
                  content : Json.value, buffers : string list}

  (* `headerJson h` is `h` as JSON, and `headerOf v` the header that `v` is.

     Example: `headerOf (headerJson {msgId = "1", session = "s", username = "u", date = "d", msgType = "t",
     version = "5.4"}) = SOME {msgId = "1", session = "s", username = "u", date = "d", msgType = "t", version = "5.4"}` *)
  val headerJson : header -> Json.value
  val headerOf : Json.value -> header option

  (* `sign (key, parts)` is the signature of the four JSON parts of a
     message under `key`: their HMAC-SHA256 in hexadecimal, or `""` when
     the key is empty. *)
  val sign : string * string list -> string

  (* `encode key m` is the parts of `m` on the wire, signed with `key`. *)
  val encode : string -> message -> string list

  (* `decode key parts` is the message of the wire's `parts`, or `NONE`
     when they are not one or their signature is not `key`'s.

     What `encode` writes, `decode` reads back with the same key, when the
     message's JSON is as lib/json reads it back; tests/lib/jupyter checks
     that, and that another key or a changed part is refused. *)
  val decode : string -> string list -> message option

  (* A kernel: its sockets, its session and the count of executions. *)
  type kernel

  (* `bind c` is a kernel bound at the ports of `c`.

     It raises lib/zmtp's error when a port cannot be bound. *)
  val bind : connection -> kernel

  (* What a handler is given: the request, and what it may do while it
     answers.

     `publish (msgType, content)` says something on iopub as the
     request's child, such as a `stream` or an `execute_result`.
     `input {prompt, password}` asks the client for a line of input on the
     stdin channel, where the request allows it (`NONE` where it does not
     or the client gave none). `idle ()`, which a handler that takes long
     calls now and then, writes what it published and answers the
     heartbeat. *)
  type request = {msgType : string, content : Json.value, publish : string * Json.value -> unit,
                  input : {prompt : string, password : bool} -> string option, idle : unit -> unit}

  (* `serve (k, {info, respond})` is the kernel's loop, until a
     `shutdown_request` ends it.

     `info` is the fields of
     `kernel_info_reply` that are the language's (`implementation`,
     `language_info`, `banner`, ...); `respond r` is the content of the
     reply to `r`, whose type is the request's with `_reply`, or `NONE`
     for no reply (a request the kernel does not know). *)
  val serve : kernel * {info : (string * Json.value) list, respond : request -> Json.value option} -> unit

  (* `close k` closes the kernel's sockets. *)
  val close : kernel -> unit
end

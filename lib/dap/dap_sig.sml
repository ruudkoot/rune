(* The Debug Adapter Protocol's messages: requests, responses and events
   as values, read from JSON and written to it, framed as the protocol
   frames them (`Content-Length`, `Framing`), and the events an adapter
   sends most.

   Every message has a sequence number, which the side that sends it
   counts from 1; a response names the request it answers by its number.

   Area: Data formats *)
signature DAP =
sig
  (* A message of the protocol. *)
  datatype message =
      Request of {seq : int, command : string, arguments : Json.value option}
    | Response of {seq : int, requestSeq : int, success : bool, command : string,
                   message : string option, body : Json.value option}
    | Event of {seq : int, event : string, body : Json.value option}

  (* `toJson m` is `m` as the protocol writes it, with its `type`. *)
  val toJson : message -> Json.value

  (* `fromJson v` is the message `v` is, or `NONE` when it is not one of
     the protocol's.

     Example: `fromJson (Json.decode "{\"seq\":1,\"type\":\"request\",\"command\":\"threads\"}")
     = SOME (Request {seq = 1, command = "threads", arguments = NONE})` *)
  val fromJson : Json.value -> message option

  (* `encode m` is `m` framed for the wire: its header and its JSON.

     Example: `String.isPrefix "Content-Length: " (encode (Event {seq = 1, event = "initialized", body = NONE}))` *)
  val encode : message -> string

  (* `decode s` is the message whose body, its framing taken off, is `s`,
     or `NONE` when it is no message. *)
  val decode : string -> message option

  (* `reply {seq, request, body}` is the successful response numbered
     `seq` to `request`, or `NONE` when `request` is no request. *)
  val reply : {seq : int, request : message, body : Json.value option} -> message option

  (* `refuse {seq, request, message}` is the failed response numbered `seq`
     to `request`, saying `message`, or `NONE` when `request` is no
     request. *)
  val refuse : {seq : int, request : message, message : string} -> message option

  (* `initialized seq` is the event that the adapter is ready to be
     configured. *)
  val initialized : int -> message

  (* `stopped {seq, reason, threadId, text}` is the event that a thread
     stopped, for a reason such as `"breakpoint"`, `"step"`, `"exception"`
     or `"pause"`. *)
  val stopped : {seq : int, reason : string, threadId : int, text : string option} -> message

  (* `output {seq, category, output}` is the event of the program's or the
     adapter's output, of a category such as `"stdout"`, `"stderr"` or
     `"console"`. *)
  val output : {seq : int, category : string, output : string} -> message

  (* `terminated seq` is the event that the session has ended. *)
  val terminated : int -> message

  (* `exited {seq, exitCode}` is the event that the program has exited,
     with its status. *)
  val exited : {seq : int, exitCode : int} -> message
end

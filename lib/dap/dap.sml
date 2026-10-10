(* Dap: the Debug Adapter Protocol's messages over Json.

   Implements: DAP *)
structure Dap :> DAP =
struct
  datatype message =
      Request of {seq : int, command : string, arguments : Json.value option}
    | Response of {seq : int, requestSeq : int, success : bool, command : string,
                   message : string option, body : Json.value option}
    | Event of {seq : int, event : string, body : Json.value option}

  fun opt (name, SOME v) = [(name, v)]
    | opt (_, NONE) = []

  fun toJson m =
    case m of
      Request {seq, command, arguments} =>
        Json.Object ([("seq", Json.int seq), ("type", Json.String "request"), ("command", Json.String command)]
                     @ opt ("arguments", arguments))
    | Response {seq, requestSeq, success, command, message, body} =>
        Json.Object ([("seq", Json.int seq), ("type", Json.String "response"), ("request_seq", Json.int requestSeq),
                      ("success", Json.Bool success), ("command", Json.String command)]
                     @ opt ("message", Option.map Json.String message) @ opt ("body", body))
    | Event {seq, event, body} =>
        Json.Object ([("seq", Json.int seq), ("type", Json.String "event"), ("event", Json.String event)]
                     @ opt ("body", body))

  fun fromJson v =
    let
      fun get name = Json.member (name, v)
      fun int name = Option.mapPartial Json.toInt (get name)
      fun str name = case get name of SOME (Json.String s) => SOME s | _ => NONE
    in
      case (int "seq", str "type") of
        (SOME seq, SOME "request") =>
          Option.map (fn c => Request {seq = seq, command = c, arguments = get "arguments"}) (str "command")
      | (SOME seq, SOME "response") =>
          (case (int "request_seq", get "success", str "command") of
             (SOME r, SOME (Json.Bool ok), SOME c) =>
               SOME (Response {seq = seq, requestSeq = r, success = ok, command = c, message = str "message",
                               body = get "body"})
           | _ => NONE)
      | (SOME seq, SOME "event") => Option.map (fn e => Event {seq = seq, event = e, body = get "body"}) (str "event")
      | _ => NONE
    end

  fun encode m = Framing.frame (Framing.ContentLength, Json.encode (toJson m))

  fun decode body = fromJson (Json.decode body) handle Json.Syntax _ => NONE

  fun reply {seq, request = Request {seq = r, command, ...}, body} =
        SOME (Response {seq = seq, requestSeq = r, success = true, command = command, message = NONE, body = body})
    | reply _ = NONE

  fun refuse {seq, request = Request {seq = r, command, ...}, message} =
        SOME (Response {seq = seq, requestSeq = r, success = false, command = command, message = SOME message,
                        body = SOME (Json.Object [("error", Json.Object [("id", Json.int 1), ("format", Json.String message)])])})
    | refuse _ = NONE

  fun initialized seq = Event {seq = seq, event = "initialized", body = NONE}

  fun stopped {seq, reason, threadId, text} =
    Event {seq = seq, event = "stopped",
           body = SOME (Json.Object ([("reason", Json.String reason), ("threadId", Json.int threadId)]
                                     @ opt ("text", Option.map Json.String text)))}

  fun output {seq, category, output = text} =
    Event {seq = seq, event = "output",
           body = SOME (Json.Object [("category", Json.String category), ("output", Json.String text)])}

  fun terminated seq = Event {seq = seq, event = "terminated", body = NONE}

  fun exited {seq, exitCode} =
    Event {seq = seq, event = "exited", body = SOME (Json.Object [("exitCode", Json.int exitCode)])}
end

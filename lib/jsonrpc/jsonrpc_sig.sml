(* JSON-RPC 2.0: requests, notifications and responses as values, read
   from JSON and written to it, with the errors of the specification and
   the cancellation the Language Server Protocol adds.

   Area: Data formats *)
signature JSON_RPC =
sig
  (* A request's id: an integer number or a string. Numbers retain their
     full precision on hosts whose default integer has only 31 bits. *)
  datatype id = Number of IntInf.int | String of string

  (* An error's code and message, and anything more about it. *)
  type error = {code : IntInf.int, message : string, data : Json.value option}

  (* What a request came to: its result, or an error. *)
  datatype outcome = Result of Json.value | Error of error

  (* A message: a request, a notification, or a response.

     A `Request` asks for a `Response` with its id; a `Notification` asks
     for none; a `Response` carries the outcome, its id `NONE` when the
     request's could not be read. *)
  datatype message =
      Request of {id : id, method : string, params : Json.value option}
    | Notification of {method : string, params : Json.value option}
    | Response of {id : id option, outcome : outcome}

  (* A message read, or the error that answers what could not be read,
     with the id of the request when it could be read. *)
  datatype read = Message of message | Invalid of error * id option

  (* The code of an error: the text is no JSON.

     Example: `parseError = ~32700` *)
  val parseError : IntInf.int

  (* The code of an error: the JSON is no request.

     Example: `invalidRequest = ~32600` *)
  val invalidRequest : IntInf.int

  (* The code of an error: the server has no such method.

     Example: `methodNotFound = ~32601` *)
  val methodNotFound : IntInf.int

  (* The code of an error: the parameters are not what the method takes.

     Example: `invalidParams = ~32602` *)
  val invalidParams : IntInf.int

  (* The code of an error: the server failed.

     Example: `internalError = ~32603` *)
  val internalError : IntInf.int

  (* The code of an error, the Language Server Protocol's: the request was
     cancelled.

     Example: `requestCancelled = ~32800` *)
  val requestCancelled : IntInf.int

  (* `toJson m` is `m` as a JSON object, with `"jsonrpc": "2.0"`. *)
  val toJson : message -> Json.value

  (* `fromJson v` is the message `v` is, or the error that answers it:
     `invalidRequest`, with the request's id when it has one it could
     read.

     Example: `fromJson (Json.decode "{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}")
     = Message (Notification {method = "exit", params = NONE})` *)
  val fromJson : Json.value -> read

  (* `decode s` is the messages of the text `s`, each read or answered as
     `fromJson` reads or answers it.

     The text is one message, or a batch, an array of them; a text that is
     no JSON, or an empty batch, is one answer. *)
  val decode : string -> read list

  (* `encode ms` is the messages as text: one alone, a batch as an array.

     Example: `encode [Notification {method = "exit", params = NONE}] =
     "{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}"` *)
  val encode : message list -> string

  (* What a handler raises for a method it does not have. *)
  exception Unknown

  (* What a handler raises to answer with an error. *)
  exception Failed of error

  (* `answer (serve, m)` is what a server answers `m` with, calling
     `serve (method, params)`.

     For a request it is the result of `serve`, an error when it raises
     `Failed`, and `methodNotFound` when it raises `Unknown`; for a
     notification nothing, `serve` being called all the same; and nothing
     for a response. *)
  val answer : (string * Json.value option -> Json.value) * message -> message option

  (* `cancel i` is the notification that asks the server to give up the
     request `i` (`$/cancelRequest`).

     Example: `cancelled (cancel (Number 3)) = SOME (Number 3)` *)
  val cancel : id -> message

  (* `cancelled m` is the request `m` asks to cancel, if it is a
     `$/cancelRequest`. *)
  val cancelled : message -> id option
end

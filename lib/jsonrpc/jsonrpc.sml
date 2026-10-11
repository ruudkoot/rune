(* JsonRpc: JSON-RPC 2.0's messages over Json.

   Implements: JSON_RPC *)
structure JsonRpc :> JSON_RPC =
struct
  datatype id = Number of int | String of string
  type error = {code : int, message : string, data : Json.value option}
  datatype outcome = Result of Json.value | Error of error
  datatype message =
      Request of {id : id, method : string, params : Json.value option}
    | Notification of {method : string, params : Json.value option}
    | Response of {id : id option, outcome : outcome}
  datatype read = Message of message | Invalid of error * id option

  val parseError = ~32700
  val invalidRequest = ~32600
  val methodNotFound = ~32601
  val invalidParams = ~32602
  val internalError = ~32603
  val requestCancelled = ~32800

  exception Unknown
  exception Failed of error

  fun idJson (Number n) = Json.int n
    | idJson (String s) = Json.String s

  fun errorJson ({code, message, data} : error) =
    Json.Object ([("code", Json.int code), ("message", Json.String message)]
                 @ (case data of SOME d => [("data", d)] | NONE => []))

  fun toJson m =
    let
      val version = ("jsonrpc", Json.String "2.0")
      fun params NONE = []
        | params (SOME p) = [("params", p)]
    in
      case m of
        Request {id, method, params = p} =>
          Json.Object ([version, ("id", idJson id), ("method", Json.String method)] @ params p)
      | Notification {method, params = p} => Json.Object ([version, ("method", Json.String method)] @ params p)
      | Response {id, outcome} =>
          Json.Object ([version, ("id", case id of SOME i => idJson i | NONE => Json.Null)]
                       @ (case outcome of Result r => [("result", r)] | Error e => [("error", errorJson e)]))
    end

  fun bad (why, id) = Invalid ({code = invalidRequest, message = "Invalid Request: " ^ why, data = NONE}, id)

  fun idOf v =
    case v of
      Json.Number _ => Option.map Number (Json.toInt v)
    | Json.String s => SOME (String s)
    | _ => NONE

  fun fromJson v =
    case v of
      Json.Object members =>
        let
          fun get name = Json.member (name, v)
          val id = Option.mapPartial idOf (get "id")
          val idOk = case get "id" of NONE => true | SOME Json.Null => true | SOME i => isSome (idOf i)
          val params = get "params"
          val paramsOk = case params of NONE => true | SOME (Json.Object _) => true | SOME (Json.Array _) => true | _ => false
        in
          if get "jsonrpc" <> SOME (Json.String "2.0") then bad ("\"jsonrpc\" is not \"2.0\"", id)
          else if not idOk then bad ("an id that is no number or string", NONE)
          else
            case get "method" of
              SOME (Json.String m) =>
                if not paramsOk then bad ("params that are no array or object", id)
                else (case get "id" of
                        NONE => Message (Notification {method = m, params = params})
                      | SOME _ => (case id of
                                     SOME i => Message (Request {id = i, method = m, params = params})
                                   | NONE => bad ("a request whose id is null", NONE)))
            | SOME _ => bad ("a method that is no string", id)
            | NONE =>
                (case (get "result", get "error") of
                   (SOME r, NONE) => Message (Response {id = id, outcome = Result r})
                 | (NONE, SOME (e as Json.Object _)) =>
                     (case (Option.mapPartial Json.toInt (Json.member ("code", e)), Json.member ("message", e)) of
                        (SOME code, SOME (Json.String msg)) =>
                          Message (Response {id = id, outcome = Error {code = code, message = msg,
                                                                      data = Json.member ("data", e)}})
                      | _ => bad ("an error without a code and a message", id))
                 | _ => bad ("neither a method, nor one of a result and an error", id))
        end
    | _ => bad ("not an object", NONE)

  datatype parsed = Parsed of Json.value | Unparsed of string

  fun decode text =
    case (Parsed (Json.decode text) handle Json.Syntax (_, why) => Unparsed why) of
      Unparsed why => [Invalid ({code = parseError, message = "Parse error: " ^ why, data = NONE}, NONE)]
    | Parsed (Json.Array []) => [bad ("an empty batch", NONE)]
    | Parsed (Json.Array vs) => map fromJson vs
    | Parsed v => [fromJson v]

  fun encode [m] = Json.encode (toJson m)
    | encode ms = Json.encode (Json.Array (map toJson ms))

  fun answer (serve, m) =
    case m of
      Request {id, method, params} =>
        SOME (Response {id = SOME id,
                        outcome = (Result (serve (method, params))
                                   handle Unknown => Error {code = methodNotFound, message = "Method not found: " ^ method,
                                                            data = NONE}
                                        | Failed e => Error e)})
    | Notification {method, params} => ((ignore (serve (method, params)) handle Unknown => () | Failed _ => ()); NONE)
    | Response _ => NONE

  fun cancel i = Notification {method = "$/cancelRequest", params = SOME (Json.Object [("id", idJson i)])}

  fun cancelled (Notification {method = "$/cancelRequest", params = SOME p}) =
        Option.mapPartial idOf (Json.member ("id", p))
    | cancelled _ = NONE
end

(* LSP's envelope and common wire values over the JSON-RPC library.

   Implements: LSP_PROTOCOL *)
structure LspProtocol :> LSP_PROTOCOL =
struct
  type integer = IntInf.int
  type position = {line : integer, character : integer}
  type range = {start : position, stop : position}
  datatype encoding = Utf8 | Utf16 | Utf32
  type capabilities = {raw : Json.value, encoding : encoding}
  datatype decoded = Message of JsonRpc.message
                   | Invalid of {error : JsonRpc.error, id : JsonRpc.id option, reply : bool}
  val version = "3.18.0"
  val minInteger = valOf (IntInf.fromString "-2147483648")
  val maxInteger = valOf (IntInf.fromString "2147483647")
  val serverNotInitialized = IntInf.fromInt ~32002
  val contentModified = IntInf.fromInt ~32801
  val serverCancelled = IntInf.fromInt ~32802
  val requestFailed = IntInf.fromInt ~32803
  fun inRange n = IntInf.<= (minInteger, n) andalso IntInf.<= (n, maxInteger)
  fun integer (value as Json.Number s) =
        (* Reject huge untrusted numerals before arbitrary-precision
           conversion: all valid signed 32-bit spellings fit 11 bytes. *)
        if size s > 11 then NONE else
          (case Json.toIntInf value of SOME n => if inRange n then SOME n else NONE | NONE => NONE)
    | integer _ = NONE
  fun uinteger value = case integer value of SOME n => if IntInf.>= (n, 0) then SOME n else NONE | NONE => NONE
  fun integerToJson n = if inRange n then Json.intInf n else raise Domain
  fun idFromJson (Json.String s) = if Utf8.isValid s then SOME (JsonRpc.String s) else NONE
    | idFromJson v = Option.map JsonRpc.Number (integer v)
  fun idToJson (JsonRpc.Number n) = integerToJson n
    | idToJson (JsonRpc.String s) = if Utf8.isValid s then Json.String s else raise Domain
  fun unsignedToJson n = if IntInf.>= (n, 0) then integerToJson n else raise Domain
  fun unique names (Json.Object fields) = List.all (fn name =>
        length (List.filter (fn (key, _) => key = name) fields) <= 1) names
    | unique _ _ = false
  fun coordinate key value = Option.mapPartial uinteger (Json.member (key, value))
  fun positionFromJson value =
    if not (unique ["line", "character"] value) then NONE else
      case (coordinate "line" value, coordinate "character" value) of
        (SOME line, SOME character) => SOME {line = line, character = character} | _ => NONE
  fun positionToJson ({line, character} : position) =
    Json.Object [("line", unsignedToJson line), ("character", unsignedToJson character)]
  fun ordered (a : position, b : position) =
    IntInf.< (#line a, #line b) orelse (#line a = #line b andalso IntInf.<= (#character a, #character b))
  fun rangeFromJson value =
    if not (unique ["start", "end"] value) then NONE else
      case (Option.mapPartial positionFromJson (Json.member ("start", value)),
            Option.mapPartial positionFromJson (Json.member ("end", value))) of
        (SOME start, SOME stop) => if ordered (start, stop) then SOME {start = start, stop = stop} else NONE
      | _ => NONE
  fun rangeToJson ({start, stop} : range) =
    if ordered (start, stop) then Json.Object [("start", positionToJson start), ("end", positionToJson stop)]
    else raise Domain
  fun idValid (JsonRpc.Number n) = inRange n | idValid (JsonRpc.String s) = Utf8.isValid s
  fun decode text =
    let
      fun invalid code message id reply = Invalid {error = {code = code, message = message, data = NONE},
                                                   id = id, reply = reply}
      fun value raw =
        let
          val response = not (isSome (Json.member ("method", raw)))
              andalso (isSome (Json.member ("result", raw)) orelse isSome (Json.member ("error", raw)))
          val notification = Json.member ("jsonrpc", raw) = SOME (Json.String "2.0")
              andalso (case Json.member ("method", raw) of SOME (Json.String _) => true | _ => false)
              andalso not (isSome (Json.member ("id", raw)))
          val reply = not response andalso not notification
          fun bad message id = invalid JsonRpc.invalidRequest message id reply
          val id = Option.mapPartial idFromJson (Json.member ("id", raw))
          val numericIdOK = case Json.member ("id", raw) of SOME (v as Json.Number _) => isSome (integer v) | _ => true
          val codeOK = case Json.member ("error", raw) of NONE => true
            | SOME error => (case Json.member ("code", error) of SOME v => isSome (integer v) | NONE => false)
          val mixed = isSome (Json.member ("method", raw))
              andalso (isSome (Json.member ("result", raw)) orelse isSome (Json.member ("error", raw)))
        in
          if not (unique ["jsonrpc", "id", "method", "params", "result", "error"] raw)
          then bad "ambiguous or non-object LSP envelope" NONE
          else if not numericIdOK then bad "request id is outside the LSP integer range" NONE
          else if not codeOK then bad "error code is outside the LSP integer range" id
          else if mixed then bad "message mixes request and response members" id
          else case JsonRpc.fromJson raw of
            JsonRpc.Message message => Message message
          | JsonRpc.Invalid (error, id) => Invalid {error = error, id = id, reply = reply}
        end
    in value (Json.decode text)
       handle Json.Syntax (_, why) => invalid JsonRpc.parseError ("invalid JSON: " ^ why) NONE true
    end
  fun encode message =
    let
      fun checkId id = if idValid id then () else raise Domain
      fun params NONE = () | params (SOME (Json.Object _)) = () | params (SOME (Json.Array _)) = ()
        | params _ = raise Domain
      val () = case message of
          JsonRpc.Request {id, params = p, ...} => (checkId id; params p)
        | JsonRpc.Notification {params = p, ...} => params p
        | JsonRpc.Response {id, outcome} =>
            (Option.app checkId id;
             case outcome of JsonRpc.Error {code, ...} => if inRange code then () else raise Domain | _ => ())
      val raw = JsonRpc.toJson message
      fun valid depth v =
        if depth > Json.maxDepth then false else case v of
          Json.String s => Utf8.isValid s
        | Json.Array vs => List.all (valid (depth + 1)) vs
        | Json.Object fields => List.all (fn (key, v) => Utf8.isValid key andalso valid (depth + 1) v) fields
        | _ => true
    in if valid 0 raw then Json.encode raw else raise Domain end
  fun path (v, []) = SOME v
    | path (v, key :: rest) = Option.mapPartial (fn x => path (x, rest)) (Json.member (key, v))
  fun capabilities (v as Json.Object _) =
        let
          val generalOK = case Json.member ("general", v) of NONE => true | SOME (Json.Object _) => true | _ => false
          val encodings = case path (v, ["general", "positionEncodings"]) of
              NONE => SOME []
            | SOME (Json.Array xs) =>
                if List.all (fn Json.String _ => true | _ => false) xs
                then SOME (List.map (fn Json.String s => s | _ => "") xs) else NONE
            | _ => NONE
        in if not generalOK then NONE else case encodings of NONE => NONE | SOME offered =>
          let val encoding = if List.exists (fn s => s = "utf-8") offered then Utf8
                             else if List.exists (fn s => s = "utf-16") offered then Utf16
                             else if List.exists (fn s => s = "utf-32") offered then Utf32 else Utf16
          in SOME {raw = v, encoding = encoding} end end
    | capabilities _ = NONE
  fun supports ({raw, ...} : capabilities, keys) = path (raw, keys) = SOME (Json.Bool true)
  fun positionEncoding ({encoding, ...} : capabilities) = encoding
  fun rawCapabilities ({raw, ...} : capabilities) = raw
  fun encodingName Utf8 = "utf-8" | encodingName Utf16 = "utf-16" | encodingName Utf32 = "utf-32"
end

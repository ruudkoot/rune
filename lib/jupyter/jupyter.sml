(* Jupyter: a kernel's side of Jupyter's messaging protocol, over Zmtp.

   Implements: JUPYTER *)
structure Jupyter :> JUPYTER =
struct
  type connection = {transport : string, ip : string, shell : int, iopub : int, stdin : int, control : int,
                     heartbeat : int, key : string, scheme : string}
  exception Connection of string

  type header = {msgId : string, session : string, username : string, date : string, msgType : string,
                 version : string}
  type message = {identities : string list, header : header, parent : Json.value, metadata : Json.value,
                  content : Json.value, buffers : string list}
  type request = {msgType : string, content : Json.value, publish : string * Json.value -> unit,
                  input : {prompt : string, password : bool} -> string option, idle : unit -> unit}

  fun field (name, v) = Json.member (name, v)
  fun str (name, v) = case field (name, v) of SOME (Json.String s) => SOME s | _ => NONE
  fun int (name, v) = Option.mapPartial Json.toInt (field (name, v))

  fun readConnection text =
    let
      val v = Json.decode text handle Json.Syntax (_, why) => raise Connection ("not JSON: " ^ why)
      fun need (f, name) = case f (name, v) of SOME x => x | NONE => raise Connection ("no " ^ name)
    in
      {transport = getOpt (str ("transport", v), "tcp"), ip = getOpt (str ("ip", v), "127.0.0.1"),
       shell = need (int, "shell_port"), iopub = need (int, "iopub_port"), stdin = need (int, "stdin_port"),
       control = need (int, "control_port"), heartbeat = need (int, "hb_port"), key = getOpt (str ("key", v), ""),
       scheme = getOpt (str ("signature_scheme", v), "hmac-sha256")}
    end

  fun headerJson ({msgId, session, username, date, msgType, version} : header) =
    Json.Object [("msg_id", Json.String msgId), ("session", Json.String session), ("username", Json.String username),
                 ("date", Json.String date), ("msg_type", Json.String msgType), ("version", Json.String version)]

  fun headerOf v =
    case (str ("msg_id", v), str ("msg_type", v)) of
      (SOME id, SOME t) =>
        SOME {msgId = id, session = getOpt (str ("session", v), ""), username = getOpt (str ("username", v), ""),
              date = getOpt (str ("date", v), ""), msgType = t, version = getOpt (str ("version", v), "")}
    | _ => NONE

  fun sign (key, parts) =
    if key = "" then "" else Hex.fromBytes (HmacSha256.macParts {key = key, parts = parts})

  val delimiter = "<IDS|MSG>"

  fun encode key ({identities, header, parent, metadata, content, buffers} : message) =
    let val parts = map Json.encode [headerJson header, parent, metadata, content]
    in identities @ [delimiter, sign (key, parts)] @ parts @ buffers end

  fun decode key parts =
    let
      fun split ([], _) = NONE
        | split (x :: rest, ids) = if x = delimiter then SOME (rev ids, rest) else split (rest, x :: ids)
    in
      case split (parts, []) of
        SOME (ids, signed :: h :: p :: m :: c :: buffers) =>
          if key <> "" andalso not (HmacSha256.equal (signed, sign (key, [h, p, m, c]))) then NONE
          else
            ((case (headerOf (Json.decode h), Json.decode p, Json.decode m, Json.decode c) of
                (SOME header, parent, metadata, content) =>
                  SOME {identities = ids, header = header, parent = parent, metadata = metadata, content = content,
                        buffers = buffers}
              | _ => NONE)
             handle Json.Syntax _ => NONE)
      | _ => NONE
    end

  type kernel = {connection : connection, shell : Zmtp.socket, control : Zmtp.socket, stdin : Zmtp.socket,
                 iopub : Zmtp.socket, heartbeat : Zmtp.socket, session : string, count : int ref, serial : int ref}

  fun bind (c : connection) =
    let
      fun at (k, p) = Zmtp.bind (k, {host = #ip c, port = p})
      val now = Time.toMilliseconds (Time.now ())
    in
      {connection = c, shell = at (Zmtp.Router, #shell c), control = at (Zmtp.Router, #control c),
       stdin = at (Zmtp.Router, #stdin c), iopub = at (Zmtp.Pub, #iopub c), heartbeat = at (Zmtp.Rep, #heartbeat c),
       session = "rune-" ^ LargeInt.toString now, count = ref 0, serial = ref 0}
    end

  fun close (k : kernel) = List.app Zmtp.close [#shell k, #control k, #stdin k, #iopub k, #heartbeat k]

  fun date () = Date.fmt "%Y-%m-%dT%H:%M:%SZ" (Date.fromTimeUniv (Time.now ()))

  fun header (k : kernel, msgType) =
    (#serial k := !(#serial k) + 1;
     {msgId = #session k ^ "-" ^ Int.toString (!(#serial k)), session = #session k, username = "kernel",
      date = date (), msgType = msgType, version = "5.4"})

  fun reply (k : kernel, socket, parent : message, msgType, content) =
    Zmtp.send (socket, encode (#key (#connection k))
                              {identities = #identities parent, header = header (k, msgType),
                               parent = headerJson (#header parent), metadata = Json.Object [],
                               content = content, buffers = []})

  fun publish (k : kernel, parent : message) (msgType, content) =
    Zmtp.send (#iopub k, encode (#key (#connection k))
                                {identities = [msgType], header = header (k, msgType),
                                 parent = headerJson (#header parent), metadata = Json.Object [],
                                 content = content, buffers = []})

  fun status (k, parent, s) = publish (k, parent) ("status", Json.Object [("execution_state", Json.String s)])

  (* what is queued written, and the heartbeat answered, without waiting *)
  fun idle (k : kernel) () =
    let fun beat () = case Zmtp.receive (#heartbeat k) of SOME m => (Zmtp.send (#heartbeat k, m); beat ()) | NONE => ()
    in
      ignore (Zmtp.wait ([#heartbeat k], SOME Time.zeroTime));
      beat ();
      List.app (fn s => Zmtp.flush (s, SOME Time.zeroTime)) [#iopub k, #heartbeat k]
    end

  (* a line asked of the client that sent parent, on the stdin channel, where
     it allows it; the heartbeat answered while it is waited for *)
  fun input (k : kernel, parent : message) {prompt, password} =
    case field ("allow_stdin", #content parent) of
      SOME (Json.Bool false) => NONE
    | _ =>
        let
          val key = #key (#connection k)
          val () = Zmtp.send (#stdin k, encode key
                                {identities = #identities parent, header = header (k, "input_request"),
                                 parent = headerJson (#header parent), metadata = Json.Object [],
                                 content = Json.Object [("prompt", Json.String prompt), ("password", Json.Bool password)],
                                 buffers = []})
          fun wait () =
            (ignore (Zmtp.wait ([#stdin k, #heartbeat k], NONE));
             idle k ();
             case Zmtp.receive (#stdin k) of
               SOME parts =>
                 (case decode key parts of
                    SOME r =>
                      if #msgType (#header r) = "input_reply" then
                        (case field ("value", #content r) of SOME (Json.String v) => SOME v | _ => NONE)
                      else wait ()
                  | NONE => wait ())
             | NONE => wait ())
        in wait () end

  fun replyType t = if String.isSuffix "_request" t then String.substring (t, 0, size t - 8) ^ "_reply" else t ^ "_reply"

  fun serve (k : kernel, {info, respond}) =
    let
      val key = #key (#connection k)
      val sockets = [#shell k, #control k, #stdin k, #heartbeat k, #iopub k]
      fun one (socket, m : message) =
        let
          val t = #msgType (#header m)
          val () = status (k, m, "busy")
          val stop =
            case t of
              "kernel_info_request" =>
                (reply (k, socket, m, "kernel_info_reply",
                        Json.Object ([("status", Json.String "ok"), ("protocol_version", Json.String "5.4")] @ info));
                 false)
            | "shutdown_request" =>
                (reply (k, socket, m, "shutdown_reply",
                        Json.Object [("status", Json.String "ok"),
                                     ("restart", getOpt (field ("restart", #content m), Json.Bool false))]);
                 true)
            | _ =>
                (case respond {msgType = t, content = #content m, publish = publish (k, m), input = input (k, m),
                               idle = idle k} of
                   SOME c => reply (k, socket, m, replyType t, c)
                 | NONE => ();
                 false)
        in
          status (k, m, "idle");
          stop
        end
      fun requests socket =
        case Zmtp.receive socket of
          NONE => false
        | SOME parts =>
            (case decode key parts of
               SOME m => one (socket, m) orelse requests socket
             | NONE => requests socket)
      fun loop () =
        (ignore (Zmtp.wait (sockets, NONE));
         (* the heartbeat comes back as it came *)
         let fun beat () = case Zmtp.receive (#heartbeat k) of SOME m => (Zmtp.send (#heartbeat k, m); beat ()) | NONE => ()
         in beat () end;
         if requests (#control k) orelse requests (#shell k) then
           List.app (fn s => Zmtp.flush (s, SOME (Time.fromSeconds 2))) [#shell k, #control k, #iopub k]
         else loop ())
    in
      loop ()
    end
end

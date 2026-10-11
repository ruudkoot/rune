(* `rune-repl --engine`: the engine (ReplEngine) on JSON-RPC 2.0
   (docs/repl-protocol.md; docs/plans/repl.md, D20 and M10), with
   lib/jsonrpc's framing and messages over lib/json.

   The protocol has a channel of its own, so that what the program writes
   stays on its standard output and error, which the front drains: by
   default the descriptors 3 (what the front sends) and 4 (what the engine
   answers), which a front that starts the engine as its child gives it;
   with --engine-connect PORT, a connection to 127.0.0.1:PORT whose first
   line is the token in RUNE_ENGINE_TOKEN, for a front that cannot pass
   descriptors (Windows). Messages are framed one to a line or behind
   Content-Length headers, told apart by the first byte the front sends.
   The engine flushes the program's output before each message it writes,
   so that output and answers keep their order for a front that drains
   the pipes before it reads a message.

   When the program reads its standard input, the engine asks the front
   (a request `input` of its own) and gives the program the answer. *)
structure ReplProtocol =
struct
  structure R = JsonRpc

  val protocol = 1

  (* ---- the channel ---- *)

  type channel = {read : unit -> string, write : string -> unit}

  fun fds (input : int, output : int) : channel =
    {read = fn () => Byte.bytesToString (Posix.IO.readVec (Posix.FileSys.wordToFD (Word.fromInt input), 65536)),
     write = fn s => ignore (Posix.IO.writeVec (Posix.FileSys.wordToFD (Word.fromInt output),
                                                Word8VectorSlice.full (Byte.stringToBytes s)))}

  (* a connection to 127.0.0.1:port, the token its first line *)
  fun connect (port : int, token : string) : channel =
    let
      val sock = INetSock.TCP.socket ()
      val addr = INetSock.toAddr (valOf (NetHostDB.fromString "127.0.0.1"), port)
      val () = Socket.connect (sock, addr)
      fun send s =
        let
          val v = Byte.stringToBytes s
          fun go i = if i >= Word8Vector.length v then ()
                     else go (i + Socket.sendVec (sock, Word8VectorSlice.slice (v, i, NONE)))
        in go 0 end
      val () = send (token ^ "\n")
    in
      {read = fn () => Byte.bytesToString (Socket.recvVec (sock, 65536)), write = send}
    end

  (* ---- framing, chosen by the first byte ---- *)

  val framing : Framing.framing option ref = ref NONE
  val reader : Framing.reader option ref = ref NONE
  val waiting : string list ref = ref []        (* messages read and not yet taken *)

  fun write (c : channel, m : R.message) : unit =
    (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr;
     #write c (Framing.frame (case !framing of SOME f => f | NONE => Framing.Lines, Json.encode (R.toJson m))))

  (* the next message's text, NONE at the end of the channel *)
  fun next (c : channel) : string option =
    case !waiting of
      m :: rest => (waiting := rest; SOME m)
    | [] =>
        let val bytes = #read c ()
        in
          if bytes = "" then NONE
          else
            let
              val () = case !framing of
                         SOME _ => ()
                       | NONE => framing := SOME (if String.sub (bytes, 0) = #"C" then Framing.ContentLength else Framing.Lines)
              val r = case !reader of SOME r => r | NONE => Framing.reader (valOf (!framing))
              val (ms, r) = Framing.feed (r, bytes)
            in reader := SOME r; waiting := ms; next c end
        end

  (* ---- the answers ---- *)

  fun str s = Json.String s
  fun int k = Json.int k
  fun field (params : Json.value option, name : string) : Json.value option =
    Option.mapPartial (fn p => Json.member (name, p)) params
  fun string (params, name) =
    case field (params, name) of
      SOME (Json.String s) => s
    | _ => raise R.Failed {code = R.invalidParams, message = "wants a string " ^ name, data = NONE}
  fun integer (params, name) =
    case Option.mapPartial Json.toInt (field (params, name)) of
      SOME k => k
    | NONE => raise R.Failed {code = R.invalidParams, message = "wants a number " ^ name, data = NONE}

  fun frameJson ({function, file, line, column} : Runtime.frame) =
    Json.Object [("function", str function), ("file", str file), ("line", int line), ("column", int column)]

  fun outcome ({ok, bindings, declared, messages, diagnostics, exn} : ReplEngine.outcome) : Json.value =
    Json.Object
      [("ok", Json.Bool ok),
       ("bindings", Json.Array (List.map (fn {name, ty, shown, id} =>
                                            Json.Object [("name", str name), ("type", str ty), ("shown", str shown),
                                                         ("handle", int id)]) bindings)),
       ("declared", Json.Array (List.map str declared)),
       ("messages", Json.Array (List.map str messages)),
       ("diagnostics", Json.Array diagnostics),
       ("exception", case exn of
                       NONE => Json.Null
                     | SOME {name, message, trace} =>
                         Json.Object [("name", str name), ("message", str message),
                                      ("trace", Json.Array (List.map frameJson trace))])]

  val methods = ["initialize", "ping", "eval", "use", "reload", "isComplete", "complete", "inspect", "typeAt",
                 "check", "value/children", "value/release", "interrupt", "shutdown"]

  val initialized = ref false
  exception Shutdown

  fun answer (method : string, params : Json.value option) : Json.value =
    case method of
      "initialize" =>
        (case Option.mapPartial Json.toInt (field (params, "protocol")) of
           SOME p => if p = protocol then () else raise R.Failed {code = ~32001, message = "this engine speaks protocol 1",
                                                                  data = NONE}
         | NONE => ();
         Option.app (fn w => ReplEngine.width := w) (Option.mapPartial Json.toInt (field (params, "width")));
         initialized := true;
         Json.Object [("protocol", int protocol), ("implementation", str ("rune-repl " ^ Config.version)),
                      ("methods", Json.Array (List.map str methods))])
    | "ping" => (case params of SOME p => p | NONE => Json.Null)
    | "shutdown" => raise Shutdown
    | _ =>
        if not (!initialized) then raise R.Failed {code = ~32002, message = "initialize first", data = NONE}
        else
          case method of
            "eval" => outcome (ReplEngine.eval (string (params, "text")))
          | "use" => outcome (ReplEngine.use (string (params, "path")))
          | "reload" => outcome (ReplEngine.reload (case field (params, "force") of SOME (Json.Bool b) => b | _ => false))
          | "isComplete" =>
              (case ReplEngine.isComplete (string (params, "text")) of
                 ReplEngine.Complete => Json.Object [("status", str "complete")]
               | ReplEngine.Incomplete k => Json.Object [("status", str "incomplete"), ("indent", int (2 * k))]
               | ReplEngine.Invalid => Json.Object [("status", str "invalid")])
          | "complete" =>
              let val {start, candidates} = ReplEngine.complete (string (params, "text"), integer (params, "offset"))
              in Json.Object [("start", int start), ("candidates", Json.Array (List.map str candidates))] end
          | "inspect" =>
              let val {info, doc} = ReplEngine.inspect (string (params, "name"))
              in Json.Object [("info", case info of SOME i => str i | NONE => Json.Null),
                              ("doc", case doc of SOME d => str d | NONE => Json.Null)] end
          | "typeAt" =>
              (case ReplEngine.typeAt (string (params, "text"), integer (params, "offset")) of
                 SOME {name, ty, start, stop} =>
                   Json.Object [("name", str name), ("type", str ty), ("start", int start), ("stop", int stop)]
               | NONE => Json.Null)
          | "check" => Json.Object [("diagnostics", Json.Array (ReplEngine.check (string (params, "text"))))]
          | "value/children" =>
              (Json.Array (List.map (fn {label, shown, id, more} =>
                                       Json.Object [("label", str label), ("shown", str shown), ("handle", int id),
                                                    ("more", Json.Bool more)])
                                    (ReplEngine.children (integer (params, "handle"))))
               handle Fail msg => raise R.Failed {code = R.invalidParams, message = msg, data = NONE})
          | "value/release" =>
              (case field (params, "handles") of
                 SOME (Json.Array hs) => (ReplEngine.release (List.mapPartial Json.toInt hs); Json.Null)
               | _ => raise R.Failed {code = R.invalidParams, message = "wants handles", data = NONE})
          | "interrupt" => Json.Null     (* idle: nothing runs; while code runs, the front's SIGINT *)
          | _ => raise R.Unknown

  (* ---- the program's input, asked of the front ---- *)

  val asked = ref 0
  val busy = ref false

  (* a request of the engine's own, and its answer; requests that come
     meanwhile are refused, the engine being busy *)
  fun ask (c : channel, method : string, params : Json.value) : Json.value option =
    let
      val () = asked := !asked + 1
      val id = R.String ("engine-" ^ Int.toString (!asked))
      val () = write (c, R.Request {id = id, method = method, params = SOME params})
      fun wait () =
        case next c of
          NONE => NONE
        | SOME text =>
            (case R.decode text of
               [R.Message (R.Response {id = SOME i, outcome = R.Result v})] => if i = id then SOME v else wait ()
             | [R.Message (R.Response {id = SOME i, outcome = R.Error _})] => if i = id then NONE else wait ()
             | [R.Message (R.Request {id = i, ...})] =>
                 (write (c, R.Response {id = SOME i, outcome = R.Error {code = ~32000, data = NONE,
                                                                        message = "busy: the program is reading its input"}});
                  wait ())
             | _ => wait ())
    in wait () end

  (* TextIO.stdIn over a reader whose reads are the front's answers to input *)
  fun inputFromFront (c : channel) : unit =
    let
      val (TextPrimIO.RD {name, chunkSize, getPos, setPos, endPos, verifyPos, close, ioDesc, ...}, ahead) =
        TextIO.StreamIO.getReader (TextIO.getInstream TextIO.stdIn)
      fun readVec _ =
        case ask (c, "input", Json.Object []) of
          SOME (Json.String s) => s
        | _ => ""
      val reader =
        TextPrimIO.RD {name = name, chunkSize = chunkSize, readVec = SOME readVec, readArr = NONE,
                       readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE, avail = fn () => NONE,
                       getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos, close = close,
                       ioDesc = ioDesc}
    in
      TextIO.setInstream (TextIO.stdIn, TextIO.StreamIO.mkInstream (reader, ahead))
    end

  (* ---- the loop ---- *)

  fun notify (c : channel, method : string, params : Json.value) =
    write (c, R.Notification {method = method, params = SOME params})

  fun serve (c : channel) : unit =
    let
      fun one text =
        List.app
          (fn R.Invalid (e, id) => write (c, R.Response {id = id, outcome = R.Error e})
            | R.Message (R.Request {id, method, params}) =>
                (let
                  val () = notify (c, "status", Json.Object [("state", str "busy")])
                  val result =
                    (R.Result (answer (method, params))
                     handle R.Failed e => R.Error e
                          | R.Unknown => R.Error {code = R.methodNotFound, message = "no method " ^ method, data = NONE}
                          | Shutdown => raise Shutdown
                          | SML90.Interrupt => R.Error {code = R.requestCancelled, message = "interrupted", data = NONE}
                          | e => R.Error {code = ~32000, message = General.exnMessage e, data = NONE})
                in
                  write (c, R.Response {id = SOME id, outcome = result});
                  notify (c, "status", Json.Object [("state", str "idle")])
                end
                handle Shutdown => (write (c, R.Response {id = SOME id, outcome = R.Result Json.Null}); raise Shutdown))
            | R.Message _ => ())     (* notifications ($/cancelRequest) and stray responses: nothing to do idle *)
          (R.decode text)
      (* the wait is masked, so that no message read is lost to an
         interrupt; one that came while idle is dropped before the next
         request, not left for its evaluation *)
      fun dropPending () = ReplLoop.unmasked (fn () => ()) handle SML90.Interrupt => ()
      fun loop () =
        case next c of
          NONE => ()
        | SOME text => (dropPending (); one text; loop ())
    in
      ReplLoop.numbered := true;
      inputFromFront c;
      (* the user's interrupt, while code runs, is the front's SIGINT; idle,
         the engine waits in its read, which the interrupt ends *)
      (loop () handle Shutdown => ())
      handle Framing.Header why => (TextIO.output (TextIO.stdErr, "rune-repl --engine: " ^ why ^ "\n"))
    end

  (* the channel the options name: --engine is the descriptors 3 and 4,
     --engine-connect PORT the connection, with RUNE_ENGINE_TOKEN *)
  fun start (how : string) : unit =
    serve (if how = "fds" then fds (3, 4)
           else connect (valOf (Int.fromString how), case OS.Process.getEnv "RUNE_ENGINE_TOKEN" of SOME t => t | NONE => ""))
    handle OS.SysErr (msg, _) =>
      (TextIO.output (TextIO.stdErr, "rune-repl --engine: the channel failed: " ^ msg
                                     ^ (if how = "fds" then " (the descriptors 3 and 4 are the front's to give)" else "") ^ "\n");
       OS.Process.exit OS.Process.failure)
end

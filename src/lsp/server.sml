(* The standalone LSP transport and lifecycle. Feature handlers are added
   only with their own capability/semantic acceptance; the specification
   inventory is not used to advertise unimplemented providers. *)
structure RuneLsp =
struct
  structure R = JsonRpc
  structure P = LspProtocol
  exception Usage of string
  datatype lifecycle = New | AwaitInitialized | Running | Shutdown
  fun stderr message = (TextIO.output (TextIO.stdErr, "runelsp: " ^ message ^ "\n"); TextIO.flushOut TextIO.stdErr)
  fun writeAll text =
    let val bytes = Byte.stringToBytes text
        fun loop i = if i = Word8Vector.length bytes then ()
          else let val written = Posix.IO.writeVec (Posix.FileSys.stdout, Word8VectorSlice.slice (bytes, i, NONE))
               in if written <= 0 then raise Fail "protocol output closed" else loop (i + written) end
    in loop 0 end
  fun send message = writeAll (Framing.frame (Framing.ContentLength, P.encode message))
  fun result id value = send (R.Response {id = SOME id, outcome = R.Result value})
  fun failure id code message = send (R.Response {id = id, outcome = R.Error {code = code, message = message, data = NONE}})
  fun traceValue (Json.String "off") = SOME "off"
    | traceValue (Json.String "messages") = SOME "messages"
    | traceValue (Json.String "verbose") = SOME "verbose"
    | traceValue _ = NONE
  fun serve {maxMessageBytes, lib} =
    let
      val state = ref New
      val trace = ref "off"
      val capabilities = ref NONE : P.capabilities option ref
      val documents = ref NONE : RuneLspDocuments.t option ref
      val controller = ref NONE : RuneLspController.t option ref
      val reader = ref (Framing.bounded {framing = Framing.ContentLength,
                                        maxHeaderBytes = 8192, maxBodyBytes = maxMessageBytes})
      val pending : unit LspRequests.t = LspRequests.new {prefix = "runelsp-", maxPending = 128}
      val exitStatus = ref NONE : OS.Process.status option ref
      fun log message = if !trace = "off" orelse !state = New then () else
        send (R.Notification {method = "$/logTrace", params = SOME (Json.Object [("message", Json.String message)])})
      fun progress token value = send (R.Notification {method = "$/progress", params = SOME
        (Json.Object [("token", P.idToJson token), ("value", Json.Object value)])})
      fun clear ()=(ignore (LspRequests.clear pending);
        Option.app RuneLspController.clear (!controller);controller:=NONE;documents:=NONE)
      fun initialize (id, params) =
        if !state <> New then failure (SOME id) R.invalidRequest "server is already initialized"
        else
          let
            val raw = case params of SOME (v as Json.Object _) => v | _ => raise Usage "initialize wants an object"
            val caps = case Option.mapPartial P.capabilities (Json.member ("capabilities", raw)) of
                SOME caps => caps | NONE => raise Usage "initialize wants client capabilities"
            val requestedTrace = case Json.member ("trace", raw) of NONE => "off"
              | SOME value => (case traceValue value of SOME v => v | NONE => raise Usage "invalid trace setting")
            val token = case Json.member ("workDoneToken", raw) of NONE => NONE
              | SOME value => (case P.idFromJson value of SOME token => SOME token | NONE => raise Usage "invalid work progress token")
            val () = case Json.member ("processId", raw) of NONE => () | SOME Json.Null => ()
              | SOME value => (case P.uinteger value of SOME _ => () | NONE => raise Usage "invalid client process id")
            val () = capabilities := SOME caps
            val () = documents := SOME (RuneLspDocuments.new (P.positionEncoding caps,
              {maxDocuments=512,maxDocumentBytes=Int.min (4*1024*1024,maxMessageBytes),maxTotalBytes=64*1024*1024,
               maxDocumentLines=200000,maxTotalLines=500000}))
            val platform=if List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
                         then LspUri.Windows else LspUri.Posix
            val ()=controller:=SOME (RuneLspController.new {platform=platform,lib=lib,documents=valOf (!documents),
              caps=caps,send=send,log=log,error=stderr,initialize=raw})
            val () = trace := requestedTrace
            val () = Option.app (fn token => progress token
              [("kind", Json.String "begin"), ("title", Json.String "Initialize Rune")]) token
            val response = Json.Object [("capabilities", Json.Object
                [("positionEncoding", Json.String (P.encodingName (P.positionEncoding caps))),
                 ("textDocumentSync", Json.Object [("openClose",Json.Bool true),("change",Json.int 2),
                   ("willSave",Json.Bool true),("save",Json.Object [("includeText",Json.Bool true)])]),
                 ("workspace",Json.Object [("workspaceFolders",Json.Object [("supported",Json.Bool true),("changeNotifications",Json.Bool true)])])]),
              ("serverInfo", Json.Object [("name", Json.String "runelsp"), ("version", Json.String Config.version)])]
            val () = state := AwaitInitialized
            val () = Option.app (fn token => progress token [("kind", Json.String "end")]) token
          in result id response end
          handle Usage message => failure (SOME id) R.invalidParams message
               | RuneLspWorkspace.Invalid message => failure (SOME id) R.invalidParams message
               | RuneLspSync.Invalid message => failure (SOME id) R.invalidParams message
               | LspUri.Invalid => failure (SOME id) R.invalidParams "invalid workspace URI"
      fun request {id, method, params} =
        if !state = Shutdown then failure (SOME id) R.invalidRequest "server has shut down"
        else if method = "initialize" then initialize (id, params)
        else if !state = New orelse (!state = AwaitInitialized andalso method <> "shutdown")
        then failure (SOME id) P.serverNotInitialized "server is not initialized"
        else if method = "shutdown" then (clear ();state := Shutdown; result id Json.Null)
        else
          (case LspMethods.find method of
             SOME descriptor => if #kind descriptor = LspMethods.Notification
               then failure (SOME id) R.invalidRequest "method is a notification"
               else failure (SOME id) R.methodNotFound ("method is not implemented: " ^ method)
           | NONE => failure (SOME id) R.methodNotFound ("unknown method: " ^ method))
      fun synchronization (data as {method,...}) =
        if !state<>Running then stderr "document synchronization before initialized"
        else case !documents of NONE => stderr "document store is unavailable"
        | SOME store =>
            let fun report (verb,snapshot:RuneLspDocuments.snapshot) =
                  log (verb ^ " " ^ #uri snapshot ^ " (version " ^ IntInf.toString (#version snapshot) ^ ")")
                val event=RuneLspSync.handleNotification (store,data)
                val ()=Option.app (fn event => Option.app (fn controller => RuneLspController.event (controller,event)) (!controller)) event
            in case event of
              SOME (RuneLspSync.Opened snapshot) => report ("opened",snapshot)
            | SOME (RuneLspSync.Changed snapshot) => report ("changed",snapshot)
            | SOME (RuneLspSync.Closed snapshot) => report ("closed",snapshot)
            | SOME (RuneLspSync.WillSave snapshot) => report ("will save",snapshot)
            | SOME (RuneLspSync.Saved {snapshot,...}) => report ("saved",snapshot)
            | NONE => ()
            end handle RuneLspSync.Invalid message => stderr (method ^ ": " ^ message)
                     | RuneLspDocuments.Rejected message => stderr (method ^ ": " ^ message)
      fun notification (data as {method, params}) =
        if method = "exit" then
          (clear ();
           exitStatus := SOME (if !state = Shutdown then OS.Process.success else OS.Process.failure))
        else if !state = Shutdown then ()
        else case method of
          "initialized" => if !state = AwaitInitialized then
                             (state := Running; log "initialized";Option.app RuneLspController.initialized (!controller))
                           else stderr "unexpected initialized notification"
        | "$/setTrace" =>
            (case Option.mapPartial (fn p => Option.mapPartial traceValue (Json.member ("value", p))) params of
               SOME value => trace := value | NONE => stderr "invalid trace notification")
        | "$/cancelRequest" =>
            (case Option.mapPartial (fn p => Option.mapPartial P.idFromJson (Json.member ("id", p))) params of
               NONE => stderr "invalid cancellation notification"
             | SOME _ => ()) (* All current handlers complete synchronously. *)
        | "window/workDoneProgress/cancel" => () (* Completed/unknown tokens need no reply. *)
        | "$/progress" => ()
        | _ => if List.exists (fn name => name=method) RuneLspSync.methods then synchronization data
               else if !state=Running andalso (case !controller of SOME controller => RuneLspController.notification (controller,data) | NONE => false)
               then () else log ("ignored notification: " ^ method)
      fun dispatch text =
        case P.decode text of
          P.Invalid {error, id, reply} => if reply then send (R.Response {id = id, outcome = R.Error error})
                                         else stderr (#message error)
        | P.Message (R.Request requestData) => (log ("request: " ^ #method requestData); request requestData)
        | P.Message (R.Notification data) => notification data
        | P.Message response => if (case !controller of SOME controller => RuneLspController.response (controller,response) | NONE => false)
                                then () else ignore (LspRequests.resolve (pending, response))
      fun messages [] = ()
        | messages (text :: rest) =
            if isSome (!exitStatus) then () else (dispatch text; messages rest)
      fun loop () =
        case !exitStatus of SOME status => status
        | NONE =>
            let val bytes = Posix.IO.readVec (Posix.FileSys.stdin, 8192)
            in if Word8Vector.length bytes = 0 then
                 (clear ();
                  if Framing.pending (!reader) then (stderr "truncated protocol message"; OS.Process.failure)
                  else OS.Process.success)
               else let val (complete, next) = Framing.feed (!reader, Byte.bytesToString bytes)
                    in reader := next; messages complete; loop () end
            end
    in loop () handle Framing.Header message => (stderr ("invalid protocol header: " ^ message); OS.Process.failure)
                   | Framing.Limit what => (stderr ("protocol " ^ what ^ " exceeds its byte limit"); OS.Process.failure)
    end
  fun main args =
    let
      val lib = ref "lib"
      val maximum = ref (16 * 1024 * 1024)
      fun parse [] = () | parse ("--stdio" :: rest) = parse rest
        | parse ("--lib" :: directory :: rest) = (lib := directory; parse rest)
        | parse ("--max-message-bytes" :: value :: rest) =
            (case P.uinteger (Json.Number value) of
               SOME n => if IntInf.> (n, 0) andalso IntInf.<= (n, IntInf.fromInt String.maxSize)
                         then (maximum := IntInf.toInt n; parse rest) else raise Usage "invalid message byte limit"
             | NONE => raise Usage "invalid message byte limit")
        | parse _ = raise Usage "usage: runelsp [--stdio] [--lib DIR] [--max-message-bytes N]"
    in case args of
         ["--help"] => (print "runelsp [--stdio] [--lib DIR] [--max-message-bytes N]\n"; OS.Process.success)
       | ["--version"] => (print ("runelsp " ^ Config.version ^ "\n"); OS.Process.success)
       | _ => (parse args; serve {maxMessageBytes = !maximum, lib = !lib})
    end handle Usage message => (stderr message; OS.Process.failure)
             | e => (stderr (General.exnMessage e); OS.Process.failure)
end

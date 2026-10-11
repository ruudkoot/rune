(* rune-dap, the Debug Adapter Protocol for Standard ML (docs/dap.md;
   docs/plans/repl.md, D22 and M12): an editor's debugger -- VS Code's,
   Emacs's dape, Neovim's nvim-dap -- speaks DAP to it on its standard
   input and output, and it drives the REPL's engine, its child, through
   docs/repl-protocol.md (`rune-repl --engine`), as the Jupyter kernel does.

   The program is a file the engine uses (`launch` names it), once the
   editor has set its breakpoints (`configurationDone`); a stop is the
   engine's `debug/stopped`, at which the frames, the variables and the
   expressions an editor asks for are the engine's. What the program writes
   is `output`; a pause is SIGINT to the engine, which pauses rather than
   interrupts (debug/configure). While the program runs the engine reads
   nothing: what is for it waits until it stops or the program ends, and
   `threads` and `pause` are answered here. There is one thread. *)
structure DapAdapter =
struct
  structure R = JsonRpc

  fun err (s : string) = (TextIO.output (TextIO.stdErr, "rune-dap: " ^ s ^ "\n"); TextIO.flushOut TextIO.stdErr)

  fun field (name : string, v : Json.value) = Json.member (name, v)
  fun string (name, v) = case field (name, v) of SOME (Json.String s) => s | _ => ""
  fun int (name, v) = case Option.mapPartial Json.toInt (field (name, v)) of SOME k => k | NONE => 0
  fun str s = Json.String s
  fun num k = Json.int k

  (* ---- the engine, the child ---- *)

  (* the engine, a child of the adapter's (src/front/engine.sml) *)
  type engine = EngineClient.engine

  fun fd (k : int) = Posix.FileSys.wordToFD (SysWord.fromInt k)

  fun readSome (f : Posix.IO.file_desc) : string = Byte.bytesToString (Posix.IO.readVec (f, 65536))

  (* ---- the state of the session ---- *)

  val engine : engine option ref = ref NONE
  val fromEngine = ref (Framing.reader Framing.Lines)
  val fromClient = ref (Framing.reader Framing.ContentLength)
  (* the engine's answers awaited, by the number of the request *)
  val awaited : (int * (R.outcome -> unit)) list ref = ref []
  val serial = ref 0
  (* the program is running: a `use` awaited; stopped: at a stop of it *)
  val running = ref false
  val stopped = ref false
  (* what is for the engine, while it reads nothing *)
  val held : (unit -> unit) list ref = ref []
  val program : string option ref = ref NONE
  val ended = ref false
  val seq = ref 0

  fun nextSeq () = (seq := !seq + 1; !seq)

  fun toClient (m : Dap.message) : unit = (TextIO.output (TextIO.stdOut, Dap.encode m); TextIO.flushOut TextIO.stdOut)
  fun event (name : string, body : Json.value) : unit =
    toClient (Dap.Event {seq = nextSeq (), event = name, body = SOME body})
  fun output (category : string, text : string) : unit =
    if text = "" then () else event ("output", Json.Object [("category", str category), ("output", str text)])
  fun respond (request : Dap.message, body : Json.value) : unit =
    Option.app toClient (Dap.reply {seq = nextSeq (), request = request, body = SOME body})
  fun refuse (request : Dap.message, message : string) : unit =
    Option.app toClient (Dap.refuse {seq = nextSeq (), request = request, message = message})

  fun theEngine () = case !engine of SOME e => e | NONE => raise Fail "no engine"

  (* what the engine has written to its output and error, given before any
     message of its read after: the message can be seen first (Windows) *)
  fun drain () : unit =
    let
      val e = theEngine ()
      fun ready f = not (List.null (OS.IO.poll ([OS.IO.pollIn (Option.valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD f)))],
                                                 SOME Time.zeroTime)))
      fun go (f, category) =
        if ready f then (case readSome f of "" => () | s => (output (category, s); go (f, category))) else ()
    in go (#out e, "stdout"); go (#errs e, "stderr") end

  (* the engine reads now: it is idle, or at a stop *)
  fun responsive () = not (!running) orelse !stopped

  fun send (method : string, params : Json.value, k : R.outcome -> unit) : unit =
    let
      val () = serial := !serial + 1
      val id = !serial
      val m = R.Request {id = R.Number id, method = method, params = SOME params}
    in
      awaited := !awaited @ [(id, k)];
      #write (theEngine ()) (Framing.frame (Framing.Lines, Json.encode (R.toJson m)))
    end

  (* a request of the engine's: now where it reads, else when it does *)
  fun call (method : string, params : Json.value, k : R.outcome -> unit) : unit =
    if responsive () then send (method, params, k) else held := !held @ [fn () => send (method, params, k)]

  fun flush () =
    if responsive () then
      case !held of
        [] => ()
      | f :: rest => (held := rest; f (); flush ())
    else ()

  (* a result, or the request refused with the engine's message *)
  fun answered (request : Dap.message, f : Json.value -> Json.value) (outcome : R.outcome) : unit =
    case outcome of
      R.Result v => (respond (request, f v) handle Fail m => refuse (request, m))
    | R.Error {message, ...} => refuse (request, message)

  fun list (name, v) = DapEngine.list (name, v)

  (* ---- the program's end ---- *)

  (* its errors and an exception nothing handled given as output; its exit
     1 for either, 0 else (a warning is not one) *)
  fun ranOut (outcome : R.outcome) : unit =
    (running := false;
     stopped := false;
     case outcome of
       R.Result v =>
         (List.app (fn d => output ("stderr", string ("rendered", d) ^ "\n")) (list ("diagnostics", v));
          case field ("exception", v) of
            SOME (e as Json.Object _) => output ("stderr", "uncaught exception " ^ string ("message", e) ^ "\n")
          | _ => ();
          event ("exited", Json.Object [("exitCode", num (if isSome (DapEngine.failure v) then 1 else 0))]))
     | R.Error {message, ...} => (output ("stderr", message ^ "\n"); event ("exited", Json.Object [("exitCode", num 1)]));
     event ("terminated", Json.Object []);
     flush ())

  fun run () : unit =
    case !program of
      NONE => ()
    | SOME path =>
        (call ("debug/configure", Json.Object [("pause", Json.Bool true)], fn _ => ());
         call ("use", Json.Object [("path", str path)], ranOut);
         running := true)

  (* ---- the editor's requests ---- *)

  fun shutdown () : unit =
    (case !engine of
       SOME e =>
         (if responsive () then (send ("shutdown", Json.Object [], fn _ => ()) handle _ => ())
          else Posix.Process.kill (Posix.Process.K_PROC (#pid e), Posix.Signal.kill) handle OS.SysErr _ => ())
     | NONE => ();
     ended := true)

  fun request (m as Dap.Request {command, arguments, ...}) : unit =
    let
      val args = getOpt (arguments, Json.Object [])
    in
      case command of
        "initialize" => (respond (m, DapEngine.capabilities ()); toClient (Dap.initialized (nextSeq ())))
      | "launch" =>
          (case field ("program", args) of
             SOME (Json.String p) => (program := SOME p; respond (m, Json.Object []))
           | _ => refuse (m, "launch wants the program: the file of SML to use"))
      | "attach" => respond (m, Json.Object [])
      | "setBreakpoints" =>
          call ("debug/setBreakpoints", DapEngine.breakpointsParams args, answered (m, DapEngine.breakpointsBody))
      | "setExceptionBreakpoints" =>
          call ("debug/setRaise", DapEngine.raiseParams args, answered (m, fn _ => Json.Object []))
      | "configurationDone" => (respond (m, Json.Object []); run ())
      | "threads" => respond (m, DapEngine.threadsBody ())
      | "stackTrace" => call ("debug/frames", Json.Object [], answered (m, DapEngine.stackTraceBody))
      | "scopes" => respond (m, DapEngine.scopesBody args)
      | "variables" =>
          let val (method, params) = DapEngine.variablesRequest args
          in call (method, params, answered (m, DapEngine.variablesBody)) end
      | "pause" =>
          (if !running andalso not (!stopped) then
             #interrupt (theEngine ()) ()
           else ();
           respond (m, Json.Object []))
      | "evaluate" =>
          let val (method, params) = DapEngine.evaluateRequest (args, !stopped)
          in call (method, params, answered (m, DapEngine.evaluateBody)) end
      | "disconnect" => (respond (m, Json.Object []); shutdown ())
      | "terminate" => (respond (m, Json.Object []); shutdown (); event ("terminated", Json.Object []))
      | _ =>
          case DapEngine.continueMode command of
            SOME mode => go (m, mode)
          | NONE => refuse (m, "rune-dap does not do " ^ command)
    end
    | request _ = ()

  (* on, as the editor says: the stop ends, and the program runs *)
  and go (m : Dap.message, mode : string) : unit =
    if not (!stopped) then refuse (m, "the program is not stopped")
    else
      (send ("debug/continue", Json.Object [("mode", str mode)], fn _ => ());
       stopped := false;
       respond (m, if mode = "continue" then Json.Object [("allThreadsContinued", Json.Bool true)] else Json.Object []))

  (* ---- what the engine says ---- *)

  fun fromTheEngine (text : string) : unit =
    case R.decode text of
      [R.Message (R.Response {id = SOME (R.Number id), outcome})] =>
        (case List.find (fn (i, _) => i = id) (!awaited) of
           SOME (_, k) => (awaited := List.filter (fn (i, _) => i <> id) (!awaited); k outcome)
         | NONE => ())
    | [R.Message (R.Notification {method = "debug/stopped", params = SOME p})] =>
        (stopped := true; event ("stopped", DapEngine.stoppedBody p); flush ())
    | [R.Message (R.Request {id, method = "input", ...})] =>
        (* the program reads its input, which an editor's debugger has
           none of to give: the end of it *)
        #write (theEngine ())
          (Framing.frame (Framing.Lines, Json.encode (R.toJson (R.Response {id = SOME id, outcome = R.Result Json.Null}))))
    | _ => ()

  (* ---- the loop ---- *)

  fun pollIn (f : Posix.IO.file_desc) = OS.IO.pollIn (Option.valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD f)))
  fun isOf (f : Posix.IO.file_desc) (p : OS.IO.poll_info) = OS.IO.pollToIODesc (OS.IO.infoToPollDesc p) = Posix.FileSys.fdToIOD f

  fun loop () : unit =
    if !ended then ()
    else
      let
        val e = theEngine ()
        val stdin = fd 0
        val ready = OS.IO.poll (OS.IO.pollIn (#poll e) :: List.map pollIn [stdin, #out e, #errs e], SOME (Time.fromSeconds 1))
        fun has f = List.exists (isOf f) ready
        val fromIt = List.exists (fn p => OS.IO.pollToIODesc (OS.IO.infoToPollDesc p) = OS.IO.pollToIODesc (#poll e)) ready
      in
        if fromIt orelse has (#out e) orelse has (#errs e) then drain () else ();
        if fromIt then
          (case #read e () of
             "" => (if !ended then () else (output ("stderr", "the engine has ended\n"); event ("terminated", Json.Object []));
                    ended := true)
           | bytes =>
               let val (ms, r) = Framing.feed (!fromEngine, bytes)
               in fromEngine := r; List.app fromTheEngine ms end)
        else ();
        if has stdin then
          (case readSome stdin of
             "" => shutdown ()
           | bytes =>
               let val (ms, r) = Framing.feed (!fromClient, bytes)
               in fromClient := r; List.app (fn t => case Dap.decode t of SOME m => request m | NONE => ()) ms end)
        else ();
        loop ()
      end

  val absolute = EngineClient.absolute

  fun main (args : string list) : unit =
    let
      fun opt (name, args) =
        let fun f (a :: b :: rest) = if a = name then SOME b else f (b :: rest) | f _ = NONE in f args end
      val vm = absolute (getOpt (opt ("--vm", args), "runevm"))
      val image = absolute (getOpt (opt ("--image", args), "rune-repl.img"))
      val e = EngineClient.start (vm, image, err)
    in
      engine := SOME e;
      send ("initialize", Json.Object [("protocol", num 1)], fn _ => ());
      loop ();
      EngineClient.finish e
    end
    handle Fail m => (err m; OS.Process.exit OS.Process.failure)
         | Framing.Header why => (err why; OS.Process.exit OS.Process.failure)
         | EngineClient.Refused why => (err why; OS.Process.exit OS.Process.failure)
         | OS.SysErr (m, _) => (err ("the system: " ^ m); OS.Process.exit OS.Process.failure)
end

val () = DapAdapter.main (CommandLine.arguments ())

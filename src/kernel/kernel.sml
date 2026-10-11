(* libraries: jupyter jsonrpc *)
(* rune-kernel: a Jupyter kernel for Standard ML (docs/plans/repl.md, D21 and
   M11; docs/kernel.md). A bridge in SML: it owns Jupyter's five sockets
   (lib/jupyter, over lib/zmtp and lib/digest) and drives the REPL's engine
   as its child (`rune-repl --engine`, docs/repl-protocol.md), so that a
   crash of the user's code takes the engine and not the kernel, which
   starts another.

     rune-kernel [--vm VM --image IMAGE] CONNECTION-FILE
     rune-kernel --install [--user | --prefix DIR] [--vm VM --image IMAGE]

   An execute_request is the engine's eval: what the program writes on its
   standard output and error goes out as `stream` messages while it runs,
   what the REPL says of the declarations is the `execute_result`, as text
   and as HTML in the palette's styles, and a compile error or an uncaught
   exception is an `error`. is_complete, complete and inspect are the
   engine's. A read of the standard input is asked of the notebook on the
   stdin channel. The kernelspec says interrupt_mode signal: Jupyter's
   SIGINT reaches the kernel, which gives it to the engine. *)
structure Kernel =
struct
  structure R = JsonRpc

  fun err (s : string) = (TextIO.output (TextIO.stdErr, "rune-kernel: " ^ s ^ "\n"); TextIO.flushOut TextIO.stdErr)

  (* the fields of a JSON object *)
  fun field (name : string, v : Json.value) = Json.member (name, v)
  fun string (name, v) = case field (name, v) of SOME (Json.String s) => s | _ => ""
  fun bool (name, v, default) = case field (name, v) of SOME (Json.Bool b) => b | _ => default
  fun int (name, v) = case Option.mapPartial Json.toInt (field (name, v)) of SOME k => k | NONE => 0
  fun strings (name, v) =
    case field (name, v) of SOME (Json.Array xs) => List.mapPartial (fn Json.String s => SOME s | _ => NONE) xs | _ => []

  (* ---- the engine, a child ---- *)

  type engine = {pid : Posix.ProcEnv.pid, to : Posix.IO.file_desc, from : Posix.IO.file_desc,
                 out : Posix.IO.file_desc, errs : Posix.IO.file_desc, reader : Framing.reader ref,
                 waiting : string list ref, serial : int ref}

  fun fd (k : int) = Posix.FileSys.wordToFD (Word.fromInt k)

  (* the engine started: its channel the descriptors 3 and 4, its output and
     error pipes of this kernel's; every other descriptor the child has
     closed, so that it holds none of the kernel's sockets *)
  fun start (vm : string, image : string) : engine =
    let
      val {infd = toR, outfd = toW} = Posix.IO.pipe ()
      val {infd = fromR, outfd = fromW} = Posix.IO.pipe ()
      val {infd = outR, outfd = outW} = Posix.IO.pipe ()
      val {infd = errR, outfd = errW} = Posix.IO.pipe ()
    in
      case Posix.Process.fork () of
        NONE =>
          ((* the child: 3 and 4 the channel, 1 and 2 the pipes, 0 nothing *)
           Posix.IO.dup2 {old = toR, new = fd 3};
           Posix.IO.dup2 {old = fromW, new = fd 4};
           Posix.IO.dup2 {old = outW, new = fd 1};
           Posix.IO.dup2 {old = errW, new = fd 2};
           let fun shut k = if k > 1023 then () else ((Posix.IO.close (fd k) handle OS.SysErr _ => ()); shut (k + 1))
           in shut 5 end;
           Posix.Process.exec (vm, [vm, "--heap-size", "67108864", "--restore", image, "--", "--no-init", "--engine"])
           handle OS.SysErr (m, _) => (err ("cannot start the engine " ^ vm ^ ": " ^ m); Posix.Process.exit 0w127))
      | SOME pid =>
          (List.app Posix.IO.close [toR, fromW, outW, errW];
           {pid = pid, to = toW, from = fromR, out = outR, errs = errR, reader = ref (Framing.reader Framing.Lines),
            waiting = ref [], serial = ref 0})
    end

  fun send (e : engine, m : R.message) : unit =
    let
      val bytes = Byte.stringToBytes (Framing.frame (Framing.Lines, Json.encode (R.toJson m)))
      fun go i = if i >= Word8Vector.length bytes then ()
                 else go (i + Posix.IO.writeVec (#to e, Word8VectorSlice.slice (bytes, i, NONE)))
    in go 0 end

  fun readSome (f : Posix.IO.file_desc) : string = Byte.bytesToString (Posix.IO.readVec (f, 65536))

  exception Died

  (* ---- the debugger's state (docs/kernel.md, The debugger) ---- *)

  (* a debugger is attached: cells are compiled under the files that name
     them (dumpCell); the program is at a stop; the interrupt the notebook
     asked for while the engine pauses at one (its abort, not a stop); the
     numbers of DAP's messages the kernel sends *)
  val debugging = ref false
  val stopped = ref false
  val interrupting = ref false
  val dapSeq = ref 0
  fun dapEvent (name : string, body : Json.value) : Json.value =
    (dapSeq := !dapSeq + 1;
     Json.Object [("seq", Json.int (!dapSeq)), ("type", Json.String "event"), ("event", Json.String name), ("body", body)])

  (* answers to requests other than the one awaited: one awaited within
     another's wait, the debugger's (a request of the control channel's
     while a cell runs) *)
  val stash : (R.id * R.outcome) list ref = ref []

  (* ---- the wait for an answer, while the program runs ---- *)

  (* the engine's answer to the request id, the program's output published
     as it comes, an input request of the engine asked of the notebook, the
     user's interrupt given to the engine; Died where the engine ended *)
  fun await (e : engine, id : R.id, req : Jupyter.request) : R.outcome =
    let
      fun publishStream (name, text) =
        if text = "" then ()
        else (#publish req ("stream", Json.Object [("name", Json.String name), ("text", Json.String text)]); #idle req ())
      fun pollIn f = OS.IO.pollIn (Option.valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD f)))
      fun ready (f, wait) = not (List.null (OS.IO.poll ([pollIn f], SOME wait)))
      fun drain (f, name) =
        if ready (f, Time.zeroTime) then (case readSome f of "" => () | s => (publishStream (name, s); drain (f, name)))
        else ()
      fun messages () =
        case !(#waiting e) of
          m :: rest => (#waiting e := rest; SOME m)
        | [] => NONE
      fun step () =
        case messages () of
          SOME text =>
            (case R.decode text of
               [R.Message (R.Response {id = SOME i, outcome})] =>
                 if i = id then SOME outcome else (stash := (i, outcome) :: !stash; NONE)
             | [R.Message (R.Notification {method = "debug/stopped", params = SOME p})] =>
                 (drain (#out e, "stdout"); drain (#errs e, "stderr");
                  if !interrupting andalso DapEngine.string ("reason", p) = "pause" then
                    (* the notebook's interrupt, which pauses while a
                       debugger is attached: raised where it paused *)
                    (interrupting := false;
                     send (e, R.Request {id = R.String "abort", method = "debug/continue",
                                         params = SOME (Json.Object [("mode", Json.String "abort")])}))
                  else (stopped := true; #publish req ("debug_event", dapEvent ("stopped", DapEngine.stoppedBody p)));
                  #idle req ();
                  NONE)
             | [R.Message (R.Notification {method = "display", params = SOME p})] =>
                 (drain (#out e, "stdout"); drain (#errs e, "stderr");
                  #publish req ((case field ("update", p) of SOME (Json.Bool true) => "update_display_data"
                                                          | _ => "display_data"),
                                Json.Object [("data", getOpt (field ("data", p), Json.Object [])),
                                             ("metadata", Json.Object []),
                                             ("transient", case field ("id", p) of
                                                             SOME i => Json.Object [("display_id", i)]
                                                           | NONE => Json.Object [])]);
                  #idle req ();
                  NONE)
             | [R.Message (R.Notification {method = "clear", params = SOME p})] =>
                 (#publish req ("clear_output", Json.Object [("wait", getOpt (field ("wait", p), Json.Bool false))]);
                  #idle req ();
                  NONE)
             | [R.Message (R.Request {id = i, method = "input", ...})] =>
                 (drain (#out e, "stdout"); drain (#errs e, "stderr");
                  send (e, R.Response {id = SOME i,
                                       outcome = R.Result (case #input req {prompt = "", password = false} of
                                                             SOME l => Json.String (l ^ "\n")
                                                           | NONE => Json.Null)});
                  NONE)
             | _ => NONE)
        | NONE => NONE
      fun stashed () =
        case List.find (fn (i, _) => i = id) (!stash) of
          SOME (_, outcome) => (stash := List.filter (fn (i, _) => i <> id) (!stash); SOME outcome)
        | NONE => NONE
      fun loop () =
        case (case stashed () of SOME found => SOME found | NONE => step ()) of
          SOME outcome => (drain (#out e, "stdout"); drain (#errs e, "stderr"); outcome)
        | NONE =>
            if not (List.null (!(#waiting e))) then loop ()
            else
              let
                (* the interrupt: Jupyter's SIGINT, while the kernel waits *)
                val () = (ignore (Runtime.maskInterrupt false);
                          ignore (OS.IO.poll (List.map pollIn [#from e, #out e, #errs e], SOME (Time.fromMilliseconds 50)));
                          ignore (Runtime.maskInterrupt true))
                         handle SML90.Interrupt =>
                           (ignore (Runtime.maskInterrupt true);
                            interrupting := !debugging;
                            Posix.Process.kill (Posix.Process.K_PROC (#pid e), Posix.Signal.int))
              in
                #idle req ();
                drain (#out e, "stdout");
                drain (#errs e, "stderr");
                if ready (#from e, Time.zeroTime) then
                  (case readSome (#from e) of
                     "" => raise Died
                   | bytes =>
                       let val (ms, r) = Framing.feed (!(#reader e), bytes)
                       in #reader e := r; #waiting e := !(#waiting e) @ ms end)
                else ();
                loop ()
              end
    in loop () end

  (* a request of the engine's, and its answer *)
  fun call (e : engine, req : Jupyter.request, method : string, params : Json.value) : R.outcome =
    let
      val () = #serial e := !(#serial e) + 1
      val id = R.Number (!(#serial e))
    in
      send (e, R.Request {id = id, method = method, params = SOME params});
      await (e, id, req)
    end

  (* ---- the notebook's requests ---- *)


  (* a byte offset of a text, as the code points Jupyter counts *)
  fun codePoints (text : string, bytes : int) : int =
    CharVector.foldli (fn (i, c, n) => if i < bytes andalso (Char.ord c < 128 orelse Char.ord c >= 192) then n + 1 else n)
                      0 text
  fun byteOf (text : string, points : int) : int =
    let
      fun go (i, n) =
        if i >= String.size text orelse n >= points then i
        else
          let val c = Char.ord (String.sub (text, i))
              val k = if c < 128 then 1 else if c >= 240 then 4 else if c >= 224 then 3 else if c >= 192 then 2 else 1
          in go (i + k, n + 1) end
    in go (0, 0) end

  val count = ref 0

  (* the reply of an execution that failed, and its error published *)
  fun failed (req : Jupyter.request, ename : string, evalue : string, traceback : string list) : Json.value =
    let val tb = Json.Array (List.map Json.String traceback)
    in
      #publish req ("error", Json.Object [("ename", Json.String ename), ("evalue", Json.String evalue), ("traceback", tb)]);
      Json.Object [("status", Json.String "error"), ("execution_count", Json.int (!count)), ("ename", Json.String ename),
                   ("evalue", Json.String evalue), ("traceback", tb)]
    end

  fun escape s = String.translate (fn #"<" => "&lt;" | #">" => "&gt;" | #"&" => "&amp;" | c => String.str c) s

  (* ---- the cells' files, which JupyterLab's debugger names them by ----
     A cell's code is the file tmpFilePrefix, its hash (Murmur2, the seed
     ipykernel's), tmpFileSuffix (debugInfo), which the notebook works out
     for itself to set a cell's breakpoints, and which the cell is compiled
     under, so that its frames are the cell's. *)
  val seed : Word32.word = 0w3339675911
  val cells : string option ref = ref NONE
  fun cellDir () : string =
    case !cells of
      SOME d => d
    | NONE =>
        let
          val tmp = case OS.Process.getEnv "TMPDIR" of SOME t => t | NONE => "/tmp"
          val d = OS.Path.concat (tmp, "rune-kernel-" ^ SysWord.fmt StringCvt.DEC (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())))
        in
          (OS.FileSys.mkDir d handle OS.SysErr _ => ());
          cells := SOME (d ^ "/");
          d ^ "/"
        end
  fun cellFile (code : string) : string =
    cellDir () ^ Word32.fmt StringCvt.DEC (Murmur2.hash {seed = seed, data = code}) ^ ".sml"
  fun dumpCell (code : string) : string =
    let
      val path = cellFile code
      val out = TextIO.openOut path
    in TextIO.output (out, code); TextIO.closeOut out; path end

  fun execute (e : engine, req : Jupyter.request) : Json.value =
    let
      val code = string ("code", #content req)
      val silent = bool ("silent", #content req, false)
      val () = if silent then () else count := !count + 1
      val () = #publish req ("execute_input", Json.Object [("code", Json.String code), ("execution_count", Json.int (!count))])
      val () = (interrupting := false; stopped := false)
      val path = if !debugging then [("path", Json.String (dumpCell code))] else []
    in
      case call (e, req, "eval", Json.Object ([("text", Json.String code)] @ path)) of
        R.Error {message, ...} => failed (req, "EngineError", message, [message])
      | R.Result r =>
          let
            val bindings = case field ("bindings", r) of SOME (Json.Array bs) => bs | _ => []
            val declared = strings ("declared", r)
            val lines = declared @ List.map (fn b => string ("line", b)) bindings
            val htmls = List.map escape declared @ List.map (fn b => string ("html", b)) bindings
            val () =
              if silent orelse List.null lines then ()
              else #publish req ("execute_result",
                                 Json.Object [("execution_count", Json.int (!count)),
                                              ("data", Json.Object
                                                         [("text/plain", Json.String (String.concatWith "\n" lines)),
                                                          ("text/html", Json.String ("<style>" ^ string ("css", r) ^ "</style>"
                                                                                     ^ "<pre class=\"rune\">"
                                                                                     ^ String.concatWith "\n" htmls ^ "</pre>"))]),
                                              ("metadata", Json.Object [])])
            val () = case strings ("messages", r) of
                       [] => ()
                     | ms => #publish req ("stream", Json.Object [("name", Json.String "stdout"),
                                                                  ("text", Json.String (String.concat ms))])
            val diagnostics = case field ("diagnostics", r) of SOME (Json.Array ds) => ds | _ => []
          in
            case (diagnostics, field ("exception", r)) of
              (d :: _, _) => failed (req, "Error", string ("message", d), List.map (fn d => string ("rendered", d)) diagnostics)
            | ([], SOME (x as Json.Object _)) =>
                let
                  val frames = case field ("trace", x) of SOME (Json.Array fs) => fs | _ => []
                  fun frame f = "  in " ^ string ("function", f) ^ " at " ^ string ("file", f) ^ ":"
                                ^ Int.toString (int ("line", f)) ^ ":" ^ Int.toString (int ("column", f))
                in
                  failed (req, string ("name", x), string ("message", x),
                          ("uncaught exception " ^ string ("message", x)) :: List.map frame frames)
                end
            | _ => Json.Object [("status", Json.String "ok"), ("execution_count", Json.int (!count)),
                                ("payload", Json.Array []), ("user_expressions", Json.Object [])]
          end
    end

  fun isComplete (e : engine, req : Jupyter.request) : Json.value =
    case call (e, req, "isComplete", Json.Object [("text", Json.String (string ("code", #content req)))]) of
      R.Result r =>
        (case string ("status", r) of
           "incomplete" => Json.Object [("status", Json.String "incomplete"),
                                        ("indent", Json.String (CharVector.tabulate (int ("indent", r), fn _ => #" ")))]
         | s => Json.Object [("status", Json.String s)])
    | R.Error _ => Json.Object [("status", Json.String "unknown")]

  fun complete (e : engine, req : Jupyter.request) : Json.value =
    let
      val code = string ("code", #content req)
      val pos = int ("cursor_pos", #content req)
      val offset = byteOf (code, pos)
    in
      case call (e, req, "complete", Json.Object [("text", Json.String code), ("offset", Json.int offset)]) of
        R.Result r =>
          Json.Object [("status", Json.String "ok"),
                       ("matches", Json.Array (List.map Json.String (strings ("candidates", r)))),
                       ("cursor_start", Json.int (codePoints (code, int ("start", r)))), ("cursor_end", Json.int pos),
                       ("metadata", Json.Object [])]
      | R.Error {message, ...} => Json.Object [("status", Json.String "error"), ("ename", Json.String "EngineError"),
                                               ("evalue", Json.String message), ("traceback", Json.Array [])]
    end

  fun isNameChar c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'" orelse c = #"."

  fun inspect (e : engine, req : Jupyter.request) : Json.value =
    let
      val code = string ("code", #content req)
      val at = byteOf (code, int ("cursor_pos", #content req))
      fun back i = if i > 0 andalso isNameChar (String.sub (code, i - 1)) then back (i - 1) else i
      fun ahead i = if i < String.size code andalso isNameChar (String.sub (code, i)) then ahead (i + 1) else i
      val name = String.substring (code, back at, ahead at - back at)
      val found =
        if name = "" then NONE
        else case call (e, req, "inspect", Json.Object [("name", Json.String name)]) of
               R.Result r =>
                 (case (string ("info", r), string ("doc", r)) of
                    ("", "") => NONE
                  | (i, d) => SOME (i ^ (if d = "" then "" else "\n" ^ d)))
             | R.Error _ => NONE
    in
      Json.Object [("status", Json.String "ok"), ("found", Json.Bool (isSome found)),
                   ("data", case found of SOME t => Json.Object [("text/plain", Json.String t)] | NONE => Json.Object []),
                   ("metadata", Json.Object [])]
    end

  fun readFile (path : string) : string =
    let val ins = TextIO.openIn path in TextIO.inputAll ins before TextIO.closeIn ins end

  (* ---- the debugger: JupyterLab's, by DAP over the control channel ----
     A debug_request is a request of DAP (src/dap/translate.sml), and its
     debug_reply DAP's response; a stop is a debug_event. JupyterLab adds
     debugInfo, dumpCell, inspectVariables and source (ipykernel's). *)
  val breakpoints : (string * Json.value) list ref = ref []

  fun debug (e : engine, req : Jupyter.request) : Json.value =
    let
      val m = #content req
      val command = string ("command", m)
      val args = getOpt (field ("arguments", m), Json.Object [])
      fun response (success, rest) =
        (dapSeq := !dapSeq + 1;
         Json.Object ([("seq", Json.int (!dapSeq)), ("type", Json.String "response"), ("request_seq", Json.int (int ("seq", m))),
                       ("success", Json.Bool success), ("command", Json.String command)] @ rest))
      fun ok body = response (true, [("body", body)])
      fun fail message = response (false, [("message", Json.String message)])
      fun engine (method, params, f) =
        case call (e, req, method, params) of
          R.Result v => (ok (f v) handle Fail why => fail why)
        | R.Error {message, ...} => fail message
      fun quietly (method, params) = ignore (call (e, req, method, params))
    in
      case command of
        "initialize" => ok (DapEngine.capabilities ())
      | "attach" => (debugging := true; quietly ("debug/configure", Json.Object [("pause", Json.Bool true)]); ok (Json.Object []))
      | "debugInfo" =>
          ok (Json.Object [("isStarted", Json.Bool (!debugging)), ("hashMethod", Json.String "Murmur2"),
                           ("hashSeed", Json.int (Word32.toInt seed)), ("tmpFilePrefix", Json.String (cellDir ())),
                           ("tmpFileSuffix", Json.String ".sml"),
                           ("breakpoints", Json.Array (List.map (fn (p, bs) => Json.Object [("source", Json.String p),
                                                                                             ("breakpoints", bs)])
                                                                (!breakpoints))),
                           ("stoppedThreads", Json.Array (if !stopped then [Json.int 1] else [])),
                           ("richRendering", Json.Bool false), ("exceptionPaths", Json.Array [])])
      | "dumpCell" => ok (Json.Object [("sourcePath", Json.String (dumpCell (DapEngine.string ("code", args))))])
      | "setBreakpoints" =>
          let val path = case field ("source", args) of SOME s => DapEngine.string ("path", s) | NONE => ""
          in
            breakpoints := List.filter (fn (p, _) => p <> path) (!breakpoints)
                           @ (case field ("breakpoints", args) of
                                SOME (bs as Json.Array (_ :: _)) => [(path, bs)]
                              | _ => []);
            engine ("debug/setBreakpoints", DapEngine.breakpointsParams args, DapEngine.breakpointsBody)
          end
      | "setExceptionBreakpoints" => engine ("debug/setRaise", DapEngine.raiseParams args, fn _ => Json.Object [])
      | "configurationDone" => ok (Json.Object [])
      | "threads" => ok (DapEngine.threadsBody ())
      | "stackTrace" => engine ("debug/frames", Json.Object [], DapEngine.stackTraceBody)
      | "scopes" => ok (DapEngine.scopesBody args)
      | "variables" => engine (#1 (DapEngine.variablesRequest args), #2 (DapEngine.variablesRequest args), DapEngine.variablesBody)
      | "evaluate" =>
          let val (method, params) = DapEngine.evaluateRequest (args, !stopped)
          in engine (method, params, DapEngine.evaluateBody) end
      | "pause" => (Posix.Process.kill (Posix.Process.K_PROC (#pid e), Posix.Signal.int); ok (Json.Object []))
      | "source" =>
          (ok (Json.Object [("content", Json.String (readFile (case field ("source", args) of
                                                                  SOME s => DapEngine.string ("path", s)
                                                                | NONE => "")))])
           handle IO.Io _ => fail "no such source")
      | "inspectVariables" => ok (Json.Object [("variables", Json.Array [])])
      | "modules" => ok (Json.Object [("modules", Json.Array []), ("totalModules", Json.int 0)])
      | "disconnect" =>
          (List.app (fn (p, _) => quietly ("debug/setBreakpoints", Json.Object [("path", Json.String p), ("lines", Json.Array [])]))
                    (!breakpoints);
           breakpoints := [];
           quietly ("debug/setRaise", Json.Object [("mode", Json.String "none")]);
           quietly ("debug/configure", Json.Object [("pause", Json.Bool false)]);
           debugging := false;
           ok (Json.Object []))
      | _ =>
          case DapEngine.continueMode command of
            SOME mode =>
              if not (!stopped) then fail "the program is not stopped"
              else (stopped := false; engine ("debug/continue", Json.Object [("mode", Json.String mode)], fn _ => Json.Object []))
          | NONE => fail ("rune-kernel's debugger does not do " ^ command)
    end
    handle e' as Died => raise e'
         | ex => Json.Object [("type", Json.String "response"), ("success", Json.Bool false),
                              ("command", Json.String (string ("command", #content req))),
                              ("message", Json.String (General.exnMessage ex))]

  (* ---- the kernel ---- *)

  fun info (implementation : string) : (string * Json.value) list =
    [("implementation", Json.String "rune-kernel"), ("implementation_version", Json.String implementation),
     ("language_info", Json.Object [("name", Json.String "sml"), ("version", Json.String "97"),
                                    ("mimetype", Json.String "text/x-sml"), ("file_extension", Json.String ".sml"),
                                    ("pygments_lexer", Json.String "sml"), ("codemirror_mode", Json.String "mllike")]),
     ("banner", Json.String ("Rune: Standard ML '97 (" ^ implementation ^ ")")),
     ("help_links", Json.Array []),
     ("debugger", Json.Bool true)]

  (* initialize, as a front does, for its answer's implementation *)
  fun initialize (e : engine) : string =
    let
      val noRequest = {msgType = "", content = Json.Object [], publish = fn _ => (),
                       input = fn _ => NONE, idle = fn () => ()} : Jupyter.request
    in
      case call (e, noRequest, "initialize", Json.Object [("protocol", Json.int 1), ("width", Json.int 100)]) of
        R.Result r => string ("implementation", r)
      | R.Error {message, ...} => raise Fail ("the engine refused to start: " ^ message)
    end

  fun run (vm : string, image : string, connectionFile : string) : unit =
    let
      val c = Jupyter.readConnection (readFile connectionFile)
      val engine = ref (start (vm, image))
      val implementation = initialize (!engine)
      val k = Jupyter.bind c
      (* the engine again, where it ended under a request *)
      fun again () = (engine := start (vm, image); ignore (initialize (!engine)))
      fun respond (req : Jupyter.request) : Json.value option =
        (case #msgType req of
           "execute_request" => SOME (execute (!engine, req))
         | "is_complete_request" => SOME (isComplete (!engine, req))
         | "complete_request" => SOME (complete (!engine, req))
         | "inspect_request" => SOME (inspect (!engine, req))
         | "comm_info_request" => SOME (Json.Object [("status", Json.String "ok"), ("comms", Json.Object [])])
         | "history_request" => SOME (Json.Object [("status", Json.String "ok"), ("history", Json.Array [])])
         | "debug_request" => SOME (debug (!engine, req))
         | _ => NONE)
        handle Died =>
          (again ();
           SOME (failed (req, "EngineDied", "the engine ended; a new one has started, without the session's declarations",
                         ["the engine ended; a new one has started, without the session's declarations"])))
    in
      Jupyter.serve (k, {info = info implementation, respond = respond});
      Jupyter.close k;
      (send (!engine, R.Request {id = R.Number 0, method = "shutdown", params = SOME (Json.Object [])}) handle _ => ());
      ignore (Posix.Process.waitpid (Posix.Process.W_CHILD (#pid (!engine)), []))
    end

  (* ---- --install: the kernelspec ---- *)

  fun env name = OS.Process.getEnv name

  fun jupyterData (prefix : string option, user : bool) : string =
    case prefix of
      SOME p => OS.Path.concat (p, "share/jupyter")
    | NONE =>
        if user then
          (case (env "JUPYTER_DATA_DIR", env "APPDATA", env "XDG_DATA_HOME", env "HOME") of
             (SOME d, _, _, _) => d
           | (NONE, SOME a, _, _) => OS.Path.concat (a, "jupyter")
           | (NONE, NONE, SOME x, _) => OS.Path.concat (x, "jupyter")
           | (NONE, NONE, NONE, SOME h) => OS.Path.concat (h, ".local/share/jupyter")
           | _ => raise Fail "no place for the kernelspec: set HOME or JUPYTER_DATA_DIR")
        else "/usr/local/share/jupyter"

  fun mkdirs (path : string) : unit =
    if path = "" orelse (OS.FileSys.isDir path handle OS.SysErr _ => false) then ()
    else (mkdirs (OS.Path.dir path); OS.FileSys.mkDir path handle OS.SysErr _ => ())

  fun install (vm : string, image : string, program : string, prefix : string option, user : bool) : unit =
    let
      val dir = OS.Path.concat (jupyterData (prefix, user), "kernels/rune")
      val () = mkdirs dir
      val spec =
        Json.Object [("argv", Json.Array (List.map Json.String [vm, program, "--vm", vm, "--image", image, "{connection_file}"])),
                     ("display_name", Json.String "Rune (Standard ML)"), ("language", Json.String "sml"),
                     ("interrupt_mode", Json.String "signal")]
      val out = TextIO.openOut (OS.Path.concat (dir, "kernel.json"))
    in
      TextIO.output (out, Json.encodeIndented 1 spec ^ "\n");
      TextIO.closeOut out;
      print ("installed the kernelspec in " ^ dir ^ "\n")
    end

  fun absolute (p : string) = if OS.Path.isAbsolute p then p else OS.Path.concat (OS.FileSys.getDir (), p)

  fun main (args : string list) : unit =
    let
      fun opt (name, args) =
        let fun f (a :: b :: rest) = if a = name then SOME b else f (b :: rest) | f _ = NONE in f args end
      fun without (names, args) =
        let fun f (a :: b :: rest) = if List.exists (fn n => n = a) names then f rest else a :: f (b :: rest)
              | f l = l
        in f args end
      val vm = absolute (getOpt (opt ("--vm", args), "runevm"))
      val image = absolute (getOpt (opt ("--image", args), "rune-repl.img"))
      val program = absolute (getOpt (opt ("--program", args), "rune-kernel.rbc"))
      val rest = without (["--vm", "--image", "--program", "--prefix"], args)
    in
      ignore (Runtime.catchInterrupt ());
      ignore (Runtime.maskInterrupt true);
      case rest of
        "--install" :: more => install (vm, image, program, opt ("--prefix", args), List.exists (fn a => a = "--user") more)
      | [connection] => run (vm, image, connection)
      | _ => (err "usage: rune-kernel [--vm VM --image IMAGE] CONNECTION-FILE | --install [--user | --prefix DIR]";
              OS.Process.exit OS.Process.failure)
    end
    handle Fail m => (err m; OS.Process.exit OS.Process.failure)
         | Jupyter.Connection m => (err ("the connection file: " ^ m); OS.Process.exit OS.Process.failure)
end

val () = Kernel.main (CommandLine.arguments ())

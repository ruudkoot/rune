(* What the Debug Adapter Protocol and the REPL's engine say of the same
   things, each in its own terms (docs/dap.md; docs/repl-protocol.md, The
   debugger): the bodies of DAP's responses and events made from the
   engine's answers, and the engine's requests from DAP's arguments. The
   adapter (src/dap/adapter.sml) and the Jupyter kernel's debugger
   (src/kernel/kernel.sml) share them; each drives the engine its own way. *)
structure DapEngine =
struct
  fun field (name : string, v : Json.value) = Json.member (name, v)
  fun string (name, v) = case field (name, v) of SOME (Json.String s) => s | _ => ""
  fun int (name, v) = case Option.mapPartial Json.toInt (field (name, v)) of SOME k => k | NONE => 0
  fun list (name, v) = case field (name, v) of SOME (Json.Array xs) => xs | _ => []
  fun str s = Json.String s
  fun num k = Json.int k
  fun items (v : Json.value) = case v of Json.Array xs => xs | _ => []

  (* what an adapter does beside DAP's minimum *)
  fun capabilities () : Json.value =
    Json.Object [("supportsConfigurationDoneRequest", Json.Bool true),
                 ("supportsEvaluateForHovers", Json.Bool true),
                 ("supportsTerminateRequest", Json.Bool true),
                 ("exceptionBreakpointFilters",
                  Json.Array [Json.Object [("filter", str "uncaught"), ("label", str "Uncaught exceptions"),
                                           ("default", Json.Bool false)],
                              Json.Object [("filter", str "all"), ("label", str "All exceptions"),
                                           ("default", Json.Bool false)]])]

  (* setBreakpoints: the engine's debug/setBreakpoints, and the answer back *)
  fun breakpointsParams (args : Json.value) : Json.value =
    Json.Object [("path", str (case field ("source", args) of SOME s => string ("path", s) | NONE => "")),
                 ("lines", Json.Array (List.map (fn b => num (int ("line", b))) (list ("breakpoints", args))))]
  fun breakpointsBody (v : Json.value) : Json.value =
    Json.Object [("breakpoints",
                  Json.Array (List.map (fn b => Json.Object [("verified", getOpt (field ("verified", b), Json.Bool false)),
                                                             ("line", num (int ("line", b)))])
                                       (list ("breakpoints", v))))]

  (* setExceptionBreakpoints: the engine's mode of its stops at a raise *)
  fun raiseParams (args : Json.value) : Json.value =
    let val filters = List.mapPartial (fn Json.String f => SOME f | _ => NONE) (list ("filters", args))
    in
      Json.Object [("mode", str (if List.exists (fn f => f = "all") filters then "all"
                                 else if List.exists (fn f => f = "uncaught") filters then "uncaught" else "none"))]
    end

  (* the frames of a stop (debug/frames) as a stackTrace's; a source is a
     file's path, but for an entry of the session (stdIn#k), which has a
     name only *)
  fun stackTraceBody (v : Json.value) : Json.value =
    let
      val frames = items v
      fun frame f =
        let val file = string ("file", f)
        in
          Json.Object ([("id", num (int ("id", f))), ("name", str (string ("function", f))),
                        ("line", num (int ("line", f))), ("column", num (int ("column", f)))]
                       @ (if file = "" then []
                          else [("source", Json.Object ([("name", str (OS.Path.file file))]
                                                        @ (if String.isPrefix "stdIn" file then [] else [("path", str file)])))]))
        end
    in Json.Object [("stackFrames", Json.Array (List.map frame frames)), ("totalFrames", num (List.length frames))] end

  (* the scope of a frame: its variables, by a reference that names the frame *)
  fun scopesBody (args : Json.value) : Json.value =
    Json.Object [("scopes", Json.Array [Json.Object [("name", str "Locals"), ("presentationHint", str "locals"),
                                                     ("variablesReference", num (int ("frameId", args) + 1)),
                                                     ("expensive", Json.Bool false)]])]

  (* a reference above this is a value's handle in the engine, below it a
     frame's variables *)
  val childBase = 100000

  (* variables: the engine's request for the reference, and its answer as DAP's *)
  fun variablesRequest (args : Json.value) : string * Json.value =
    let val r = int ("variablesReference", args)
    in
      if r <= childBase then ("debug/variables", Json.Object [("frame", num (r - 1))])
      else ("value/children", Json.Object [("handle", num (r - childBase))])
    end
  fun variablesBody (v : Json.value) : Json.value =
    let
      fun one x =
        let
          val name = case field ("name", x) of SOME (Json.String n) => n | _ => string ("label", x)
          val ty = string ("type", x)
        in
          Json.Object ([("name", str name), ("value", str (string ("shown", x))),
                        ("variablesReference", num (if field ("more", x) = SOME (Json.Bool true)
                                                    then int ("handle", x) + childBase else 0))]
                       @ (if ty = "" then [] else [("type", str ty)]))
        end
    in Json.Object [("variables", Json.Array (List.map one (items v)))] end

  (* evaluate: at a stop in the frame, else in the session *)
  fun evaluateRequest (args : Json.value, stopped : bool) : string * Json.value =
    if stopped then ("debug/evaluate", Json.Object [("frame", num (int ("frameId", args))), ("text", str (string ("expression", args)))])
    else ("eval", Json.Object [("text", str (string ("expression", args)))])

  (* what an outcome says went wrong: an error, or an exception nothing
     handled; NONE where it went well (a warning is not wrong) *)
  fun failure (v : Json.value) : string option =
    case List.find (fn d => string ("severity", d) = "error") (list ("diagnostics", v)) of
      SOME d => SOME (string ("message", d))
    | NONE =>
        case field ("exception", v) of
          SOME (e as Json.Object _) => SOME ("uncaught exception " ^ string ("message", e))
        | _ => NONE

  (* an evaluation's answer: its last value, with a reference where it has
     parts, or what it declared; Fail where it failed *)
  fun evaluateBody (v : Json.value) : Json.value =
    case failure v of
      SOME why => raise Fail why
    | NONE =>
        case List.rev (list ("bindings", v)) of
          b :: _ => Json.Object [("result", str (string ("shown", b))), ("type", str (string ("type", b))),
                                 ("variablesReference", num 0)]
        | [] => Json.Object [("result", str (String.concatWith "\n" (List.mapPartial (fn Json.String s => SOME s | _ => NONE)
                                                                                      (list ("declared", v))))),
                             ("variablesReference", num 0)]

  (* the engine's debug/stopped as DAP's stopped event; one thread *)
  fun stoppedBody (p : Json.value) : Json.value =
    Json.Object ([("reason", str (string ("reason", p))), ("threadId", num 1), ("allThreadsStopped", Json.Bool true),
                  ("description", str (string ("description", p)))]
                 @ (case field ("exception", p) of
                      SOME e => [("text", str (string ("message", e)))]
                    | NONE => []))

  (* continue, next, stepIn, stepOut: the engine's debug/continue mode *)
  fun continueMode (command : string) : string option =
    case command of
      "continue" => SOME "continue" | "next" => SOME "next" | "stepIn" => SOME "stepIn" | "stepOut" => SOME "stepOut"
    | _ => NONE

  fun threadsBody () : Json.value =
    Json.Object [("threads", Json.Array [Json.Object [("id", num 1), ("name", str "main")]])]
end

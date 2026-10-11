(* The REPL's engine (docs/plans/repl.md, D20 and M10): the session as
   operations that answer with data rather than print, for a front in
   another process -- an editor, the Jupyter kernel, a debug adapter -- that
   drives it through docs/repl-protocol.md (src/repl/protocol.sml). The
   terminal front calls the same session in-process.

   An evaluation's answer is its declarations' values, each laid out and
   with a handle, what else they declared, the diagnostics in rune-ide's
   schema (Diagnostic.item), and the exception that ended it, with the
   frames it left. What the program writes stays on its own standard output
   and error, which the front drains. A handle names a value's document, so
   that a front opens it a level at a time (`children`); the table of them
   holds what it names until the front releases it. *)
signature ENGINE =
sig
  (* a value bound: its name, type, the line the REPL says of it as text
     and as HTML, and its handle *)
  type binding = {name : string, ty : string, shown : string, line : string, html : string, id : int}
  (* css: the palette's rules of the roles the bindings' HTML uses *)
  type outcome = {ok : bool, bindings : binding list, declared : string list, messages : string list,
                  diagnostics : Json.value list,
                  exn : {name : string, message : string, trace : Runtime.frame list} option, css : string}

  datatype completeness = Complete | Incomplete of int | Invalid

  (* the width values are laid out at *)
  val width : int ref

  val eval : string -> outcome
  val use : string -> outcome
  val reload : bool -> outcome
  val isComplete : string -> completeness
  val complete : string * int -> {start : int, candidates : string list}
  val inspect : string -> {info : string option, doc : string option}
  val typeAt : string * int -> {name : string, ty : string, start : int, stop : int} option
  val check : string -> Json.value list
  val children : int -> {label : string, shown : string, id : int, more : bool} list
  val release : int list -> unit
end

structure ReplEngine : ENGINE =
struct
  type binding = {name : string, ty : string, shown : string, line : string, html : string, id : int}
  type outcome = {ok : bool, bindings : binding list, declared : string list, messages : string list,
                  diagnostics : Json.value list,
                  exn : {name : string, message : string, trace : Runtime.frame list} option, css : string}

  datatype completeness = Complete | Incomplete of int | Invalid

  val width = ref 80

  (* ---- the handles: documents by number, held until released ---- *)

  val handles : RuneCompiler.pretty IntMap.map ref = ref IntMap.empty
  val next = ref 1

  fun hold (p : RuneCompiler.pretty) : int =
    let val h = !next in next := h + 1; handles := IntMap.insert (!handles, h, p); h end

  fun release (hs : int list) : unit =
    List.app (fn h => if IntMap.member (!handles, h) then handles := IntMap.remove (!handles, h) else ()) hs

  fun shown (p : RuneCompiler.pretty) : string = Pretty.render (!width) (ReplFront.toDoc p)

  (* the parts of a document a front opens it into: a block's items but
     its breaks and its punctuation; a field of a record by its label; a
     part in a role -- a number, a string, a constructor alone -- has none *)
  fun parts (p : RuneCompiler.pretty) : (string * RuneCompiler.pretty) list =
    let
      val punctuation = ["[", "]", "(", ")", "{", "}", ",", "#[", "fromList[", "..."]
      fun isLeaf q =
        case q of
          RuneCompiler.PrettyBlock (_, _, [RuneCompiler.ContextProperty ("role", _)], _) => true
        | RuneCompiler.PrettyString _ => true
        | RuneCompiler.PrettyStringWithWidth _ => true
        | _ => false
      fun label (k, q) =
        case q of
          RuneCompiler.PrettyBlock (_, _, [], RuneCompiler.PrettyString l :: RuneCompiler.PrettyBreak _ :: rest) =>
            if String.isSuffix " =" l then (String.substring (l, 0, String.size l - 2),
                                            case rest of [v] => v | _ => RuneCompiler.PrettyBlock (0, false, [], rest))
            else (Int.toString k, q)
        | _ => (Int.toString k, q)
    in
      case p of
        RuneCompiler.PrettyBlock (_, _, [RuneCompiler.ContextProperty ("role", _)], _) => []
      | RuneCompiler.PrettyBlock (_, _, _, items) =>
          let
            val kept = List.filter (fn RuneCompiler.PrettyBreak _ => false
                                     | RuneCompiler.PrettyLineBreak => false
                                     | RuneCompiler.PrettyString s => not (List.exists (fn x => x = s) punctuation)
                                     | q => not (isLeaf q andalso List.exists (fn x => x = RuneShow.flat q) punctuation))
                                   items
          in #2 (List.foldl (fn (q, (k, acc)) => (k + 1, acc @ [label (k, q)])) (1, []) kept) end
      | _ => []
    end

  fun children (h : int) : {label : string, shown : string, id : int, more : bool} list =
    case IntMap.find (!handles, h) of
      NONE => raise Fail ("no value has the handle " ^ Int.toString h)
    | SOME p => List.map (fn (l, q) => {label = l, shown = shown q, id = hold q, more = not (List.null (parts q))})
                         (parts p)

  (* ---- what the loop prints, taken ---- *)

  fun diagnostics () : Json.value list =
    List.map (fn (level, sp, msg) => Diagnostic.item (level, sp, msg)) (List.rev (!Error.kept))

  (* f () with the REPL's output taken as data, and its ok *)
  fun capture (f : unit -> bool) : outcome =
    let
      val bindings = ref []
      val declared = ref []
      val messages = ref []
      val raised = ref NONE
      val echo = !RuneCompiler.echoHook
      val roles = ref []
      fun bound (n, p, t) =
        let
          val d = ReplFront.echoDoc (n, p, t)
          val (h, used) = ReplFront.html d
        in
          roles := used @ !roles;
          bindings := {name = n, ty = t, shown = shown p, line = Pretty.render (!width) d, html = h, id = hold p}
                      :: !bindings
        end
      val () = RuneCompiler.echoHook := bound
      val () = ReplLoop.declaredHook := (fn ds => declared := !declared @ ds)
      val () = ReplLoop.uncaughtHook :=
                 SOME (fn e => raised := SOME {name = General.exnName e, message = General.exnMessage e,
                                               trace = !ReplLoop.lastTrace})
      val () = ReplLoop.sayHook := SOME (fn s => messages := s :: !messages)
      val () = (Error.silent := true; Error.keep := true; Error.kept := [])
      fun restore () =
        (RuneCompiler.echoHook := echo; ReplLoop.uncaughtHook := NONE; ReplLoop.sayHook := NONE;
         Error.silent := false; Error.keep := false)
      val ok = (f () handle e => (ReplLoop.uncaught e; false)) handle e => (restore (); raise e)
      val diags = diagnostics ()
    in
      restore ();
      {ok = ok andalso not (isSome (!raised)) andalso List.null diags, bindings = List.rev (!bindings),
       declared = !declared, messages = List.rev (!messages), diagnostics = diags, exn = !raised,
       css = if List.null (!roles) then "" else Color.cssOf (!roles)}
    end

  (* a text that does not end its last declaration with a `;` ends it, as a
     notebook's cell or -e's text is written *)
  fun eval (text : string) : outcome =
    let val whole = if ReplScan.complete (ReplScan.ofText (text ^ "\n")) then text else text ^ "\n;"
    in capture (fn () => #2 (ReplLoop.step (whole, true))) end

  fun use (file : string) : outcome = capture (fn () => (ReplLoop.use file; true))

  fun reload (force : bool) : outcome = capture (fn () => ((if force then ReplLoop.restart () else ReplLoop.reload ()); true))

  fun isComplete (text : string) : completeness =
    let val scan = ReplScan.ofText (text ^ "\n")
    in
      if CharVector.all Char.isSpace text then Complete
      else if not (ReplScan.complete scan) then Incomplete (ReplScan.depth scan)
      else case ReplLoop.parse ("stdIn", text) of
             ReplLoop.Decs _ => Complete
           | ReplLoop.More => Incomplete (ReplScan.depth scan)
           | ReplLoop.Wrong _ => Invalid
    end

  fun complete (text : string, offset : int) = ReplComplete.complete (!ReplSession.env) (text, offset)

  fun inspect (name : string) : {info : string option, doc : string option} =
    {info = SOME (ReplCommands.info name) handle Fail _ => NONE,
     doc = SOME (ReplDoc.doc (!ReplSession.env, name)) handle Fail _ => NONE}

  fun typeAt (text : string, offset : int) =
    Option.map (fn (name, t, {start, stop, ...} : Source.span) =>
                  {name = name, ty = ReplShow.typeIn (!ReplSession.env) t, start = start, stop = stop})
               (Serve.variableAt ([("stdIn", ReplQuery.elaborated text)], "stdIn", offset))
    handle Error.CompileError _ => NONE | ReplSession.Reported => NONE

  fun check (text : string) : Json.value list =
    let
      val () = (Error.silent := true; Error.keep := true; Error.kept := [])
      val () = (ignore (ReplQuery.elaborated text) handle Error.CompileError (sp, msg) => Error.note ("error", sp, msg)
                                                       | ReplSession.Reported => ())
      val ds = diagnostics ()
    in Error.silent := false; Error.keep := false; ds end
    handle e => (Error.silent := false; Error.keep := false; raise e)
end

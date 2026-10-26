(* The REPL's debugger (docs/plans/repl.md, D22 and M12; runtime/debug.c):
   breakpoints, the stops at them, at a step, at a pause and at a raise, the
   frames of a stop and their variables, and expressions evaluated in a
   frame.

   The VM calls `stopped` where the program stops, on the frames it stopped
   in; it asks the front what to do -- the terminal a prompt of its own, the
   engine its front (stopHook) -- and then says how the program goes on: on,
   a step in, over or out, or the interrupt raised. While the debugger has
   anything to stop at, the declarations are compiled for it (`-g`,
   ReplSession.debugging) and the program runs in the VM's debug loop.

   A frame's variables are those the compiler kept of its function: each
   read from its register or its closure, where it holds a value there, and
   shown by a printer made from its type as an echo's is (ReplShow); an
   expression at a stop is `fn (x : t, ...) => exp` applied to them. *)
structure ReplDebug =
struct
  type frame = {k : int, function : string, file : string, line : int, column : int}

  (* the stop, while the program is at one: what stopped it and its frames,
     innermost first, each with the VM's frame it is of (k); the frame
     looked at; how the stop is to end (RuneRuntime.debugStep) *)
  val current : {event : int, frames : frame list} option ref = ref NONE
  val selected = ref 0
  val resume : int option ref = ref NONE

  fun isStopped () = isSome (!current)

  (* what the debugger stops at: breakpoints by file and line, in the order
     they were set; a raise (0 none, 1 every one, 2 one nothing of the
     program's handles); and whether Ctrl-C pauses the program *)
  val breaks : (string * int) list ref = ref []
  val raises = ref 0
  val pauses = ref false

  (* the front's answer to a stop: the terminal's prompt, or the engine's *)
  val stopHook : (int -> unit) ref = ref (fn _ => ())

  fun eventName (event : int) : string =
    case event of
      1 => "a breakpoint" | 2 => "a step" | 3 => "a pause" | 4 => "a raise" | _ => "an exception nothing handles"

  (* the VM's mode and breakpoints as the debugger's are now *)
  fun apply () : unit =
    let
      val mode = (if null (!breaks) then 0 else 1) + (case !raises of 1 => 2 | 2 => 4 | _ => 0) + (if !pauses then 8 else 0)
    in
      ignore (RuneRuntime.debugMode mode);
      ignore (RuneRuntime.debugBreak ("", 0, false));
      List.app (fn (f, l) => ignore (RuneRuntime.debugBreak (f, l, true))) (!breaks)
    end

  fun framesOf () : frame list =
    List.map (fn (k, f, file, l, c) => {k = k, function = f, file = file, line = l, column = c}) (RuneRuntime.debugFrames ())

  (* What the VM calls where the program stops: the front asked, and the
     program on as it says (on, where nothing does). Nothing escapes it: an
     exception out of the hook would leave the VM in it. *)
  fun stopped (event : int) : unit =
    ((current := SOME {event = event, frames = framesOf ()};
      selected := 0;
      resume := NONE;
      (!stopHook event) handle _ => ();
      current := NONE;
      apply ();
      RuneRuntime.debugStep (getOpt (!resume, 0)))
     handle _ => (current := NONE; RuneRuntime.debugStep 0))

  (* the hook installed, the first time the debugger is asked for anything,
     and debugging on: what is compiled from now on is for the debugger *)
  val installed = ref false
  fun ensure () : unit =
    (if !installed then ()
     else if RuneRuntime.debugHook stopped then installed := true
     else raise Fail "this VM has no debugger";
     ReplSession.debugging := true;
     (* each entry a source of its own, stdIn#k, which a frame names *)
     ReplLoop.numbered := true)

  (* ---- breakpoints ---- *)

  (* the name a file has in the program: the file used of that name, or of
     that base name where one is, else the name given (a file not used yet) *)
  fun fileFor (file : string) : string =
    let val used = List.map #file (!ReplLoop.usedFiles)
    in
      if List.exists (fn f => f = file) used then file
      else
        case List.filter (fn f => OS.Path.file f = OS.Path.file file) used of
          [f] => f
        | _ => file
    end

  (* the file a breakpoint of a line alone is in: the frame looked at, else
     the file used last *)
  fun defaultFile () : string =
    case (!current, !ReplLoop.lastUsed) of
      (SOME {frames, ...}, _) =>
        (case List.drop (frames, !selected) handle Subscript => [] of
           {file, ...} :: _ => if file = "" then raise Fail "which file?" else file
         | [] => raise Fail "which file?")
    | (NONE, SOME f) => f
    | (NONE, NONE) => raise Fail "which file? (:break FILE:LINE)"

  (* a breakpoint at FILE:LINE, or at LINE: how many places of the code begin
     the line, 0 where none does yet *)
  fun setBreak (file : string, line : int) : int =
    (ensure ();
     if List.exists (fn b => b = (file, line)) (!breaks) then () else breaks := !breaks @ [(file, line)];
     apply ();
     RuneRuntime.debugBreak (file, line, true))

  fun clearBreak (file : string, line : int) : unit =
    (breaks := List.filter (fn b => b <> (file, line)) (!breaks); apply ())

  fun parseBreak (arg : string) : string * int =
    let
      val (file, line) =
        case String.fields (fn c => c = #":") arg of
          [l] => (defaultFile (), l)
        | parts => (String.concatWith ":" (List.take (parts, List.length parts - 1)), List.last parts)
    in
      case Int.fromString line of
        SOME n => if n > 0 then (fileFor file, n) else raise Fail ("not a line: " ^ line)
      | NONE => raise Fail ("not a line: " ^ line)
    end

  fun setRaises (mode : int) : unit = (ensure (); raises := mode; apply ())
  fun setPauses (on : bool) : unit = (if on then ensure () else (); pauses := on; apply ())

  (* ---- the frames and their variables ---- *)

  (* line `line` of a source: the session's own, else the file's *)
  fun sourceLine (file : string, line : int) : string option =
    let
      fun fromDisk () =
        let
          val ins = TextIO.openIn file
          fun go k = case TextIO.inputLine ins of
                       NONE => NONE
                     | SOME l => if k = line then SOME l else go (k + 1)
        in (go 1 before TextIO.closeIn ins) handle e => (TextIO.closeIn ins; raise e) end
        handle IO.Io _ => NONE
      fun strip l = let val l = if String.isSuffix "\n" l then String.substring (l, 0, size l - 1) else l
                    in if String.isSuffix "\r" l then String.substring (l, 0, size l - 1) else l end
    in
      Option.map strip
        (case Source.findFile file of
           SOME {text, lineStarts, line = first, ...} =>
             let val idx = line - first - 1
             in
               if text = "" orelse idx < 0 orelse idx >= Vector.length lineStarts then fromDisk ()
               else
                 let
                   val a = Vector.sub (lineStarts, idx)
                   val b = if idx + 1 < Vector.length lineStarts then Vector.sub (lineStarts, idx + 1) else size text
                 in SOME (String.substring (text, a, Int.max (0, b - a))) end
             end
         | NONE => fromDisk ())
    end

  fun whereOf ({function, file, line, column, ...} : frame) : string =
    function ^ (if file = "" then "" else " at " ^ Source.shownPlace (file, line, column))

  fun selectedFrame () : frame option =
    case !current of
      SOME {frames, ...} => (SOME (List.nth (frames, !selected)) handle Subscript => NONE)
    | NONE => NONE

  fun isUnit (t : Types.ty) = case Types.prune t of Types.TRecord [] => true | _ => false

  (* whether every value of the type is a pointer, so that an immediate in
     its register is no value of it (one not set yet, or found dead) *)
  fun pointerOnly (t : Types.ty) : bool =
    case Types.prune t of
      Types.TRecord [] => false
    | Types.TRecord _ => true
    | Types.TCon (c, _) =>
        let val s = #stamp c
        in
          List.exists (fn c' => s = #stamp c')
                      [Types.stringTycon, Types.refTycon, Types.arrayTycon, Types.vectorTycon, Types.exnTycon]
          orelse (case IntMap.find (!Elaborate.dataCons, s) of
                    SOME cons => not (List.exists (fn (_, Env.Con {info, ...}) => not (#hasArg info) | _ => false) cons)
                  | NONE => false)
        end
    | _ => false

  (* the variables of VM frame k that hold a value: name, type, and the SML
     that reads it -- one set by where the frame is, whose register holds
     what its type may; the last bound of each name (one a later binding
     hides is not shown), in the order they were bound *)
  fun variables (k : int) : (string * Types.ty * string) list =
    case RuneRuntime.debugWhere k of
      (~1, _) => []
    | (f, pc) =>
        case ReplSession.varsOf f of
          NONE => []
        | SOME vars =>
            let
              val i = Int.toString
              fun read ({name, ty, place} : ReplSession.var) =
                case place of
                  ReplSession.Reg (r, at) =>
                    if pc < at then NONE
                    else if isUnit ty then SOME (name, ty, "()")
                    else
                      (case RuneRuntime.debugLive (k, r) of
                         0 => NONE
                       | 1 => if pointerOnly ty then NONE else SOME (name, ty, "RuneDebug.register (" ^ i k ^ ", " ^ i r ^ ")")
                       | _ => SOME (name, ty, "RuneDebug.register (" ^ i k ^ ", " ^ i r ^ ")"))
                | ReplSession.Captured e => SOME (name, ty, "RuneDebug.env (" ^ i k ^ ", " ^ i e ^ ")")
              (* the list has the latest binding first *)
              fun dedupe ([], _) = []
                | dedupe ((v as (n, _, _)) :: rest, seen) =
                    if List.exists (fn s => s = n) seen then dedupe (rest, seen) else v :: dedupe (rest, n :: seen)
            in List.rev (dedupe (List.mapPartial read vars, [])) end

  (* the declaration that shows the variables as echoes, run *)
  fun show (vars : (string * Types.ty * string) list) : unit =
    case ReplShow.echoesOf (!ReplSession.env, vars, []) of
      NONE => ()
    | SOME (text, extra) =>
        let
          (* the variables' names may be Unicode: read as --unicode reads *)
          val file = Source.fromStringIn (Source.Unicode Source.Utf8, "<locals>", text)
          val () = Source.register file
          val (decs, _) = Parser.parseTokensWith (Lexer.tokenize file, Fixity.initial)
          val {run, delta, bind, ...} = ReplSession.compileWith (decs, "<locals>", text, NONE, extra)
        in
          run ();
          ReplSession.env := Env.plus (!ReplSession.env, delta);
          bind ();
          Source.unregister "<locals>"
        end

  (* the variables of VM frame k as the echoes would show them, taken as
     documents rather than printed (the engine's) *)
  fun collect (k : int) : (string * RuneCompiler.pretty * string) list =
    let
      val got = ref []
      val echo = !RuneCompiler.echoHook
    in
      RuneCompiler.echoHook := (fn v => got := v :: !got);
      (show (variables k) before RuneCompiler.echoHook := echo) handle e => (RuneCompiler.echoHook := echo; raise e);
      List.rev (!got)
    end

  fun showLocals () : unit =
    case selectedFrame () of
      NONE => raise Fail "the program is not stopped"
    | SOME {k, ...} =>
        (case variables k of
           [] => ReplLoop.ui "  no variables here (the frame's function was not compiled for the debugger, or binds none)"
         | vars => show vars)

  (* An expression at a stop, or `val y = exp`, in the frame looked at:
     `val it = (fn (x : t, ...) => exp) (values)`, the expression's tokens
     its own, where the frame has variables whose types the session names;
     else NONE, and the entry is run as any other. *)
  fun evalIn (name : string, text : string, decs : Ast.dec list) : bool option =
    case (selectedFrame (), decs) of
      (SOME {k, ...}, [Ast.DVal ([], [(Ast.PVar (([], bound), _, _, _), _)], _, _)]) =>
        let
          val env = !ReplSession.env
          fun nameable (n, t, _) =
            Ident.isAlphanumeric n
            andalso not (String.isSubstring "?" (ReplShow.typeIn env t))
          val vars = List.filter nameable (variables k)
        in
          if null vars then NONE
          else
            let
              fun tokens (src : string, s : string) =
                let
                  val f = Source.fromStringIn (Source.Unicode Source.Utf8, src, s)
                  val () = Source.register f
                  val ts = Lexer.tokenize f
                in VectorSlice.vector (VectorSlice.slice (ts, 0, SOME (Vector.length ts - 1))) end
              (* the expression's tokens: the entry's, less its `;`, and
                 less `val x =` where it is a declaration *)
              val user =
                let
                  val f = Source.fromStringIn (ReplSession.typedMode (), name, text)
                  val () = Source.register f
                  val ts = Lexer.tokenize f
                  val n = Vector.length ts - 1
                  val n = if n > 0 andalso #1 (Vector.sub (ts, n - 1)) = Token.SEMI then n - 1 else n
                  val from = if n >= 3 andalso #1 (Vector.sub (ts, 0)) = Token.VAL then 3 else 0
                in (VectorSlice.vector (VectorSlice.slice (ts, from, SOME (n - from))), #2 (Vector.sub (ts, Vector.length ts - 1))) end
              val pre = "val " ^ bound ^ " = (fn ("
                        ^ String.concatWith ", " (List.map (fn (n, t, _) => n ^ " : " ^ ReplShow.typeIn env t) vars)
                        ^ ") => ("
              val post = ")) (" ^ String.concatWith ", " (List.map #3 vars) ^ ")"
              val toks = Vector.concat [tokens ("<frame>", pre), #1 user, tokens ("<frame>", post),
                                        Vector.fromList [(Token.SEMI, #2 user), (Token.EOF, #2 user)]]
            in
              case SOME (#1 (Parser.parseTokensWith (toks, !ReplSession.fixity))) handle Error.CompileError _ => NONE of
                NONE => NONE
              | SOME wrapped => SOME (ReplLoop.run (wrapped, name, text, NONE, false))
            end
        end
    | _ => NONE

  (* ---- the terminal's stop ---- *)

  fun excerpt (file : string, line : int) : string =
    case sourceLine (file, line) of
      SOME l => ReplFront.paint "diag.gutter" (StringCvt.padLeft #" " 5 (Int.toString line) ^ " |") ^ " "
                ^ ReplHighlight.paint (!ReplSession.env, l, ReplHighlight.code) ^ "\n"
    | NONE => ""

  fun describe () : string =
    case (!current, selectedFrame ()) of
      (SOME {event, ...}, SOME (fr as {file, line, ...})) =>
        let
          val what =
            case event of
              4 => "a raise of " ^ General.exnMessage (RuneRuntime.debugExn ()) ^ ", which a handler of the program's takes"
            | 5 => "a raise of " ^ General.exnMessage (RuneRuntime.debugExn ()) ^ ", which nothing of the program's handles"
            | e => eventName e
        in
          ReplFront.paint "repl.ui" ("stopped at " ^ what ^ ": in " ^ whereOf fr) ^ "\n" ^ excerpt (file, line)
        end
    | _ => ""

  fun terminal (event : int) : unit =
    (ReplFront.freshLine ();
     print (describe ());
     ReplLoop.nested ("debug> ", fn () => isSome (!resume)))

  (* the frames of the stop, the one looked at marked (:bt at a stop) *)
  fun backtrace () : string =
    case !current of
      NONE => raise Fail "the program is not stopped"
    | SOME {frames, ...} =>
        String.concat (List.tabulate (List.length frames, fn i =>
                         (if i = !selected then "> " else "  ") ^ Int.toString i ^ " in " ^ whereOf (List.nth (frames, i)) ^ "\n"))

  fun selectFrame (arg : string) : string =
    case !current of
      NONE => raise Fail "the program is not stopped"
    | SOME {frames, ...} =>
        (case arg of
           "" => ()
         | "up" => selected := Int.min (!selected + 1, List.length frames - 1)
         | "down" => selected := Int.max (!selected - 1, 0)
         | _ => case Int.fromString arg of
                  SOME n => if n >= 0 andalso n < List.length frames then selected := n
                            else raise Fail ("no frame " ^ arg ^ " (:bt lists them)")
                | NONE => raise Fail ("not a frame: " ^ arg);
         case selectedFrame () of
           SOME (fr as {file, line, ...}) => "frame " ^ Int.toString (!selected) ^ ": in " ^ whereOf fr ^ "\n" ^ excerpt (file, line)
         | NONE => "")

  (* how a stop ends *)
  fun go (mode : int) : unit = if isStopped () then resume := SOME mode else raise Fail "the program is not stopped"

  fun listBreaks () : string =
    (case !breaks of
       [] => "no breakpoints\n"
     | bs => String.concat (List.tabulate (List.length bs, fn i =>
                              let val (f, l) = List.nth (bs, i) in "  " ^ Int.toString (i + 1) ^ "  " ^ f ^ ":" ^ Int.toString l ^ "\n" end)))
    ^ (case !raises of 1 => "  and at every raise\n" | 2 => "  and at a raise nothing handles\n" | _ => "")

  (* :break ARG *)
  fun break (arg : string) : string =
    case String.tokens Char.isSpace arg of
      [] => listBreaks ()
    | ["raise"] => (setRaises 2; "stops at a raise nothing of the program's handles\n")
    | ["raise", "all"] => (setRaises 1; "stops at every raise\n")
    | [spec] =>
        let
          val (file, line) = parseBreak spec
          val n = setBreak (file, line)
        in
          "breakpoint " ^ Int.toString (List.length (!breaks)) ^ " at " ^ file ^ ":" ^ Int.toString line
          ^ (if n = 0 then " (no code there yet: a file used from now on, compiled for the debugger, may have some)" else "")
          ^ "\n"
        end
    | _ => raise Fail ":break FILE:LINE, :break LINE, :break raise or :break raise all"

  (* :delete ARG *)
  fun delete (arg : string) : string =
    case arg of
      "all" => (breaks := []; raises := 0; apply (); "no breakpoints\n")
    | "raise" => (raises := 0; apply (); "no stops at a raise\n")
    | _ =>
        case Int.fromString arg of
          SOME n =>
            (case (SOME (List.nth (!breaks, n - 1)) handle Subscript => NONE) of
               SOME b => (clearBreak b; "breakpoint " ^ arg ^ " deleted\n")
             | NONE => raise Fail ("no breakpoint " ^ arg ^ " (:break lists them)"))
        | NONE => raise Fail ":delete N, :delete raise or :delete all"

  val () = (stopHook := terminal; ReplLoop.evalHook := evalIn;
            (* a unit linked may have the lines of a breakpoint *)
            ReplSession.linkedHook := (fn () => if !installed then apply () else ()))
end

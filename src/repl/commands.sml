(* The REPL's commands (docs/plans/repl.md, D15 and M8): a `:` and a name of
   letters, which begin no SML, the rest of the line their argument, no `;`
   needed; any unique prefix of a name names it, as in GHCi (`:t` for
   `:type`). The same are functions of the structure `Repl` of the session
   (lib/basis/repl.sml), for init files, scripts and HOL4, through hooks this
   puts in RuneRepl at start. *)
structure ReplCommands =
struct
  type command = {name : string, args : string, help : string, run : string -> unit}

  fun say (s : string) = (ReplFront.freshLine (); TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)
  fun complain (s : string) = ReplLoop.err (s ^ "\n")

  fun paint role s = ReplFront.paint role s

  fun trim (s : string) : string =
    Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full s)))

  (* ---- the settings (:set, :show) ---- *)

  (* the timing of each entry (:time) *)
  val timing = ReplLoop.timing

  val settings : (string * string * (unit -> string) * (string -> unit)) list =
    let
      fun int (r : int ref) = (fn () => Int.toString (!r),
                               fn v => case Int.fromString v of SOME k => r := k | NONE => raise Fail ("not a number: " ^ v))
      fun bool (r : bool ref) = (fn () => if !r then "on" else "off",
                                 fn v => case v of "on" => r := true | "off" => r := false
                                                 | _ => raise Fail ("on or off, not " ^ v))
      fun named (r : string ref, choices) =
        (fn () => !r,
         fn v => if List.exists (fn c => c = v) choices then r := v
                 else raise Fail ("one of " ^ String.concatWith ", " choices ^ ", not " ^ v))
      fun row (name, help, (get, set)) = (name, help, get, set)
    in
      [row ("depth", "levels of a value printed (Compiler.printDepth)", int RuneCompiler.printDepth),
       row ("length", "items of a list, an array or a vector printed (Compiler.printLength)", int RuneCompiler.printLength),
       row ("string", "characters of a string printed (Compiler.stringLength)", int RuneCompiler.stringLength),
       row ("width", "columns a value is laid out in without a terminal (Compiler.lineLength)", int RuneCompiler.lineLength),
       row ("feedback", "what is said of a declaration: normal, concise, verbose or silent",
            named (RuneCompiler.feedback, ["normal", "concise", "verbose", "silent"])),
       row ("prompt", "the prompt (Compiler.prompt1)", (fn () => !RuneCompiler.prompt1, fn v => RuneCompiler.prompt1 := v)),
       row ("prompt2", "the prompt of a line that continues an entry (Compiler.prompt2)",
            (fn () => !RuneCompiler.prompt2, fn v => RuneCompiler.prompt2 := v)),
       row ("time", "the time and memory of each entry (:time)", bool timing),
       row ("watch", "reload at each prompt where a file used has changed", bool ReplLoop.watching),
       row ("debug", "compile what is entered and used for the debugger (:break turns it on)",
            (fn () => if !ReplSession.debugging then "on" else "off",
             fn v => case v of "on" => ReplDebug.ensure () | "off" => ReplSession.debugging := false
                             | _ => raise Fail ("on or off, not " ^ v))),
       row ("keys", "the editor's keys: emacs, or vi for Vi's modes",
            (fn () => case !ReplFront.keys of LineEdit.Vi => "vi" | LineEdit.Emacs => "emacs",
             fn v => case v of "vi" => ReplFront.keys := LineEdit.Vi | "emacs" => ReplFront.keys := LineEdit.Emacs
                             | _ => raise Fail ("emacs or vi, not " ^ v))),
       row ("pause", "Ctrl-C pauses the program in the debugger rather than interrupting it",
            (fn () => if !ReplDebug.pauses then "on" else "off",
             fn v => case v of "on" => ReplDebug.setPauses true | "off" => ReplDebug.setPauses false
                             | _ => raise Fail ("on or off, not " ^ v)))]
    end

  fun set (name : string, value : string) : unit =
    case List.filter (fn (n, _, _, _) => String.isPrefix name n) settings of
      [(_, _, _, setter)] => setter value
    | [] => raise Fail ("no setting " ^ name ^ " (:show lists them)")
    | many => (case List.find (fn (n, _, _, _) => n = name) many of
                 SOME (_, _, _, setter) => setter value
               | NONE => raise Fail ("which setting: " ^ String.concatWith ", " (List.map #1 many) ^ "?"))

  fun show () : string =
    String.concat (List.map (fn (n, help, get, _) => n ^ " = " ^ get () ^ "    " ^ paint "repl.ui" ("(" ^ help ^ ")") ^ "\n")
                            settings)

  (* ---- what a name is (:type, :info, :browse) ---- *)

  fun env () = !ReplSession.env

  fun typeOf (text : string) : string = ReplShow.typeIn (env ()) (ReplQuery.typeOf text)

  (* where a name of the session was defined, as a comment after it *)
  fun place (kind : string, name : string) : string =
    case StringMap.find (!ReplSession.defined, kind ^ " " ^ name) of
      SOME (file, 0) => "  (* from " ^ file ^ " *)"
    | SOME (file, line) => "  (* defined at " ^ file ^ ":" ^ Int.toString line ^ " *)"
    | NONE => ""

  (* SML the REPL says, coloured as it is where it is typed *)
  fun code (text : string, ctx : ReplHighlight.context) : string = ReplHighlight.paint (env (), text, ctx)

  (* the structure a long name is in, and its last part *)
  fun split (name : string) : string list * string =
    let val parts = String.fields (fn c => c = #".") name
    in (List.take (parts, List.length parts - 1), List.last parts) end

  fun fixityOf (name : string) : string option =
    case StringMap.find (#table (!ReplSession.fixity), name) of
      SOME (Fixity.Infix p) => SOME ("infix " ^ Int.toString p ^ " " ^ name)
    | SOME (Fixity.Infixr p) => SOME ("infixr " ^ Int.toString p ^ " " ^ name)
    | _ => NONE

  fun info (name : string) : string =
    let
      val (path, last) = split name
      val e = ReplShow.structureAt (env (), path)
      val t = ReplShow.typeIn (env ())
      val top = List.null path
      fun lines ls = String.concatWith "\n" ls ^ "\n"
      val vals =
        case Option.mapPartial (fn e => StringMap.find (Env.vals e, last)) e of
          SOME (Env.Val {scheme, ...}) => ["val " ^ name ^ " : " ^ t scheme ^ (if top then place ("v", last) else "")]
        | SOME (Env.Prim {scheme, ...}) => ["val " ^ name ^ " : " ^ t scheme]
        | SOME (Env.ConAsVal {scheme, ...}) => ["val " ^ name ^ " : " ^ t scheme]
        | SOME (Env.ExnAsVal {ty, ...}) => ["val " ^ name ^ " : " ^ t ty]
        | SOME (Env.Con {scheme, ...}) =>
            let
              val result = case Types.prune scheme of Types.TArrow (_, r) => r | r => r
              val datatypeLine =
                case Types.prune result of
                  Types.TCon (c, _) =>
                    (case ReplShow.pathOf (env (), c) of
                       SOME p =>
                         let val (tp, tl) = split p
                         in case Option.mapPartial (fn te => StringMap.find (Env.tys te, tl))
                                                   (ReplShow.structureAt (env (), tp)) of
                              SOME ts => ["  " ^ ReplShow.typeSpec (env ()) (p, ts)]
                            | NONE => []
                         end
                     | NONE => [])
                | _ => []
            in ("con " ^ name ^ " : " ^ t scheme) :: datatypeLine end
        | SOME (Env.Exn {ty, info}) =>
            ["exception " ^ name ^ (if #hasArg info then case Types.prune ty of Types.TArrow (a, _) => " of " ^ t a | _ => "" else "")
             ^ (if top then place ("v", last) else "")]
        | NONE => []
      val tys =
        case Option.mapPartial (fn e => StringMap.find (Env.tys e, last)) e of
          SOME ts => [ReplShow.typeSpec (env ()) (name, ts) ^ (if top then place ("t", last) else "")]
        | NONE => []
      val strs =
        case Option.mapPartial (fn e => StringMap.find (Env.strs e, last)) e of
          SOME s => ("structure " ^ name ^ " :" ^ (if top then place ("s", last) else ""))
                    :: "  sig" :: ReplShow.signatureLines (env (), s, "    ") @ ["  end"]
        | NONE => []
      val sigs =
        if not top then []
        else case StringMap.find (!Elaborate.sigs, name) of
               SOME {env = se, ...} => ("signature " ^ name ^ " =") :: "  sig" :: ReplShow.signatureLines (env (), se, "    ")
                                       @ ["  end"]
             | NONE => []
      val funs =
        if not top then []
        else case StringMap.find (!Elaborate.funs, name) of
               SOME (Elaborate.FunInfo {param, paramSig, ...}) =>
                 ["functor " ^ name ^ " (" ^ (case param of SOME p => p ^ " : " | NONE => "")
                  ^ "sig ... end) (" ^ Int.toString (List.length (ReplShow.signatureLines (env (), #env paramSig, "")))
                  ^ " specifications)"]
             | NONE => []
      val fix = if top then (case fixityOf name of SOME f => [f] | NONE => []) else []
    in
      case vals @ tys @ strs @ sigs @ funs @ fix of
        [] => raise Fail ("unbound: " ^ name)
      | ls => lines ls
    end

  fun browse (name : string) : string =
    let val (path, last) = split name
    in
      case ReplShow.structureAt (env (), path @ [last]) of
        SOME s => String.concatWith "\n" (ReplShow.signatureLines (env (), s, "")) ^ "\n"
      | NONE =>
          case StringMap.find (!Elaborate.sigs, name) of
            SOME {env = se, ...} => String.concatWith "\n" (ReplShow.signatureLines (env (), se, "")) ^ "\n"
          | NONE => raise Fail ("no structure or signature " ^ name)
    end

  (* ---- the trace of the last uncaught exception (:bt) ---- *)

  fun frame ({function, file, line, column} : Runtime.frame) : string =
    "  in " ^ function ^ (if file = "" then "" else " at " ^ Source.shownPlace (file, line, column))

  fun backtrace () : string =
    case !ReplLoop.lastTrace of
      [] => "no trace: nothing has raised an exception that the REPL caught\n"
    | frames => String.concat (List.map (fn f => frame f ^ "\n") frames)

  (* ---- the session's entries (:history, :save) ---- *)

  fun history () : string =
    let
      fun go (_, []) = []
        | go (k, (text, ok) :: rest) =
            (paint "repl.ui" (StringCvt.padLeft #" " 4 (Int.toString k) ^ (if ok then "  " else " !")) ^ " "
             ^ String.translate (fn #"\n" => "\n       " | c => String.str c) (trim text) ^ "\n") :: go (k + 1, rest)
    in String.concat (go (1, List.rev (!ReplLoop.entries))) end

  fun save (file : string) : unit =
    let
      val out = TextIO.openOut file
      val good = List.filter #2 (List.rev (!ReplLoop.entries))
    in
      List.app (fn (text, _) => TextIO.output (out, text ^ (if String.isSuffix "\n" text then "" else "\n"))) good;
      TextIO.closeOut out;
      say ("saved " ^ Int.toString (List.length good) ^ " entries to " ^ file ^ "\n")
    end

  fun saveImage (file : string) : unit =
    case Runtime.save file of
      Runtime.Saved => say ("saved the session to " ^ file ^ " (runevm --restore " ^ file ^ ")\n")
    | Runtime.Restored => ()

  (* ---- the shell ---- *)

  fun shell (command : string) : unit =
    (ReplFront.release ();
     ignore (OS.Process.system command))

  fun editor () : string =
    case (OS.Process.getEnv "VISUAL", OS.Process.getEnv "EDITOR") of
      (SOME e, _) => e
    | (NONE, SOME e) => e
    | (NONE, NONE) => "vi"

  (* :edit, at the definition of a name or a file, then the file used again *)
  fun edit (what : string) : unit =
    let
      val (file, line) =
        if what = "" then
          (case !ReplLoop.lastUsed of SOME f => (f, 0) | NONE => raise Fail "which file? (:edit FILE or :edit NAME)")
        else
          case List.mapPartial (fn k => StringMap.find (!ReplSession.defined, k ^ " " ^ what)) ["v", "t", "s"] of
            (f, l) :: _ => if String.isPrefix "stdIn" f orelse String.isPrefix "lib/basis/" f
                           then raise Fail (what ^ " was not defined in a file of yours") else (f, l)
          | [] => (what, 0)
    in
      ignore (OS.Process.system (editor () ^ (if line > 0 then " +" ^ Int.toString line else "") ^ " '" ^ file ^ "'"));
      !ReplLoop.reloadHook file
    end

  (* ---- the table ---- *)

  val table : command list ref = ref []

  fun help (which : string) : string =
    if which = "" then
      "Commands (any unique prefix names one; `;` not needed):\n"
      ^ String.concat (List.map (fn {name, args, help, ...} =>
                                   "  " ^ StringCvt.padRight #" " 24 (":" ^ name ^ (if args = "" then "" else " " ^ args))
                                   ^ help ^ "\n") (!table))
      ^ "The same are functions of the structure Repl: Repl.command \":type 1\", Repl.typeOf \"1\".\n"
    else
      case List.filter (fn {name, ...} => String.isPrefix (if String.isPrefix ":" which then String.extract (which, 1, NONE) else which) name)
                       (!table) of
        [{name, args, help, ...}] => ":" ^ name ^ (if args = "" then "" else " " ^ args) ^ "\n  " ^ help ^ "\n"
      | _ => raise Fail ("no command " ^ which)

  (* the debugger's commands at a stop: these are first where a prefix
     names several (:s is :step, :n :next, :c :continue, :f :frame) *)
  val atStop = ["step", "next", "continue", "finish", "frame", "locals", "abort", "break", "delete"]

  fun find (word : string) : command =
    case List.filter (fn {name, ...} => name = word) (!table) of
      [c] => c
    | _ =>
        (* where a prefix names several, the first in the table, as in
           GHCi: :t is :type, :h is :help *)
        case List.filter (fn {name, ...} => String.isPrefix word name) (!table) of
          [] => raise Fail ("no command :" ^ word ^ " (:help lists them)")
        | cs as c :: _ =>
            if ReplDebug.isStopped () then
              case List.find (fn n => String.isPrefix word n) atStop of
                SOME n => (case List.find (fn {name, ...} => name = n) cs of SOME d => d | NONE => c)
              | NONE => c
            else c

  (* a command line: `:name rest` *)
  fun dispatch (line : string) : bool =
    let
      val t = trim line
      val body = String.extract (t, 1, NONE)
      (* a command's name is ASCII *)
      val name = Substring.string (Substring.takel (fn c => Ident.isStartAscii c orelse c = #"-") (Substring.full body))
      val rest = trim (String.extract (body, String.size name, NONE))
    in
      (#run (find name) rest; true)
      handle Fail msg => (complain (paint "error" "error:" ^ " " ^ msg); false)
           | Error.CompileError (sp, msg) => (ReplLoop.report (sp, msg); false)
           | ReplSession.Reported => false
           | IO.Io {name, function, ...} => (complain (function ^ " " ^ name ^ ": cannot"); false)
           | OS.SysErr (msg, _) => (complain msg; false)
    end

  fun mustHave (what : string, s : string) = if s = "" then raise Fail ("which " ^ what ^ "?") else s

  val () =
    table :=
      [{name = "help", args = "[command]", help = "these commands, or one", run = fn a => say (help a)},
       {name = "quit", args = "", help = "end the session (as Ctrl-D on an empty entry)",
        run = fn _ => OS.Process.exit OS.Process.success},
       {name = "type", args = "exp", help = "the type of an expression, not evaluated",
        run = fn a => let val ty = typeOf (mustHave ("expression", a))
                      in say (code (a, ReplHighlight.code) ^ " : " ^ code (ty, ReplHighlight.aType) ^ "\n") end},
       {name = "info", args = "name", help = "what a name is, and where it was defined",
        run = fn a => say (code (info (mustHave ("name", a)), ReplHighlight.code))},
       {name = "browse", args = "structure", help = "a structure's or a signature's specifications",
        run = fn a => say (code (browse (mustHave ("structure", a)), ReplHighlight.code))},
       {name = "doc", args = "name", help = "the documentation of a name of the Basis Library",
        run = fn a => say (ReplDoc.doc (env (), mustHave ("name", a)))},
       {name = "search", args = "text or type", help = "names that contain the text, or values whose type is like it",
        run = fn a => say (ReplSearch.search (env (), mustHave ("text", a)))},
       {name = "use", args = "file", help = "use a file (Compiler.use)", run = fn a => ReplLoop.use (mustHave ("file", a))},
       {name = "reload", args = "[!]", help = "use again the files that changed and those that name what they bind; ! from the start",
        run = fn a => case a of "" => ReplLoop.reload () | "!" => ReplLoop.restart ()
                              | _ => raise Fail (":reload or :reload!, not " ^ a)},
       {name = "mark", args = "", help = "where :reload! comes back to from now on",
        run = fn _ => (ReplLoop.mark false; say "marked: :reload! comes back here\n")},
       {name = "edit", args = "[name or file]", help = "$EDITOR at a name's definition or a file, then use it again",
        run = edit},
       {name = "cd", args = "dir", help = "change the directory", run = fn a => OS.FileSys.chDir (mustHave ("directory", a))},
       {name = "pwd", args = "", help = "the directory", run = fn _ => say (OS.FileSys.getDir () ^ "\n")},
       {name = "sh", args = "command", help = "a command of the shell", run = fn a => shell (mustHave ("command", a))},
       {name = "set", args = "setting value", help = "change a setting (:show lists them)",
        run = fn a =>
                case String.tokens Char.isSpace a of
                  n :: _ :: _ => set (n, trim (String.extract (trim a, String.size n + 1, NONE)))
                | _ => raise Fail "which setting, and what to? (:set depth 10)"},
       {name = "show", args = "", help = "the settings", run = fn _ => say (show ())},
       {name = "time", args = "[on or off]", help = "the time and memory each entry takes, compiling apart from running",
        run = fn a => (timing := (case a of "off" => false | "on" => true | _ => not (!timing));
                       say ("time " ^ (if !timing then "on" else "off") ^ "\n"))},
       {name = "history", args = "", help = "the entries of this session (! where one failed)", run = fn _ => say (history ())},
       {name = "save", args = "file", help = "the entries that went well, as a script", run = fn a => save (mustHave ("file", a))},
       {name = "save-image", args = "file", help = "the whole session, as an image runevm --restore starts again",
        run = fn a => saveImage (mustHave ("file", a))},
       {name = "bt", args = "", help = "the frames of a stop, or where the last exception that ended an entry was raised",
        run = fn _ => say (if ReplDebug.isStopped () then ReplDebug.backtrace () else backtrace ())},
       {name = "break", args = "[file:]line | raise [all]",
        help = "stop at a line, or at a raise nothing handles (all: every raise); alone, the breakpoints",
        run = fn a => say (ReplDebug.break a)},
       {name = "delete", args = "n | raise | all", help = "a breakpoint, the stops at a raise, or all of them",
        run = fn a => say (ReplDebug.delete (mustHave ("breakpoint", a)))},
       {name = "step", args = "", help = "at a stop: on to the next line, into what it calls", run = fn _ => ReplDebug.go 1},
       {name = "next", args = "", help = "at a stop: on to the next line of this function, or where it returns",
        run = fn _ => ReplDebug.go 2},
       {name = "finish", args = "", help = "at a stop: on to where this function returns", run = fn _ => ReplDebug.go 3},
       {name = "continue", args = "", help = "at a stop: on, to the next stop", run = fn _ => ReplDebug.go 0},
       {name = "abort", args = "", help = "at a stop: the program interrupted there", run = fn _ => ReplDebug.go 4},
       {name = "frame", args = "[n | up | down]", help = "at a stop: the frame looked at, or another",
        run = fn a => say (ReplDebug.selectFrame a)},
       {name = "locals", args = "", help = "at a stop: the variables of the frame looked at",
        run = fn _ => ReplDebug.showLocals ()}]

  (* the hooks of the session's Repl (lib/basis/repl.sml), and :reload until
     M9 makes it the files' *)
  fun install () : unit =
    (ReplComplete.commands := List.map (fn {name, ...} : command => ":" ^ name) (!table);
     RuneRepl.commandHook := (fn line =>
                                let val t = trim line
                                in if dispatch (if String.isPrefix ":" t then t else ":" ^ t) then ()
                                   else raise Fail ("Repl.command: " ^ t ^ " failed")
                                end);
     RuneRepl.typeOfHook := typeOf;
     RuneRepl.infoHook := info;
     RuneRepl.docHook := (fn n => ReplDoc.doc (env (), n));
     RuneRepl.searchHook := (fn t => ReplSearch.search (env (), t));
     RuneRepl.setHook := set;
     RuneRepl.settingsHook := (fn () => List.map (fn (n, _, get, _) => (n, get ())) settings);
     (* :edit's file used again: the files reload, where it is one of them *)
     ReplLoop.reloadHook := (fn file =>
                               if List.exists (fn {file = f, ...} : ReplLoop.used => f = file) (!ReplLoop.usedFiles)
                               then ReplLoop.reload ()
                               else ReplLoop.use file))
end

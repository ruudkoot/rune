(* The REPL's terminal front (docs/plans/repl.md, M6): how an entry is read
   and how what the REPL says is shown.

   On a terminal that can be edited on, an entry is read with lib/terminal's
   editor: the prompts in the palette's roles, the text coloured as it is
   typed (ReplHighlight), Tab completing from the session (ReplComplete),
   the history shared with every Rune program's (History.defaultFile), and
   Enter submitting only an entry that a `;` ends at the top (ReplScan, D12).
   While what was compiled runs, the terminal is quiet (Terminal.quiet):
   keys typed ahead are neither echoed nor lost, and Ctrl-C is the user's
   interrupt; a program that reads the standard input gets it as at a
   shell, echoed and edited by lines, for that read (D18). Where the
   terminal is known to take them, the prompt and the output are marked for
   it (OSC 133).

   Everywhere else -- a pipe, a file, TERM=dumb, Emacs's comint,
   RUNE_BASIC_REPL, --basic -- the REPL is in its basic mode, a prompt and a
   line at a time, whose transcript is what it always was (D24). *)
structure ReplFront =
struct
  (* ---- the command line (D25) ---- *)

  type options = {quiet : bool, exprs : string list, init : bool, color : Color.choice, basic : bool,
                  files : string list}

  exception Usage of string

  val usage =
    "usage: rune-repl [-q] [-e DECLARATIONS]... [--no-init] [--color=always|never|auto] [--basic] [FILE]...\n\
    \  -q             no banner\n\
    \  -e TEXT        run TEXT's declarations, then end, after the files (a `;` is added where TEXT has none)\n\
    \  --no-init      do not use the init file (~/.config/rune/init.sml)\n\
    \  --color=WHEN   colour the REPL's output and the diagnostics: always, never or auto (on a terminal)\n\
    \  --basic        a prompt and a line at a time, as on a pipe\n\
    \  FILE           used before the first prompt\n"

  fun parseArgs (args : string list) : options =
    let
      fun color w = case Color.choiceNamed w of SOME c => c | NONE => raise Usage ("--color takes always, never or auto, not " ^ w)
      fun go ([], o') = o'
        | go (a :: rest, o' as {quiet, exprs, init, color = c, basic, files}) =
            case a of
              "-q" => go (rest, {quiet = true, exprs = exprs, init = init, color = c, basic = basic, files = files})
            | "--quiet" => go (rest, {quiet = true, exprs = exprs, init = init, color = c, basic = basic, files = files})
            | "-e" =>
                (case rest of
                   e :: rest => go (rest, {quiet = quiet, exprs = exprs @ [e], init = init, color = c, basic = basic, files = files})
                 | [] => raise Usage "-e takes the text to run")
            | "--no-init" => go (rest, {quiet = quiet, exprs = exprs, init = false, color = c, basic = basic, files = files})
            | "--basic" => go (rest, {quiet = quiet, exprs = exprs, init = init, color = c, basic = true, files = files})
            | "--color" =>
                (case rest of
                   w :: rest => go (rest, {quiet = quiet, exprs = exprs, init = init, color = color w, basic = basic, files = files})
                 | [] => raise Usage "--color takes always, never or auto")
            | "--" => {quiet = quiet, exprs = exprs, init = init, color = c, basic = basic, files = files @ rest}
            | _ =>
                if String.isPrefix "--color=" a then
                  go (rest, {quiet = quiet, exprs = exprs, init = init, color = color (String.extract (a, 8, NONE)),
                             basic = basic, files = files})
                else if String.isPrefix "-" a andalso a <> "-" then raise Usage ("unknown option " ^ a)
                else go (rest, {quiet = quiet, exprs = exprs, init = init, color = c, basic = basic, files = files @ [a]})
    in
      go (args, {quiet = false, exprs = [], init = true, color = Color.WhenTerminal, basic = false, files = []})
    end

  fun env (name : string) : string = case OS.Process.getEnv name of SOME v => v | NONE => ""

  (* the init file: $XDG_CONFIG_HOME/rune/init.sml, %APPDATA%\rune\init.sml,
     or ~/.config/rune/init.sml, by the first of those variables set *)
  fun initFile () : string option =
    let
      fun under (d, rest) = if d = "" then NONE else SOME (OS.Path.concat (d, rest))
      val chosen =
        case under (env "XDG_CONFIG_HOME", "rune/init.sml") of
          SOME f => SOME f
        | NONE =>
            case under (env "APPDATA", "rune/init.sml") of
              SOME f => SOME f
            | NONE => under (env "HOME", ".config/rune/init.sml")
    in
      case chosen of
        SOME f => if (OS.FileSys.access (f, [OS.FileSys.A_READ]) handle OS.SysErr _ => false) then SOME f else NONE
      | NONE => NONE
    end

  (* ---- what the REPL shows, in the palette's roles ---- *)

  (* whether entries are read with the editor; else the basic mode *)
  val editing = ref false
  (* whether the terminal takes the marks of OSC 133 *)
  val marking = ref false

  fun paint (role : string) (s : string) : string =
    case !ReplHighlight.theme of NONE => s | SOME t => Color.paintIn t role s

  fun out (s : string) = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)

  (* a mark for the terminal: A before the prompt, C before the output, D
     and the status after it *)
  fun mark (code : string) = if !marking then out ("\027]133;" ^ code ^ "\027\\") else ()

  (* the terminals known to take OSC 133's marks; never under Emacs, a dumb
     terminal or a pipe *)
  fun marksTaken () : bool =
    let
      val tty = (Posix.ProcEnv.isatty Posix.FileSys.stdout) handle _ => false
      val program = env "TERM_PROGRAM"
    in
      tty andalso env "TERM" <> "dumb" andalso env "INSIDE_EMACS" = ""
      andalso (env "WT_SESSION" <> "" orelse program = "vscode" orelse program = "WezTerm"
               orelse program = "iTerm.app" orelse program = "ghostty" orelse env "TERM" = "xterm-kitty")
    end

  (* Where the program left a line unfinished, what the REPL says next goes
     on a line of its own: on a terminal, the mark of a partial line (zsh's
     PROMPT_SP, as the editor draws before its prompt) before the first of
     what the REPL writes after code has run -- a `%` and the line's width
     of blanks, which wrap only where the cursor was not at the start, and
     are taken back there. *)
  val fresh = ref true
  fun freshLine () =
    if !editing andalso not (!fresh) then
      (fresh := true;
       out (paint "repl.partial-line" "%"
            ^ CharVector.tabulate (Int.max (0, (case Terminal.size () of SOME {columns, ...} => columns | NONE => 80) - 1),
                                   fn _ => #" ")
            ^ "\r\027[K"))
    else ()
  (* code is about to run, which may leave a line unfinished *)
  fun running () = fresh := false

  (* ---- documents laid out (D16) ---- *)

  (* the printers' document (Compiler.pretty, Poly/ML's shape) as one of
     lib/pretty: a block indented from the column it begins at, its breaks
     all or none where it is consistent and each as it must where not, and
     its roles (ContextProperty "role") as annotations *)
  fun toDoc (p : RuneCompiler.pretty) : string Pretty.doc =
    case p of
      RuneCompiler.PrettyString s => Pretty.text s
    | RuneCompiler.PrettyStringWithWidth (s, w) => Pretty.sized (s, w)
    | RuneCompiler.PrettyBreak (b, off) => Pretty.break (b, off)
    | RuneCompiler.PrettyLineBreak => Pretty.hardline
    | RuneCompiler.PrettyBlock (indent, consistent, context, items) =>
        let
          (* inconsistent: each break grouped with what follows it to the
             next break, so that it breaks where that does not fit after it
             (Oppen's rule) and what follows is then laid out by itself *)
          fun filled [] = []
            | filled (RuneCompiler.PrettyBreak (b, off) :: rest) =
                let
                  fun upto (acc, []) = (List.rev acc, [])
                    | upto (acc, r as RuneCompiler.PrettyBreak _ :: _) = (List.rev acc, r)
                    | upto (acc, q :: r) = upto (toDoc q :: acc, r)
                  val (segment, rest) = upto ([], rest)
                in Pretty.group (Pretty.concat (Pretty.break (b, off) :: segment)) :: filled rest end
            | filled (q :: rest) = toDoc q :: filled rest
          val docs = if consistent then List.map toDoc items else filled items
          val body = Pretty.align (Pretty.nest indent (Pretty.concat docs))
        in
          List.foldr (fn (RuneCompiler.ContextProperty ("role", r), d) => Pretty.annotate (r, d) | (_, d) => d)
                     (if consistent then Pretty.group body else body) context
        end

  (* how wide what the REPL prints is laid out: the terminal's width where
     entries are edited, else Compiler.lineLength *)
  fun width () : int =
    if !editing then (case Terminal.size () of SOME {columns, ...} => if columns > 1 then columns else 80 | NONE => 80)
    else Int.max (1, !RuneCompiler.lineLength)

  (* a document laid out, in the palette's styles where there are colours,
     its annotations given their roles by roleOf *)
  fun renderAs (roleOf : 'a -> string) (d : 'a Pretty.doc) : string =
    case !ReplHighlight.theme of
      NONE => Pretty.render (width ()) d
    | SOME t =>
        let
          val styles : string list ref = ref []
          fun start a = let val st = Color.sgr (t, roleOf a) in styles := st :: !styles; st end
          fun finish _ =
            case !styles of
              st :: rest => (styles := rest; if st = "" then "" else "\027[0m" ^ String.concat (List.rev rest))
            | [] => ""
        in Pretty.renderWith {width = width (), start = start, finish = finish} d end

  fun render (d : string Pretty.doc) : string = renderAs (fn r => r) d

  (* the echo of a value a declaration bound (RuneCompiler.echoHook): its
     type on the line of the value's end where it fits *)
  fun echo (name : string, shown : RuneCompiler.pretty, ty : string) : unit =
    (freshLine ();
     print (render (Pretty.concat [Pretty.text "val ", Pretty.annotate ("repl.name", Pretty.text name), Pretty.text " = ",
                                   toDoc shown,
                                   Pretty.group (Pretty.nest 2 (Pretty.concat [Pretty.line, Pretty.text ": ",
                                                                               Pretty.annotate ("repl.type", Pretty.text ty)]))])
            ^ "\n"))

  (* ---- the terminal while code runs (D18) ---- *)

  val holding = ref false

  (* the terminal quiet while what was compiled runs *)
  fun hold () =
    if !editing andalso not (!holding) then ((Terminal.quiet (); holding := true) handle OS.SysErr _ => ()) else ()

  fun release () =
    if !holding then ((Terminal.leave (); holding := false) handle OS.SysErr _ => holding := false) else ()

  (* f () with the terminal as at a shell, where it is held quiet: a read of
     the standard input by the program *)
  fun shellLike (f : unit -> 'a) : 'a =
    if not (!holding) then f ()
    else (release (); (f () before hold ()) handle e => (hold (); raise e))

  (* TextIO.stdIn over a reader that reads as at a shell (shellLike); what the
     stream had read ahead is kept in front of it *)
  fun wrapStdIn () : unit =
    let
      val (TextPrimIO.RD {name, chunkSize, readVec, readArr, readVecNB, readArrNB, block, canInput, avail,
                          getPos, setPos, endPos, verifyPos, close, ioDesc}, ahead) =
        TextIO.StreamIO.getReader (TextIO.getInstream TextIO.stdIn)
      val reader =
        TextPrimIO.RD {name = name, chunkSize = chunkSize,
                       readVec = Option.map (fn f => fn n => shellLike (fn () => f n)) readVec,
                       readArr = Option.map (fn f => fn a => shellLike (fn () => f a)) readArr,
                       readVecNB = readVecNB, readArrNB = readArrNB,
                       block = Option.map (fn f => fn () => shellLike f) block, canInput = canInput, avail = avail,
                       getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos, close = close,
                       ioDesc = ioDesc}
    in
      TextIO.setInstream (TextIO.stdIn, TextIO.StreamIO.mkInstream (reader, ahead))
    end

  (* ---- reading an entry with the editor ---- *)

  val history : History.history option ref = ref NONE

  datatype entry = Entry of string | Interrupted | EndOfInput

  (* a command (D15): `:` and a name begin no SML, and take the line *)
  fun isCommand (text : string) : bool =
    let val t = Substring.dropl Char.isSpace (Substring.full text)
    in Substring.size t >= 2 andalso Substring.sub (t, 0) = #":" andalso Char.isAlpha (Substring.sub (t, 1)) end

  fun config (sessionEnv : Env.env, isWhole : string -> bool) : LineEdit.config =
    let val st = ReplHighlight.styleOf
    in
      {prompt = !RuneCompiler.prompt1, continuation = !RuneCompiler.prompt2,
       (* the text as it is at Enter: a string open at its end runs into
          the end of a line *)
       isComplete = fn t => CharVector.all Char.isSpace t orelse isCommand t
                            orelse (ReplScan.complete (ReplScan.ofText (t ^ "\n")) andalso isWhole t),
       complete = ReplComplete.complete sessionEnv,
       hint = fn _ => NONE,
       highlight = ReplHighlight.highlight sessionEnv,
       styles = {prompt = st "repl.prompt", hint = st "repl.hint", menu = st "repl.menu", search = st "repl.search",
                 control = st "syn.error", mark = st "repl.partial-line"},
       bindings = #bindings LineEdit.defaults, escapeTimeout = #escapeTimeout LineEdit.defaults,
       policy = Device.policy (), basic = false}
    end

  (* the next entry, read with the editor; isWhole says whether the parser
     takes a text the scanner says may be whole *)
  fun readEntry (sessionEnv : Env.env, isWhole : string -> bool) : entry =
    (mark "A";
     (case LineEdit.readLine (config (sessionEnv, isWhole), !history) of
        LineEdit.Line t => (holding := false; mark "C"; Entry t)
      | LineEdit.Interrupted => (holding := false; Interrupted)
      | LineEdit.End => (holding := false; EndOfInput))
     handle SML90.Interrupt => (holding := false; Interrupted))

  (* what an entry ended with, for the terminal's mark *)
  fun ended (ok : bool) = mark (if ok then "D;0" else "D;1")

  (* ---- the start ---- *)

  (* start options: the diagnostics and the REPL's output coloured as the
     options say; where entries are edited, the history loaded, the standard
     input wrapped, the marks chosen and the banner shown *)
  fun start ({quiet, color, basic, ...} : options) : unit =
    let
      val () = Diagnostic.install {color = color, full = NONE, json = NONE}
      val () = ReplHighlight.theme := Color.decide (color, Posix.FileSys.stdout)
      val canEdit = not basic andalso not (LineEdit.basic LineEdit.defaults)
    in
      RuneCompiler.echoHook := echo;
      editing := canEdit;
      if not canEdit then ()
      else
        (marking := marksTaken ();
         history := SOME (History.load {file = History.defaultFile (), limit = 1000});
         wrapStdIn ();
         if quiet then () else out (paint "repl.ui" ("Rune " ^ Config.version ^ ". Ctrl-D ends the session.") ^ "\n"))
    end
end

(* The REPL's terminal front (docs/plans/repl.md, M6): how an entry is read
   and how what the REPL says is shown.

   On a terminal that can be edited on, an entry is read with lib/terminal's
   editor: the prompts in the palette's roles, the text coloured as it is
   typed (ReplHighlight), Tab completing from the session (ReplComplete),
   the history shared with every Rune program's (History.defaultFile), and
   Enter submitting only an entry that a `;` ends at the top (ReplScan, D12).
   While a declaration or command runs, the terminal is quiet (Terminal.quiet):
   keys typed ahead are neither echoed nor lost, and Ctrl-C is the user's
   interrupt. The editor goes quiet as soon as a line is accepted
   (LineEdit.keepRaw): putting the terminal back would turn echo on, and
   staying fully raw would take Ctrl-C as a byte. A program
   that reads the standard input gets it as at a shell, echoed and edited
   by lines, for that read (D18). Where the
   terminal is known to take them, the prompt and the output are marked for
   it (OSC 133). The prompt's mark is sent once the editor has the terminal
   raw (LineEdit.beforePrompt): sent earlier, a key typed at the mark is
   echoed, and a return is translated to a newline before the editor sees it.

   Everywhere else -- a pipe, a file, TERM=dumb, Emacs's comint,
   RUNE_BASIC_REPL, --basic -- the REPL is in its basic mode, a prompt and a
   line at a time, whose transcript is what it always was (D24). *)
structure ReplFront =
struct
  (* ---- the command line (D25) ---- *)

  type options = {quiet : bool, exprs : string list, init : bool, color : Color.choice, basic : bool,
                  files : string list, engine : string option, mode : Source.mode}

  exception Usage of string

  val usage =
    "usage: rune-repl [-q] [-e DECLARATIONS]... [--no-init] [--color=always|never|auto] [--basic] [--unicode[=ENC]] [FILE]...\n\
    \       rune-repl --engine | --engine-connect PORT [--no-init] [FILE]...\n\
    \  -q             no banner\n\
    \  -e TEXT        run TEXT's declarations, then end, after the files (a `;` is added where TEXT has none)\n\
    \  --no-init      do not use the init file (~/.config/rune/init.sml)\n\
    \  --color=WHEN   colour the REPL's output and the diagnostics: always, never or auto (on a terminal)\n\
    \  --basic        a prompt and a line at a time, as on a pipe\n\
    \  --unicode[=ENC]  read the files used as Unicode text in the encoding ENC, utf8 (the default) or latin1,\n\
    \                 and what is typed as UTF-8 (docs/units.md, Source modes)\n\
    \  --no-unicode-lints  do not warn of what UTS #39 finds in names and comments\n\
    \  --no-inline-functors  none of the Basis Library's functors and functions marked to be inlined\n\
    \                 across units (docs/build.md)\n\
    \  --engine       the engine, for a front: JSON-RPC on the descriptors 3 and 4 (docs/repl-protocol.md)\n\
    \  --engine-connect PORT  the same on a connection to 127.0.0.1:PORT, its token in RUNE_ENGINE_TOKEN\n\
    \  FILE           used before the first prompt\n"

  fun parseArgs (args : string list) : options =
    let
      val quiet = ref false
      val exprs = ref []
      val init = ref true
      val color = ref Color.WhenTerminal
      val basic = ref false
      val files = ref []
      val engine = ref NONE
      val mode = ref Source.Ascii
      fun colorOf w = case Color.choiceNamed w of SOME c => c | NONE => raise Usage ("--color takes always, never or auto, not " ^ w)
      fun go [] = ()
        | go (a :: rest) =
            case (a, rest) of
              ("-q", _) => (quiet := true; go rest)
            | ("--quiet", _) => (quiet := true; go rest)
            | ("-e", e :: rest) => (exprs := !exprs @ [e]; go rest)
            | ("-e", []) => raise Usage "-e takes the text to run"
            | ("--no-init", _) => (init := false; go rest)
            | ("--basic", _) => (basic := true; go rest)
            | ("--color", w :: rest) => (color := colorOf w; go rest)
            | ("--color", []) => raise Usage "--color takes always, never or auto"
            | ("--engine", _) => (engine := SOME "fds"; go rest)
            | ("--engine-connect", p :: rest) =>
                (case Int.fromString p of
                   SOME _ => (engine := SOME p; go rest)
                 | NONE => raise Usage ("--engine-connect takes a port, not " ^ p))
            | ("--engine-connect", []) => raise Usage "--engine-connect takes a port"
            | ("--", _) => files := !files @ rest
            | _ =>
                if String.isPrefix "--color=" a then (color := colorOf (String.extract (a, 8, NONE)); go rest)
                (* the encoding only after an =, as rune takes it: a word
                   after --unicode is a file *)
                else if a = "--unicode" then (mode := Source.Unicode Source.Utf8; go rest)
                else if a = "--no-unicode-lints" then (Lexer.lints := false; go rest)
                else if a = "--no-inline-functors" then
                  (Elaborate.inlineFunctors := StringMap.empty; Elaborate.inlineValues := StringMap.empty; go rest)
                else if String.isPrefix "--unicode=" a then
                  (case Source.modeNamed (String.extract (a, 2, NONE)) of
                     SOME m => (mode := m; go rest)
                   | NONE => raise Usage ("--unicode=ENC takes utf8 or latin1, not " ^ String.extract (a, 10, NONE)))
                else if String.isPrefix "-" a andalso a <> "-" then raise Usage ("unknown option " ^ a)
                else (files := !files @ [a]; go rest)
    in
      go args;
      {quiet = !quiet, exprs = !exprs, init = !init, color = !color, basic = !basic orelse isSome (!engine),
       files = !files, engine = !engine, mode = !mode}
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

  (* what the REPL says of a value a declaration bound: its type on the
     line of the value's end where it fits; `val` and the type coloured as
     they are where they are typed (ReplHighlight) *)
  fun echoDoc (name : string, shown : RuneCompiler.pretty, ty : string) : string Pretty.doc =
    Pretty.concat [Pretty.annotate ("syn.keyword", Pretty.text "val"), Pretty.text " ",
                   Pretty.annotate ("repl.name", Pretty.text name), Pretty.text " = ",
                   toDoc shown,
                   Pretty.group (Pretty.nest 2 (Pretty.concat [Pretty.line, Pretty.text ": ",
                                                               ReplHighlight.doc (!ReplSession.env, ty, ReplHighlight.aType)]))]

  (* a document as HTML, laid out at the width: its text escaped, its roles
     spans of the palette's classes (Color.cssOf); and the roles it used *)
  fun html (d : string Pretty.doc) : string * string list =
    let
      val used = ref []
      fun escape s = String.translate (fn #"<" => "&lt;" | #">" => "&gt;" | #"&" => "&amp;" | #"\"" => "&quot;"
                                        | c => String.str c) s
      fun piece (Pretty.Text s) = escape s
        | piece (Pretty.Newline i) = "\n" ^ CharVector.tabulate (i, fn _ => #" ")
        | piece (Pretty.Begin r) =
            (used := r :: !used; "<span class=\"rune-" ^ String.translate (fn #"." => "-" | c => String.str c) r ^ "\">")
        | piece Pretty.End = "</span>"
    in (String.concat (List.map piece (Pretty.layout (width ()) d)), !used) end

  (* the echo of a value a declaration bound (RuneCompiler.echoHook) *)
  fun echo (name : string, shown : RuneCompiler.pretty, ty : string) : unit =
    (freshLine (); print (render (echoDoc (name, shown, ty)) ^ "\n"))

  (* ---- the terminal while an entry runs (D18) ---- *)

  val holding = ref false

  (* the terminal quiet while a declaration or command runs *)
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

  (* the editor's keys: Emacs's, or Vi's modes (:set keys) *)
  val keys : LineEdit.keys ref = ref LineEdit.Emacs

  fun config (sessionEnv : Env.env, isWhole : string -> bool) : LineEdit.config =
    let val st = ReplHighlight.styleOf
    in
      {prompt = !RuneCompiler.prompt1, continuation = !RuneCompiler.prompt2,
       (* the text as it is at Enter: a string open at its end runs into
          the end of a line *)
       isComplete = fn t => CharVector.all Char.isSpace t orelse isCommand t
                            orelse (ReplScan.complete (ReplScan.ofText (t ^ "\n")) andalso isWhole t),
       complete = ReplComplete.complete sessionEnv,
       (* what Tab would add, shown faintly at the end (ReplComplete.hinter) *)
       hint = ReplComplete.hinter sessionEnv,
       highlight = ReplHighlight.highlight sessionEnv,
       styles = {prompt = st "repl.prompt", hint = st "repl.hint", menu = st "repl.menu", search = st "repl.search",
                 control = st "syn.error", mark = st "repl.partial-line"},
       bindings = #bindings LineEdit.defaults, escapeTimeout = #escapeTimeout LineEdit.defaults,
       policy = Device.policy (), basic = false, keys = !keys}
    end

  (* the next entry, read with the editor; isWhole says whether the parser
     takes a text the scanner says may be whole. The prompt's mark is
     beforePrompt, sent from the editor once the terminal is raw. *)
  fun readEntry (sessionEnv : Env.env, isWhole : string -> bool) : entry =
    (case LineEdit.readLine (config (sessionEnv, isWhole), !history) of
       LineEdit.Line t =>
         (* keepRaw has already made every accepted line quiet, including
            commands and blanks. Record that ownership so shellLike can
            release it for an external program or a read of standard input. *)
         (holding := true; mark "C"; Entry t)
     | LineEdit.Interrupted => (holding := false; Interrupted)
     | LineEdit.End => (holding := false; EndOfInput))
    handle SML90.Interrupt =>
      (holding := false; (Terminal.leave () handle OS.SysErr _ => ()); Interrupted)

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
        (LineEdit.keepRaw := true;
         marking := marksTaken ();
         LineEdit.beforePrompt := (fn () => mark "A");
         history := SOME (History.load {file = History.defaultFile (), limit = 1000});
         wrapStdIn ();
         if quiet then () else out (paint "repl.ui" ("Rune " ^ Config.version ^ ". Type :help for instructions.") ^ "\n"))
    end
end

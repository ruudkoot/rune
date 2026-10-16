(* The REPL (docs/repl.md; the incremental roadmap's M4 and D12): it reads
   top-level declarations, compiles each with the resident compiler
   (ReplSession), runs it and echoes what it declared, as the Definition's
   Chapter 8 has it:

   * a declaration that does not elaborate is reported, and the session is
     as it was before it;
   * one whose running raises an exception that nothing handles is
     reported too: what it did is done, and it binds nothing;
   * one that completes extends the session, `exp ;` binding `it`.

   A declaration is a unit of its own (docs/units.md), linked into the
   running program by Runtime.link. `use` (Compiler.use) does the same for
   the declarations of a file, and may be called from one of them.

   The user's interrupt is SML90.Interrupt (Runtime.catchInterrupt; D11).
   The REPL's own work -- parsing, compiling, echoing -- runs with the mask
   on, so that an interrupt waits for what the user asked to run, and a
   declaration's running and the wait for a line with it off: an
   interrupt ends the declaration, which is reported and binds nothing, or
   what has been typed of one. *)
structure ReplLoop =
struct
  fun err s =
    (TextIO.flushOut TextIO.stdOut; ReplFront.freshLine (); TextIO.output (TextIO.stdErr, s); TextIO.flushOut TextIO.stdErr)

  (* The frames the last exception that left the code the REPL ran went
     through, innermost first (:bt) *)
  val lastTrace : Runtime.frame list ref = ref []

  (* an error at a place, as the diagnostics show it (Diagnostic, with the
     excerpt where stderr is a terminal); only kept where Error is silent
     (the engine) *)
  fun report (sp : Source.span, msg : string) =
    if !Error.silent then (Error.errors := !Error.errors + 1; Error.note ("error", sp, msg))
    else err (!Error.show ("error", sp, msg) ^ "\n")

  (* what an entry's declarations declared that is not a value, and an
     exception nothing handled: printed, or taken by the engine *)
  val declaredHook : (string list -> unit) ref = ref (fn _ => ())
  val uncaughtHook : (exn -> unit) option ref = ref NONE

  (* An exception that nothing handled, as the REPL says so *)
  fun uncaught e =
    case !uncaughtHook of SOME h => h e | NONE =>
    case e of
      SML90.Interrupt => err (ReplFront.paint "repl.interrupt" "Interrupt" ^ "\n")
    | IO.Io {name, function, cause} =>
        (* what failed, on what and why, as Poly/ML shows the fields *)
        err (ReplFront.paint "repl.exception" "uncaught exception" ^ " Io: " ^ function ^ " " ^ name ^ ": "
             ^ (case cause of OS.SysErr (m, _) => m | c => General.exnMessage c) ^ "\n")
    | _ => err (ReplFront.paint "repl.exception" "uncaught exception" ^ " " ^ General.exnMessage e ^ "\n")

  (* where an uncaught exception was raised, on a terminal: the innermost
     frame of the trace, :bt the rest *)
  fun whereRaised (e : exn) =
    if not (!ReplFront.editing) then ()
    else
      case List.find (fn {file, ...} : Runtime.frame => file <> "") (!lastTrace) of
        SOME {function, file, line, column} =>
          err (ReplFront.paint "repl.ui" ((case e of SML90.Interrupt => "  interrupted in " | _ => "  raised in ")
                                          ^ function ^ " at " ^ file ^ ":" ^ Int.toString line ^ ":"
                                          ^ Int.toString column ^ (if List.length (!lastTrace) > 1 then " (:bt for the rest)" else ""))
               ^ "\n")
      | NONE => ()

  (* f () with the interrupt's mask on, and as it was after, which raises
     an interrupt that waited where the mask was off *)
  fun masked (f : unit -> 'a) : 'a =
    let val was = Runtime.maskInterrupt true
    in (f () before ignore (Runtime.maskInterrupt was)) handle e => (ignore (Runtime.maskInterrupt was); raise e) end

  (* f () with the mask off, where it is on, and on again after: an
     interrupt that waited is raised as it goes *)
  fun unmasked (f : unit -> 'a) : 'a =
    ((ignore (Runtime.maskInterrupt false); f ()) before ignore (Runtime.maskInterrupt true))
    handle e => (ignore (Runtime.maskInterrupt true); raise e)


  (* the entries of the session, the newest first, and whether each went
     well (:history, :save); the file used last (:edit); the commands and
     :reload, which ReplCommands puts here (src/main/repl-main.sml) *)
  val entries : (string * bool) list ref = ref []
  val lastUsed : string option ref = ref NONE
  val commandHook : (string -> bool) ref = ref (fn _ => (err "rune-repl: no commands\n"; false))
  (* the engine's loop (ReplProtocol.start), put here at start too *)
  val engineHook : (string -> unit) ref = ref (fn _ => err "rune-repl: no engine\n")
  val reloadHook : (string -> unit) ref = ref (fn _ => err "rune-repl: no :reload\n")

  (* :time: what an entry took, compiling apart from running *)
  val timing = ref false
  val compiling = ref Time.zeroTime
  val running = ref Time.zeroTime
  fun timed (r : Time.time ref) (f : unit -> 'a) : 'a =
    let val t0 = Time.now ()
    in (f () before r := Time.+ (!r, Time.- (Time.now (), t0)))
       handle e => (r := Time.+ (!r, Time.- (Time.now (), t0)); raise e)
    end

  (* run (), the code the REPL compiled, inside a handler of the REPL's own
     whose raises record the frames they leave (RuneRuntime.raiseMark): what
     escapes run is traced, and what run handles itself costs nothing more *)
  fun runUser (run : unit -> unit) : unit =
    let val prior = ref 0
    in
      lastTrace := [];
      (prior := RuneRuntime.raiseMark ~1; run (); ignore (RuneRuntime.raiseMark (!prior)))
      handle e => (ignore (RuneRuntime.raiseMark (!prior)); lastTrace := RuneRuntime.raiseTrace (); raise e)
    end

  (* What a text is to the parser: declarations, more to read, or an error *)
  datatype parsed = Decs of Ast.dec list * Fixity.env | More | Wrong of Source.span * string

  (* The declarations of a text, if it ends with a `;` that ends one; the
     text is the source name's from its line `line` on. *)
  fun parseAt (name : string, text : string, line : int) : parsed =
    let
      val file = Source.fromStringAt (name, text, line)
      val () = Source.register file
    in
      (let
         val toks = Lexer.tokenize file
         val n = Vector.length toks
         val eof = #2 (Vector.sub (toks, n - 1))
         val ends = n >= 2 andalso #1 (Vector.sub (toks, n - 2)) = Token.SEMI
       in
         if n <= 1 then More
         else
           (let val (decs, fx) = Parser.parseTokensWith (toks, !ReplSession.fixity)
            in if ends then Decs (decs, fx) else More end)
           handle Error.CompileError (sp, msg) => if sp = eof then More else Wrong (sp, msg)
       end)
      handle Error.CompileError (sp, msg) =>
        (* a comment, or a string's gap, the text has not finished yet; a
           string that a line ends in cannot be finished, and is reported at
           once (D12) *)
        if String.isSubstring "unterminated" msg andalso not (String.isSubstring "string literal" msg) then More
        else Wrong (sp, msg)
    end
  fun parse (name : string, text : string) : parsed = parseAt (name, text, 1)

  (* run (decs, name, text, cached, stopping): each declaration of the text
     of source name compiled and run in turn; false at the first that fails,
     where stopping says so. cached is SOME (stem, n, names) where the text
     is a file's, or a part of one (compileReader): stem names the text, n
     is the place of the first declaration in it and names what parsing it
     looked up; its units are then the text's, through the cache
     (ReplSession.compile). Masked but for the running, which may be inside
     another declaration's (a nested use). *)
  fun run (decs : Ast.dec list, name : string, text : string, cached : (string * int * string list) option,
           stopping : bool) : bool =
    runGroups (topdecs decs, name, text, cached, stopping)

  (* The declarations as units: a top-level declaration each -- those to a
     `;` or the end -- where flexible records are settled there, as Poly/ML
     compiles and runs a topdec at once (--flex-records, docs/repl.md);
     else each declaration *)
  and topdecs (decs : Ast.dec list) : Ast.dec list list =
    case !Elaborate.flexRecords of
      Elaborate.FlexTopdec => groupTopdecs decs
    | Elaborate.FlexTopdecMono => groupTopdecs decs
    | _ => List.map (fn d => [d]) decs
  and groupTopdecs decs =
    let
      fun go ([], [], acc) = List.rev acc
        | go ([], cur, acc) = List.rev (List.rev cur :: acc)
        | go (d :: rest, cur, acc) =
            if Parser.endsTopdec (Ast.spanOfDec d) then go (rest, [], List.rev (d :: cur) :: acc)
            else go (rest, d :: cur, acc)
    in go (decs, [], []) end

  and runGroups (groups : Ast.dec list list, name : string, text : string,
                 cached : (string * int * string list) option, stopping : bool) : bool =
    case groups of
      [] => true
    | d :: rest =>
        let
          fun one () =
            let
              (* what was written before reaches the file before what the
                 compile reports *)
              val () = TextIO.flushOut TextIO.stdOut
              (* compiled: an error is the declaration's, or the compiler's own *)
              val compiled =
                SOME (timed compiling (fn () => ReplSession.compile (d, name, text, cached)))
                handle Error.CompileError (sp, msg) => (report (sp, msg); NONE)
                     | ReplSession.Reported => NONE
                     | Error.Bug msg => (err ("rune-repl: " ^ msg ^ "\n"); NONE)
                     | Fail msg => (err ("rune-repl: " ^ msg ^ "\n"); NONE)
            in
              (* run: what it raises is the program's, and use passes it on *)
              case compiled of
                NONE => false
              | SOME {run, delta, declared, bind} =>
                  ((ReplFront.running (); timed running (fn () => unmasked (fn () => runUser run)); ReplFront.freshLine ();
                    ReplSession.env := Env.plus (!ReplSession.env, delta);
                    bind ();
                    (* where its names were bound, for :info and :edit *)
                    (case d of
                       first :: _ =>
                         let val sp = Ast.spanOfDec first
                         in ReplSession.noteDefined (delta, #file sp,
                                                     case Source.findFile (#file sp) of
                                                       SOME f => #1 (Source.lineCol (f, #start sp))
                                                     | NONE => 0)
                         end
                     | [] => ());
                    (* what is not a value, in feedback normal and verbose *)
                    if !RuneCompiler.printDepth > 0 andalso not (!ReplSession.quiet)
                       andalso (!RuneCompiler.feedback = "normal" orelse !RuneCompiler.feedback = "verbose")
                    then (case !uncaughtHook of
                            SOME _ => !declaredHook declared
                          | NONE => (ReplFront.freshLine ();
                                     List.app (fn s => print (ReplHighlight.paint (!ReplSession.env, s, ReplHighlight.code) ^ "\n"))
                                              declared))
                    else ();
                    true)
                   handle e => if stopping then raise e else (uncaught e; whereRaised e; false))
            end
          val ok = masked one
        in
          if ok orelse not stopping
          then runGroups (rest, name, text, Option.map (fn (s, n, ns) => (s, n + 1, ns)) cached, stopping) andalso ok
          else false
        end

  (* Compiler.use: the declarations of a file, the first that does not
     compile ending it, the exception of one that raises going on *)
  (* ---- the files of the session (docs/plans/repl.md, D19 and M9) ----
     Each file used from the top -- at the prompt, by a command, the init
     file, the command line; not by another file, which its user uses again
     -- in the order they were last used, with its text and its time then. *)
  type used = {file : string, text : string, time : Time.time}
  val usedFiles : used list ref = ref []
  val useDepth = ref 0

  fun modTime (file : string) : Time.time = OS.FileSys.modTime file handle OS.SysErr _ => Time.zeroTime

  (* while files are used again by :reload, each keeps its place *)
  val reloading = ref false

  fun noteUsed (file : string, text : string) : unit =
    let val u = {file = file, text = text, time = modTime file}
    in
      if !reloading andalso List.exists (fn {file = f, ...} : used => f = file) (!usedFiles)
      then usedFiles := List.map (fn v => if #file v = file then u else v) (!usedFiles)
      else usedFiles := List.filter (fn {file = f, ...} : used => f <> file) (!usedFiles) @ [u]
    end

  fun use (file : string) : unit =
    let
      val () = lastUsed := SOME file
      (* a file that cannot be read raises IO.Io, as Poly/ML's use does *)
      val text = #text (Source.readFile file)
      val top = !useDepth = 0
      val () = if top then noteUsed (file, text) else ()
      val () = useDepth := !useDepth + 1
      (* compiled, the file's lines are what the session keeps of it *)
      fun done () = (useDepth := !useDepth - 1; Source.keepLines file)
    in
      (* parsed, what the parse looked up recorded: each declaration's
         usages have it (ReplSession.compile) *)
      (case Usage.record (fn () => parse (file, text ^ "\n;")) of
         (Decs (decs, fx), names) =>
           (ReplSession.fixity := fx;
            if run (decs, file, text ^ "\n;", SOME (file, 0, names), true) then ()
            else raise Fail ("use: " ^ file ^ " has errors"))
       | (More, _) => raise Fail ("use: " ^ file ^ " ends in the middle of a declaration")
       | (Wrong e, _) => (report e; raise Fail ("use: " ^ file ^ " has errors")))
      handle e => (done (); raise e);
      done ()
    end

  (* Compiler.compile {read, file, line}: the characters read up to a `;`
     that ends a declaration at the top level, or to the end of read, parsed
     as the text of file from line on; the function that runs its
     declarations as use does, raising Fail where one does not compile. A
     syntax error is reported, and raises Fail, at once.

     A part of a file that is there goes through the cache as use's
     declarations do, its units named by the file and the line it begins
     at, and keyed by its text (ReplSession.compile). Once its declarations
     are compiled, the session keeps the file's lines and not the text. *)
  fun compileReader {read : unit -> char option, file : string, line : int} : unit -> unit =
    let
      fun static msg = (err (msg ^ "\n"); raise Fail ("Static errors in " ^ file))
      fun wrong e = (report e; raise Fail ("Static errors in " ^ file))
      val isFile = (OS.FileSys.access (file, [OS.FileSys.A_READ]) andalso not (OS.FileSys.isDir file))
                   handle OS.SysErr _ => false
      fun run' (decs, fx, text, names) =
        (ReplSession.fixity := fx;
         fn () =>
           let
             val cached = if isFile then SOME (file ^ ":" ^ Int.toString line, 0, names) else NONE
             val ok = run (decs, file, text, cached, true) handle e => (Source.keepLines file; raise e)
           in
             Source.keepLines file;
             if ok then () else raise Fail ("Static errors in " ^ file)
           end)
      fun parsed text = Usage.record (fn () => parseAt (file, text, line))
      (* where a `;` may end a declaration at the top level (ReplScan): only
         there is the text parsed, since a structure has a `;` after most of
         its declarations, and parsing the text at each of them made reading
         one quadratic. Where the scanner is wrong the parse decides. *)
      val scan = ReplScan.new ()
      fun gather (acc : char list) =
        case read () of
          NONE =>
            let val text = String.implode (List.rev acc)
            in
              if CharVector.all Char.isSpace text then (fn () => ())
              else
                case parsed (text ^ "\n;") of
                  (Decs (decs, fx), names) => run' (decs, fx, text ^ "\n;", names)
                | (More, _) => static (file ^ ": the text ends in the middle of a declaration")
                | (Wrong e, _) => wrong e
            end
        | SOME #";" =>
            let
              val () = ReplScan.char (scan, #";")
              val acc = #";" :: acc
            in
              if not (ReplScan.complete scan) then gather acc
              else
                let val text = String.implode (List.rev acc)
                in
                  case parsed text of
                    (Decs (decs, fx), names) => run' (decs, fx, text, names)
                  | (More, _) => gather acc
                  | (Wrong e, _) => wrong e
                end
            end
        | SOME c => (ReplScan.char (scan, c); gather (c :: acc))
    in gather [] end

  (* true where the text was taken -- run, or reported wrong -- and the next
     prompt is the first; whether what it ran all went well beside *)
  (* ---- :reload, :reload! and :mark (D19) ---- *)

  (* what the REPL says, or the engine takes *)
  val sayHook : (string -> unit) option ref = ref NONE
  fun say (s : string) =
    case !sayHook of
      SOME h => h s
    | NONE => (ReplFront.freshLine (); TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)
  fun ui (s : string) = say (ReplFront.paint "repl.ui" s ^ "\n")

  fun hasChanged ({file, text, ...} : used) = (#text (Source.readFile file) <> text) handle IO.Io _ => true

  (* the names a text names: its identifiers, and the first part of each
     long one; NONE where it does not lex *)
  fun namesIn (text : string) : string list option =
    SOME (Vector.foldr (fn ((Token.ID n, _), acc) => n :: acc
                         | ((Token.LONGID (p :: _, _), _), acc) => p :: acc
                         | ((Token.LONGID ([], n), _), acc) => n :: acc
                         | (_, acc) => acc)
                       [] (Lexer.tokenize (Source.fromString ("<reload>", text))))
    handle Error.CompileError _ => NONE

  (* the session's names a file bound at the top *)
  fun boundBy (file : string) : string list =
    StringMap.foldli (fn (k, (f, _), acc) => if f = file then String.extract (k, 2, NONE) :: acc else acc)
                     [] (!ReplSession.defined)

  (* The files to use again: from the first that changed, each that changed
     and each that names what a file used again before it binds, which its
     code holds the old of (the dependency rule of incremental M8, by names) *)
  fun toReload (files : used list) : used list =
    let
      fun go ([], _, acc) = List.rev acc
        | go (u :: rest, names, acc) =
            let
              val again = hasChanged u
                          orelse (case namesIn (#text u) of
                                    SOME ns => List.exists (fn n => List.exists (fn m => m = n) names) ns
                                  | NONE => true)
            in if again then go (rest, boundBy (#file u) @ names, u :: acc) else go (rest, names, acc) end
      fun from [] = []
        | from (u :: rest) = if hasChanged u then go (u :: rest, [], []) else from rest
    in from files end

  (* the values made at the prompt whose types a reload replaced: ghosts,
     which print ?.t and match no value of the new type *)
  fun ghosts () : string list =
    StringMap.foldri
      (fn (k, (f, _), acc) =>
         if String.isPrefix "v " k andalso String.isPrefix "stdIn" f then
           let val n = String.extract (k, 2, NONE)
           in
             case StringMap.find (Env.vals (!ReplSession.env), n) of
               SOME (Env.Val {scheme, ...}) =>
                 let val t = ReplShow.typeIn (!ReplSession.env) scheme
                 in if String.isSubstring "?." t then (n ^ " : " ^ t) :: acc else acc end
             | _ => acc
           end
         else acc)
      [] (!ReplSession.defined)

  fun sorted (names : string list) : string list =
    let fun insert (x, []) = [x] | insert (x, y :: ys) = if x <= y then x :: y :: ys else y :: insert (x, ys)
    in List.foldl insert [] names end

  (* :reload: the files to use again, used again in their places, through
     the cache, so that a declaration that did not change is linked and not
     compiled; what they shadow said before, and the ghosts after *)
  (* the times of the files used whose text is the same taken again: a file
     whose time changed and whose text did not is not a change, at the next
     prompt either (:set watch on) *)
  fun retime () : unit =
    usedFiles := List.map (fn u as {file, text, ...} : used =>
                             if hasChanged u then u else {file = file, text = text, time = modTime file})
                          (!usedFiles)

  fun reload () : unit =
    case toReload (!usedFiles) of
      [] => (retime (); ui "nothing used has changed")
    | again =>
        let val shadowed = sorted (List.concat (List.map (fn {file, ...} => boundBy file) again))
        in
          ui ("using again " ^ String.concatWith ", " (List.map #file again)
              ^ (if List.null shadowed then "" else "; shadowing " ^ String.concatWith " " shadowed));
          reloading := true;
          List.app (fn {file, ...} => use file handle e => uncaught e) again;
          reloading := false;
          retime ();
          case ghosts () of
            [] => ()
          | gs => (ui "made at the prompt, of a type the reload replaced:";
                   List.app (fn g => say ("  " ^ g ^ "\n")) gs)
        end
        handle e => (reloading := false; raise e)

  (* the session to come back to: its start, or a :mark *)
  type mark = {start : UnitBasis.start, env : Env.env, fixity : Fixity.env, defined : (string * int) StringMap.map,
               files : used list, atStart : bool}
  val marked : mark option ref = ref NONE

  fun mark (atStart : bool) : unit =
    marked := SOME {start = UnitBasis.begin (!ReplSession.env, !ReplSession.fixity), env = !ReplSession.env,
                    fixity = !ReplSession.fixity, defined = !ReplSession.defined, files = !usedFiles, atStart = atStart}

  (* :reload!: the session as it was at the mark, and the files used since
     used again, as DrScheme's Run does *)
  fun restart () : unit =
    case !marked of
      NONE => raise Fail "there is no mark to come back to"
    | SOME {start, env, fixity, defined, files, atStart} =>
        let
          val replay = List.filter (fn u => not (List.exists (fn v => #file v = #file u) files)) (!usedFiles)
        in
          UnitBasis.undo start;
          ReplSession.env := env;
          ReplSession.fixity := fixity;
          ReplSession.defined := defined;
          usedFiles := files;
          ReplHighlight.reset ();
          ui ("back to the " ^ (if atStart then "start" else "mark")
              ^ (if List.null replay then "" else "; using " ^ String.concatWith ", " (List.map #file replay)));
          List.app (fn {file, ...} => use file handle e => uncaught e) replay
        end

  (* :set watch on: at each prompt, a file used whose time changed reloads,
     where its text did too; where none did, the times are taken, quietly *)
  val watching = ref false
  fun watch () : unit =
    if !watching andalso List.exists (fn {file, time, ...} : used => modTime file <> time) (!usedFiles)
    then ((case toReload (!usedFiles) of [] => retime () | _ => reload ()) handle e => uncaught e)
    else ()

  (* an entry's source: stdIn in the basic mode, whose transcripts have
     always said so, and stdIn#k for the k-th entry on a terminal, so that a
     trace tells entries apart *)
  val entryCount = ref 0
  (* the engine numbers its entries too, whose traces a front shows *)
  val numbered = ref false
  fun entryName () =
    if !ReplFront.editing orelse !numbered then "stdIn#" ^ Int.toString (!entryCount + 1) else "stdIn"

  (* what :time says of an entry *)
  fun ms (t : Time.time) = Real.fmt (StringCvt.FIX (SOME 1)) (Time.toReal t * 1000.0) ^ " ms"
  fun report' (cpu : Timer.cpu_timer, s0 : Runtime.stats, w0 : Time.time) =
    let
      val s1 = Runtime.stats ()
      val {usr, sys} = Timer.checkCPUTimer cpu
      val kb = (#bytes s1 - #bytes s0) div 1024
    in
      err (ReplFront.paint "repl.timing"
             ("  " ^ ms (Time.- (Time.now (), w0)) ^ " in all: compiling " ^ ms (!compiling) ^ ", running " ^ ms (!running)
              ^ "; " ^ ms (Time.+ (usr, sys)) ^ " of CPU; " ^ Int.toString kb ^ " KB allocated, "
              ^ Int.toString (#collections s1 - #collections s0) ^ " collections") ^ "\n")
    end

  (* an expression entered at a stop of the debugger, evaluated in the
     frame looked at, its variables in scope (ReplDebug): SOME of whether
     it went well, or NONE where the entry is run as any other *)
  val evalHook : (string * string * Ast.dec list -> bool option) ref = ref (fn _ => NONE)

  (* the name of the next entry's source, where a front gives one (the
     Jupyter kernel's debugger names a cell by its file) *)
  val nextName : string option ref = ref NONE

  fun step (text : string, last : bool) : bool * bool =
    if CharVector.all Char.isSpace text then (true, true)
    else if ReplFront.isCommand text then (true, !commandHook text)
    else
      let
        val name = case !nextName of SOME n => (nextName := NONE; n) | NONE => entryName ()
        val () = (compiling := Time.zeroTime; running := Time.zeroTime)
        val w0 = Time.now ()
        val cpu = Timer.startCPUTimer ()
        val s0 = Runtime.stats ()
        val result =
          case parse (name, text) of
            Decs (decs, fx) =>
              (ReplSession.fixity := fx;
               (true, case !evalHook (name, text, decs) of SOME ok => ok | NONE => run (decs, name, text, NONE, false)))
          | More => (last, false)
          | Wrong e => (report e; (true, false))
      in
        if #1 result then
          (entryCount := !entryCount + 1;
           entries := (text, #2 result) :: !entries;
           if !timing then report' (cpu, s0, w0) else ())
        else ();
        result
      end

  (* The basic mode's loop: a prompt, lines until a declaration ends, the
     declarations run; on to the end of the input. The lines are scanned as
     they come (ReplScan), and parsed only where one may end a declaration,
     so that what is pasted costs time in proportion to its length. *)
  fun basicLoop () : unit = basicLoopUntil (fn () => false)
  (* and until done () says so after an entry or a command: the debugger's
     prompt at a stop (ReplDebug) *)
  and basicLoopUntil (done : unit -> bool) : unit =
    let
      fun again () = if done () then () else read ([], ReplScan.new (), !RuneCompiler.prompt1)
      and read (lines : string list, scan : ReplScan.t, prompt : string) =
        ((if null lines then watch () else ());
         print prompt; TextIO.flushOut TextIO.stdOut;
         (* the wait with the mask off: an interrupt drops what has been
            typed of the declaration *)
         case SOME (unmasked (fn () => TextIO.inputLine TextIO.stdIn)) handle SML90.Interrupt => NONE of
           NONE => (print "\n"; uncaught SML90.Interrupt; read ([], ReplScan.new (), !RuneCompiler.prompt1))
         | SOME NONE => if null lines then print "\n" else ignore (step (String.concat (List.rev lines) ^ "\n;", true))
         | SOME (SOME line) =>
             if null lines andalso ReplFront.isCommand line then
               (ignore (!commandHook line); again ())
             else
             let
               val () = ReplScan.string (scan, line)
               val lines = line :: lines
             in
               if ReplScan.complete scan andalso #1 (step (String.concat (List.rev lines), false))
               then again ()
               else read (lines, scan, !RuneCompiler.prompt2)
             end)
    in
      read ([], ReplScan.new (), !RuneCompiler.prompt1)
    end

  (* whether the parser takes a text as whole: what the editor asks at
     Enter, once the scanner says it may be *)
  fun isWhole (text : string) : bool =
    case parse ("stdIn", text) of More => false | _ => true

  (* The loop on the editor (ReplFront): an entry at a time, run with the
     terminal held quiet; ended at Ctrl-D on an empty entry *)
  fun editorLoop () : unit = editorLoopUntil (fn () => false)
  and editorLoopUntil (done : unit -> bool) : unit =
    (watch ();
    case unmasked (fn () => ReplFront.readEntry (!ReplSession.env, isWhole)) handle SML90.Interrupt => ReplFront.Interrupted of
      ReplFront.EndOfInput => ()
    | ReplFront.Interrupted => editorLoopUntil done
    | ReplFront.Entry text =>
        (if CharVector.all Char.isSpace text then ()
         else
           let
             val () = if ReplFront.isCommand text then () else ReplFront.hold ()
             val (_, ok) = step (text, true)
           in
             ReplComplete.noteUses text;
             ReplHighlight.reset ();
             ReplFront.ended ok
           end;
         if done () then () else editorLoopUntil done))

  fun loop () : unit = if !ReplFront.editing then editorLoop () else basicLoop ()

  (* The loop at a stop of the debugger (ReplDebug): its prompt, the
     terminal as at the prompt, and the interrupt masked but for what runs,
     until done () or the end of the input *)
  fun nested (prompt : string, done : unit -> bool) : unit =
    let
      val (p1, p2) = (!RuneCompiler.prompt1, !RuneCompiler.prompt2)
      val held = !ReplFront.holding
      (* no file reloads while the program is stopped in one *)
      val watched = !watching
      fun restore () =
        (RuneCompiler.prompt1 := p1; RuneCompiler.prompt2 := p2; watching := watched;
         if held then ReplFront.hold () else ())
    in
      watching := false;
      RuneCompiler.prompt1 := prompt;
      RuneCompiler.prompt2 := String.implode (List.map (fn _ => #" ") (String.explode prompt));
      ReplFront.release ();
      (masked (fn () => if !ReplFront.editing then editorLoopUntil done else basicLoopUntil done) before restore ())
      handle e => (restore (); raise e)
    end

  (* The printers of the Basis's exceptions with an argument, as a
     declaration of the session registers its own (ReplShow.echoes) *)
  val basisExceptions =
    "local\n\
    \  fun s d x = RuneShow.string d x\n\
    \  fun sysErr d e = case e of NONE => RuneShow.con0 \"NONE\" \n\
    \                           | SOME c => RuneShow.con1 d (\"SOME\", fn _ => RuneShow.con0 (OS.errorName c))\n\
    \in\n\
    \  val () = RuneShow.addExn (fn d => fn e =>\n\
    \    case e of\n\
    \      Fail m => SOME (RuneShow.con1 d (\"Fail\", fn d => s d m))\n\
    \    | IO.Io {name, function, cause} =>\n\
    \        SOME (RuneShow.con1 d (\"Io\", fn d => RuneShow.record d\n\
    \                [(\"cause\", fn d => RuneShow.exn d cause), (\"function\", fn d => s d function), (\"name\", fn d => s d name)]))\n\
    \    | OS.SysErr (m, c) => SOME (RuneShow.con1 d (\"SysErr\", fn d => RuneShow.tuple d [fn d => s d m, fn d => sysErr d c]))\n\
    \    | _ => NONE)\n\
    \end;"

  (* The lines of a file *)
  fun linesOf (file : string) : string list =
    let val ins = TextIO.openIn file
    in List.filter (fn s => s <> "") (String.fields (fn c => c = #"\n") (TextIO.inputAll ins)) before TextIO.closeIn ins end

  (* main (list :: files): list names the REPL program's unit files, which
     its loader loaded it from (src/repl/load.sml), each by its name in the
     list's directory; the file `sources` beside it names the source of
     each, as the build did; the library is two directories up, as
     rune-repl is laid out (Makefile, bin/rune-repl). The files after the
     list are used before the loop. *)
  fun main (args : string list) : unit =
    let
      val (list, rest) = case args of l :: r => (l, r) | [] => raise ReplSession.Failed "no list of units"
      val dir = OS.Path.dir list
      val units = List.map (fn u => OS.Path.joinDirFile {dir = dir, file = OS.Path.file u}) (linesOf list)
      val sources = linesOf (OS.Path.joinDirFile {dir = dir, file = "sources"})
      val lib = OS.Path.concat (dir, "../../lib")
      (* the options and files given: the init file, the files used, then
         the loop, or the text of -e and the end *)
      fun session args =
        let
          val options as {init, files, exprs, engine, ...} =
            ReplFront.parseArgs args
            handle ReplFront.Usage msg => (err ("rune-repl: " ^ msg ^ "\n" ^ ReplFront.usage); OS.Process.exit OS.Process.failure)
          val () = ReplFront.start options
          (* the files of the REPL's program are the library's: the
             debugger's steps stop only in the session's *)
          val () = RuneRuntime.debugUser ()
          (* where :reload! comes back to, before the init file and the files *)
          val () = mark true
          val () = if init then Option.app (fn f => use f handle e => uncaught e) (ReplFront.initFile ()) else ()
          val () = List.app (fn f => use f handle e => uncaught e) files
        in
          case (engine, exprs) of
            (SOME how, _) => !engineHook how
          | (NONE, []) => loop ()
          | (NONE, _) =>
              let
                fun whole t = if ReplScan.complete (ReplScan.ofText t) then t else t ^ "\n;"
                val ok = List.foldl (fn (t, ok) => #2 (step (whole t, true)) andalso ok) true exprs
              in
                OS.Process.exit (if ok then OS.Process.success else OS.Process.failure)
              end
        end
    in
      (* the interrupt caught and masked from the start: one during the
         start waits for the first prompt *)
      ignore (Runtime.catchInterrupt ());
      ignore (Runtime.maskInterrupt true);
      ReplSession.start {units = units, sources = sources, lib = lib};
      RuneCompiler.useHook := use;
      RuneCompiler.compileHook := compileReader;
      (* the top level's own: use, and the printers of the Basis's
         exceptions that have an argument (RuneShow.addExn), before the
         image is saved *)
      ReplSession.quiet := true;
      List.app (fn text =>
                  case parse ("<repl>", text) of
                    Decs (decs, _) => ignore (run (decs, "<repl>", text, NONE, true))
                  | _ => ())
               ["val use = Compiler.use;", basisExceptions];
      ReplSession.quiet := false;
      (* the Basis's documentation, for :doc, in the image *)
      ReplDoc.load (OS.Path.concat (lib, "../docs/lib/basis/members.json"));
      (* --make-image IMAGE: the REPL as it is now, written to IMAGE; the
         world that writes it stops, and one started from it (runevm
         --restore IMAGE FILE...) goes on here with its own arguments
         (docs/repl.md, How it is built) *)
      case rest of
        ["--make-image", image] =>
          (ignore (Runtime.share ());
           case Runtime.save image of
             Runtime.Saved => ()
           | Runtime.Restored => session (CommandLine.arguments ()))
      | files => session files
    end
    handle ReplSession.Failed msg => (err ("rune-repl: " ^ msg ^ "\n"); OS.Process.exit OS.Process.failure)
end

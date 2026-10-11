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
structure Repl =
struct
  fun err s = (TextIO.flushOut TextIO.stdOut; TextIO.output (TextIO.stdErr, s); TextIO.flushOut TextIO.stdErr)

  (* An exception that nothing handled, as the REPL says so *)
  fun uncaught e =
    case e of
      SML90.Interrupt => err "Interrupt\n"
    | IO.Io {name, function, cause} =>
        (* what failed, on what and why, as Poly/ML shows the fields *)
        err ("uncaught exception Io: " ^ function ^ " " ^ name ^ ": "
             ^ (case cause of OS.SysErr (m, _) => m | c => General.exnMessage c) ^ "\n")
    | _ => err ("uncaught exception " ^ General.exnMessage e ^ "\n")

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

  (* What a text is to the parser: declarations, more to read, or an error *)
  datatype parsed = Decs of Ast.dec list * Fixity.env | More | Wrong of string

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
           handle Error.CompileError (sp, msg) => if sp = eof then More else Wrong (Error.format (sp, msg))
       end)
      handle Error.CompileError (sp, msg) =>
        (* a string or a comment the text has not finished yet *)
        if String.isSubstring "unterminated" msg then More else Wrong (Error.format (sp, msg))
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
              (* compiled: an error is the declaration's, or the compiler's own *)
              val compiled =
                SOME (ReplSession.compile (d, name, text, cached))
                handle Error.CompileError (sp, msg) => (err (Error.format (sp, msg) ^ "\n"); NONE)
                     | Error.Bug msg => (err ("rune-repl: " ^ msg ^ "\n"); NONE)
                     | Fail msg => (err ("rune-repl: " ^ msg ^ "\n"); NONE)
            in
              (* run: what it raises is the program's, and use passes it on *)
              case compiled of
                NONE => false
              | SOME {run, delta, declared, bind} =>
                  ((unmasked run;
                    ReplSession.env := Env.plus (!ReplSession.env, delta);
                    bind ();
                    if !RuneCompiler.printDepth > 0 then List.app (fn s => print (s ^ "\n")) declared else ();
                    true)
                   handle e => if stopping then raise e else (uncaught e; false))
            end
          val ok = masked one
        in
          if ok orelse not stopping
          then runGroups (rest, name, text, Option.map (fn (s, n, ns) => (s, n + 1, ns)) cached, stopping)
          else false
        end

  (* Compiler.use: the declarations of a file, the first that does not
     compile ending it, the exception of one that raises going on *)
  fun use (file : string) : unit =
    let
      (* a file that cannot be read raises IO.Io, as Poly/ML's use does *)
      val text = #text (Source.readFile file)
      (* compiled, the file's lines are what the session keeps of it *)
      fun done () = Source.keepLines file
    in
      (* parsed, what the parse looked up recorded: each declaration's
         usages have it (ReplSession.compile) *)
      (case Usage.record (fn () => parse (file, text ^ "\n;")) of
         (Decs (decs, fx), names) =>
           (ReplSession.fixity := fx;
            if run (decs, file, text ^ "\n;", SOME (file, 0, names), true) then ()
            else raise Fail ("use: " ^ file ^ " has errors"))
       | (More, _) => raise Fail ("use: " ^ file ^ " ends in the middle of a declaration")
       | (Wrong msg, _) => (err (msg ^ "\n"); raise Fail ("use: " ^ file ^ " has errors")))
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
      (* How deep what has been read is in brackets and in let, local,
         struct, sig and abstype ... end, outside strings and comments. A
         `;` at depth 0 may end a declaration at the top level, and only
         there is the text parsed: a structure has a `;` after most of its
         declarations, and parsing the text at each of them made reading
         one quadratic. Where the count is wrong the text is parsed at a
         `;` too many or too few; the parse decides. *)
      val depth = ref 0
      val comment = ref 0
      val inString = ref false
      val escaped = ref false
      val prev = ref #" "
      val word = ref ([] : char list)
      fun endWord () =
        (case String.implode (List.rev (!word)) of
           "let" => depth := !depth + 1
         | "local" => depth := !depth + 1
         | "struct" => depth := !depth + 1
         | "sig" => depth := !depth + 1
         | "abstype" => depth := !depth + 1
         | "end" => depth := !depth - 1
         | _ => ();
         word := [])
      fun scan (c : char) =
        if !comment > 0 then
          if !prev = #"(" andalso c = #"*" then (comment := !comment + 1; prev := #" ")
          else if !prev = #"*" andalso c = #")" then (comment := !comment - 1; prev := #" ")
          else prev := c
        else if !inString then
          if !escaped then escaped := false
          else if c = #"\\" then escaped := true
          else if c = #"\"" then inString := false
          else ()
        else if Char.isAlphaNum c orelse c = #"_" orelse c = #"'" then word := c :: !word
        else
          (if null (!word) then () else endWord ();
           case c of
             #"*" => if !prev = #"(" then (depth := !depth - 1; comment := 1; prev := #" ") else prev := c
           | #"(" => (depth := !depth + 1; prev := c)
           | #"[" => (depth := !depth + 1; prev := c)
           | #"{" => (depth := !depth + 1; prev := c)
           | #")" => (depth := !depth - 1; prev := c)
           | #"]" => (depth := !depth - 1; prev := c)
           | #"}" => (depth := !depth - 1; prev := c)
           | #"\"" => (inString := true; prev := c)
           | _ => prev := c)
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
                | (Wrong msg, _) => static msg
            end
        | SOME #";" =>
            let
              val () = scan #";"
              val acc = #";" :: acc
            in
              if !depth > 0 orelse !comment > 0 orelse !inString then gather acc
              else
                let val text = String.implode (List.rev acc)
                in
                  case parsed text of
                    (Decs (decs, fx), names) => run' (decs, fx, text, names)
                  | (More, _) => gather acc
                  | (Wrong msg, _) => static msg
                end
            end
        | SOME c => (scan c; gather (c :: acc))
    in gather [] end

  (* The loop: a prompt, lines until a declaration ends, the declarations
     run; on to the end of the input *)
  fun loop () : unit =
    let
      fun read (buffer : string, prompt : string) =
        (print prompt; TextIO.flushOut TextIO.stdOut;
         (* the wait with the mask off: an interrupt drops what has been
            typed of the declaration *)
         case SOME (unmasked (fn () => TextIO.inputLine TextIO.stdIn)) handle SML90.Interrupt => NONE of
           NONE => (print "\n"; uncaught SML90.Interrupt; read ("", !RuneCompiler.prompt1))
         | SOME NONE => if buffer = "" then print "\n" else ignore (step (buffer ^ "\n;", true))
         | SOME (SOME line) =>
             let val text = buffer ^ line
             in if step (text, false) then read ("", !RuneCompiler.prompt1) else read (text, !RuneCompiler.prompt2) end)
      (* true where the text was taken -- run, or reported wrong -- and the
         next prompt is the first *)
      and step (text : string, last : bool) : bool =
        case parse ("stdIn", text) of
          Decs (decs, fx) => (ReplSession.fixity := fx; ignore (run (decs, "stdIn", text, NONE, false)); true)
        | More => last
        | Wrong msg => (err (msg ^ "\n"); true)
    in
      read ("", !RuneCompiler.prompt1)
    end

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
      (* the files given used, then the loop *)
      fun session files = (List.app (fn f => use f handle e => uncaught e) files; loop ())
    in
      (* the interrupt caught and masked from the start: one during the
         start waits for the first prompt *)
      ignore (Runtime.catchInterrupt ());
      ignore (Runtime.maskInterrupt true);
      ReplSession.start {units = units, sources = sources, lib = lib};
      RuneCompiler.useHook := use;
      RuneCompiler.compileHook := compileReader;
      (* the top level's own: use *)
      ReplSession.quiet := true;
      (case parse ("<repl>", "val use = Compiler.use;") of
         Decs (decs, _) => ignore (run (decs, "<repl>", "val use = Compiler.use;", NONE, true))
       | _ => ());
      ReplSession.quiet := false;
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

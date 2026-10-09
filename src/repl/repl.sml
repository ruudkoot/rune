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

  (* The declarations of a text, if it ends with a `;` that ends one. *)
  fun parse (name : string, text : string) : parsed =
    let
      val file = Source.fromString (name, text)
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

  (* run decs: each declaration compiled and run in turn; false at the first
     that fails, where stopping says so. Masked but for the running, which
     may be inside another declaration's (a nested use). *)
  fun run (decs : Ast.dec list, stopping : bool) : bool =
    case decs of
      [] => true
    | d :: rest =>
        let
          fun one () =
            let
              (* compiled: an error is the declaration's, or the compiler's own *)
              val compiled =
                SOME (ReplSession.compile [d])
                handle Error.CompileError (sp, msg) => (err (Error.format (sp, msg) ^ "\n"); NONE)
                     | Error.Bug msg => (err ("rune-repl: " ^ msg ^ "\n"); NONE)
                     | Fail msg => (err ("rune-repl: " ^ msg ^ "\n"); NONE)
            in
              (* run: what it raises is the program's, and use passes it on *)
              case compiled of
                NONE => false
              | SOME {run, delta, declared} =>
                  ((unmasked run;
                    ReplSession.env := Env.plus (!ReplSession.env, delta);
                    List.app (fn s => print (s ^ "\n")) declared;
                    true)
                   handle e => if stopping then raise e else (uncaught e; false))
            end
          val ok = masked one
        in
          if ok orelse not stopping then run (rest, stopping) else false
        end

  (* Compiler.use: the declarations of a file, the first that does not
     compile ending it, the exception of one that raises going on *)
  fun use (file : string) : unit =
    let
      val text = #text (Source.readFile file) handle IO.Io _ => raise Fail ("use: cannot read " ^ file)
    in
      case parse (file, text ^ "\n;") of
        Decs (decs, fx) => (ReplSession.fixity := fx;
                            if run (decs, true) then () else raise Fail ("use: " ^ file ^ " has errors"))
      | More => raise Fail ("use: " ^ file ^ " ends in the middle of a declaration")
      | Wrong msg => (err (msg ^ "\n"); raise Fail ("use: " ^ file ^ " has errors"))
    end

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
          Decs (decs, fx) => (ReplSession.fixity := fx; ignore (run (decs, false)); true)
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
      (* the top level's own: use *)
      ReplSession.quiet := true;
      (case parse ("<repl>", "val use = Compiler.use;") of
         Decs (decs, _) => ignore (run (decs, true))
       | _ => ());
      ReplSession.quiet := false;
      (* --make-image IMAGE: the REPL as it is now, written to IMAGE; the
         world that writes it stops, and one started from it (runevm
         --restore IMAGE FILE...) goes on here with its own arguments
         (docs/repl.md, How it is built) *)
      case rest of
        ["--make-image", image] =>
          (case Runtime.save image of
             Runtime.Saved => ()
           | Runtime.Restored => session (CommandLine.arguments ()))
      | files => session files
    end
    handle ReplSession.Failed msg => (err ("rune-repl: " ^ msg ^ "\n"); OS.Process.exit OS.Process.failure)
end

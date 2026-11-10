(* rhc on files of Haskell 98 (the haskell98 roadmap's M11, M12): it reads
   a file through the syntax of lib/language/haskell and prints it or a
   view of it, which the round trips of tests/runner/hsroundtrip.sml drive;
   or it reads a program, the file and the modules it imports, through
   names and fixity (RhcGraph, RhcNames), and goes no further yet.

     rhc --parse-only FILE.hs          read the file, and stop
     rhc --print FILE.hs               every block in braces (HsPrint.explicit)
     rhc --print-layout FILE.hs        every block by layout (HsPrint.implicit)
     rhc --print-exact FILE.hs         the file again, byte for byte (HsPrint.exact)
     rhc --dump-tokens FILE.hs         the tokens of the Report's L, one a line
     rhc --dump-ast [--no-spans] FILE.hs  the tree as text (HsDump)
     rhc --dump-names FILE.hs...       the program's exports, fixities, instances
                                       and errors of names (RhcNames)

   `rhc --typecheck-only FILE.hs` checks the program as far as rhc goes,
   its names and fixity, until the checker lands (M13), so that a program
   they accept is accepted; `rhc FILE.hs -o OUT` checks as much and says it
   can go no further. An error of the program's is a diagnostic,
   `FILE:LINE:COL: error: MESSAGE`, on standard error, each in the order
   of the source, and status 1. The options of names: `--names=least` or
   `greatest` (D29), `--cycle-default=module` or `scc` (D30, which M13
   reads), `--dotted-names` (D35). *)
structure RhcSyntax =
struct
  fun eprint s = TextIO.output (TextIO.stdErr, s)

  datatype mode = ParseOnly | Print | PrintLayout | PrintExact | DumpTokens | DumpAst | DumpNames | Check | Compile

  fun isSource a = String.isSuffix ".hs" a orelse String.isSuffix ".lhs" a

  fun modeOf a =
    case a of
      "--parse-only" => SOME ParseOnly
    | "--print" => SOME Print
    | "--print-layout" => SOME PrintLayout
    | "--print-exact" => SOME PrintExact
    | "--dump-tokens" => SOME DumpTokens
    | "--dump-ast" => SOME DumpAst
    | "--dump-names" => SOME DumpNames
    | _ => NONE

  (* the options of names, which M13 reads too *)
  val fixpoint = ref HsModules.Least
  datatype cycleDefault = PerModule | PerGroup
  val cycleDefault = ref PerModule
  val dotted = ref false

  fun readBytes path =
    let val f = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll f) before BinIO.closeIn f end

  (* a token a line: layout's as the braces and semicolon it stands for, a
     line end in a string's gap as \n *)
  fun tokenLine t =
    String.translate (fn #"\n" => "\\n" | #"\r" => "\\r" | c => str c) (HsToken.show (HsToken.plain t)) ^ "\n"

  fun message (file, span : HsSource.span, msg) =
    case RhcGraph.textOf (#file span) of
      SOME t => HsSource.message (t, span, msg)
    | NONE => (if #file span = "" then file else #file span) ^ ": error: " ^ msg

  (* A program: its diagnostics, the library's aside, in the order of
     its groups and, in a file, of the source. *)
  fun program (mode, files) =
    let
      val g = RhcGraph.load {roots = files, dotted = !dotted}
      val r = RhcNames.run (g, !fixpoint)
      val fileOrder =
        #2 (List.foldl (fn ({file, ...} : RhcGraph.node, (k, m)) => (k + 1, HsStringMap.insert (m, file, k)))
              (0, HsStringMap.empty) (List.concat (#groups g)))
      fun rank ({span, ...} : RhcGraph.diag) = (getOpt (HsStringMap.find (fileOrder, #file span), ~1), #start span)
      fun precedes (a, b) = let val ((f1, s1), (f2, s2)) = (rank a, rank b) in f1 < f2 orelse (f1 = f2 andalso s1 <= s2) end
      fun insert (d, []) = [d]
        | insert (d, x :: xs) = if precedes (d, x) then d :: x :: xs else x :: insert (d, xs)
      val diags = List.foldr insert [] (List.filter (fn d => not (#library d)) (#diags g @ #diags r))
      val root = hd files
      fun report () = List.app (fn {span, msg, ...} => eprint (message (root, span, msg) ^ "\n")) diags
      (* A program's module is Main, and exports main (5): what a compile
         asks, and a check of a file Main.hs or of a module Main. *)
      val main = hd (#roots g)
      val exportsMain =
        List.exists (fn {space = HsModules.Value, name = "main", ...} => true | _ => false)
          (getOpt (HsStringMap.find (#exports r, main), []))
      val mainFile = OS.Path.base (OS.Path.file root) = "Main"
      val mainError =
        if main <> "Main" then
          if mode = Compile orelse mainFile then
            SOME (root ^ ": error: a program's module is `Main`, and " ^ root ^ " holds the module `" ^ main ^ "`")
          else NONE
        else if not exportsMain then SOME (root ^ ": error: the module `Main` does not export `main`, which a program runs (5)")
        else NONE
    in
      case mode of
        DumpNames => (RhcNames.dump (g, r); OS.Process.success)
      | _ =>
          if not (null diags) then (report (); OS.Process.failure)
          else
            case mainError of
              SOME m => (eprint (m ^ "\n"); OS.Process.failure)
            | NONE =>
                if mode = Check then OS.Process.success
                else
                  (eprint (root ^ ": error: rhc reads Haskell no further than its names and fixity yet (the haskell98 " ^
                           "roadmap's M12)\n");
                   OS.Process.failure)
    end
    handle HsSource.Error (span, msg) => (eprint (message (hd files, span, msg) ^ "\n"); OS.Process.failure)

  fun go (mode, spans, file) =
    let
      val bytes = readBytes file
      val text = HsSource.text {file = file, bytes = bytes}
      val lexer = {hierarchical = !dotted}
      val opts : HsParser.options = {lexer = lexer, annotations = HsParser.Full}
      fun tokensOf () =
        HsLexer.tokens (lexer, file, if HsLiterate.isLiterate file then HsLiterate.unlit (file, bytes) else bytes)
    in
      (case mode of
         ParseOnly => (ignore (HsParser.parseFile (opts, file, bytes)); OS.Process.success)
       | Print => (print (HsPrint.explicit (HsParser.parseFile (opts, file, bytes))); OS.Process.success)
       | PrintLayout => (print (HsPrint.implicit (HsParser.parseFile (opts, file, bytes))); OS.Process.success)
       | PrintExact => (print (HsPrint.exact (bytes, HsParser.parseFile (opts, file, bytes))); OS.Process.success)
       | DumpTokens =>
           let val (_, trace) = HsParser.parseTraced (opts, file, tokensOf ())
           in
             List.app (fn HsToken.EOF => () | t => print (tokenLine t)) trace;
             OS.Process.success
           end
       | DumpAst => (print (HsDump.module {spans = spans} (HsParser.parseFile (opts, file, bytes))); OS.Process.success)
       | _ => program (mode, [file]))
      handle HsSource.Error (span, msg) => (eprint (HsSource.message (text, span, msg) ^ "\n"); OS.Process.failure)
    end

  (* `command args` is what rhc does with a command line that names a file
     of Haskell, or asks for one of the commands above; NONE for any other.
     The compiler's own options that a compile of a file may have, `-o`
     and its file, `--target=`, `-O`, `--thunks=`, `--lint`, `--dump-after=`
     and `--pass-stats`, are taken and change nothing yet. *)
  fun command (args : string list) : (unit -> OS.Process.status) option =
    let
      val modes = List.mapPartial modeOf args
      val files = List.filter isSource args
    in
      if null modes andalso null files then NONE
      else
        SOME (fn () =>
          let
            val spans = not (List.exists (fn a => a = "--no-spans") args)
            fun option a =
              case a of
                "--names=least" => (fixpoint := HsModules.Least; true)
              | "--names=greatest" => (fixpoint := HsModules.Greatest; true)
              | "--cycle-default=module" => (cycleDefault := PerModule; true)
              | "--cycle-default=scc" => (cycleDefault := PerGroup; true)
              | "--dotted-names" => (dotted := true; true)
              | _ =>
                  if String.isPrefix "--names=" a then raise RhcOptions.Usage ("--names takes least or greatest: " ^ a)
                  else if String.isPrefix "--cycle-default=" a then
                    raise RhcOptions.Usage ("--cycle-default takes module or scc: " ^ a)
                  else false
            fun known a =
              isSource a orelse isSome (modeOf a) orelse a = "--no-spans" orelse a = "--typecheck-only"
              orelse String.isPrefix "--target=" a orelse String.isPrefix "--lint" a orelse String.isPrefix "-O" a
              orelse String.isPrefix "--thunks=" a orelse String.isPrefix "--dump-after=" a orelse a = "--pass-stats"
              orelse option a
            fun check [] = ()
              | check ("-o" :: _ :: rest) = check rest
              | check (a :: rest) = if known a then check rest else raise RhcOptions.Usage ("unknown option or argument: " ^ a)
            val () = check args
            val mode =
              case modes of
                [] => if List.exists (fn a => a = "--typecheck-only") args then Check else Compile
              | [m] => m
              | _ => raise RhcOptions.Usage
                       "one of --parse-only, --print, --print-layout, --print-exact, --dump-tokens, --dump-ast and --dump-names"
          in
            case (mode, files) of
              (_, []) => raise RhcOptions.Usage "no file of Haskell to read: give FILE.hs"
            | (DumpNames, _) => program (DumpNames, files)
            | (_, [file]) => go (mode, spans, file)
            | _ => raise RhcOptions.Usage "one file of Haskell at a time, the program's Main, but for --dump-names"
          end)
    end
end

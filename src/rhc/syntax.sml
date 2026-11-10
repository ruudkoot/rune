(* rhc on a file of Haskell 98 (the haskell98 roadmap's M11): it reads the
   file through the syntax of lib/language/haskell, and prints it or a view
   of it, which the round trips of tests/runner/hsroundtrip.sml drive; past
   the parser it goes no further yet.

     rhc --parse-only FILE.hs          read the file, and stop
     rhc --print FILE.hs               every block in braces (HsPrint.explicit)
     rhc --print-layout FILE.hs        every block by layout (HsPrint.implicit)
     rhc --print-exact FILE.hs         the file again, byte for byte (HsPrint.exact)
     rhc --dump-tokens FILE.hs         the tokens of the Report's L, one a line
     rhc --dump-ast [--no-spans] FILE.hs  the tree as text (HsDump)

   `rhc --typecheck-only FILE.hs` checks the file as far as rhc goes, its
   parse, until the checker lands (M13), so that a program the parse
   accepts is accepted; `rhc FILE.hs -o OUT` reads the file and says it can
   go no further. An error of the file's is its first diagnostic,
   `FILE:LINE:COL: error: MESSAGE`, on standard error, and status 1. *)
structure RhcSyntax =
struct
  fun eprint s = TextIO.output (TextIO.stdErr, s)

  datatype mode = ParseOnly | Print | PrintLayout | PrintExact | DumpTokens | DumpAst | Compile

  fun isSource a = String.isSuffix ".hs" a orelse String.isSuffix ".lhs" a

  fun modeOf a =
    case a of
      "--parse-only" => SOME ParseOnly
    | "--print" => SOME Print
    | "--print-layout" => SOME PrintLayout
    | "--print-exact" => SOME PrintExact
    | "--dump-tokens" => SOME DumpTokens
    | "--dump-ast" => SOME DumpAst
    | _ => NONE

  fun readBytes path =
    let val f = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll f) before BinIO.closeIn f end

  (* a token a line: layout's as the braces and semicolon it stands for, a
     line end in a string's gap as \n *)
  fun tokenLine t =
    String.translate (fn #"\n" => "\\n" | #"\r" => "\\r" | c => str c) (HsToken.show (HsToken.plain t)) ^ "\n"

  fun go (mode, spans, file) =
    let
      val bytes = readBytes file
      val text = HsSource.text {file = file, bytes = bytes}
      val opts : HsParser.options = {lexer = HsLexer.defaults, annotations = HsParser.Full}
      fun tokensOf () =
        HsLexer.tokens (HsLexer.defaults, file, if HsLiterate.isLiterate file then HsLiterate.unlit (file, bytes) else bytes)
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
       | Compile =>
           (ignore (HsParser.parseFile (opts, file, bytes));
            eprint (file ^ ": error: rhc reads Haskell no further than its parser yet (the haskell98 roadmap's M11)\n");
            OS.Process.failure))
      handle HsSource.Error (span, msg) => (eprint (HsSource.message (text, span, msg) ^ "\n"); OS.Process.failure)
    end

  (* `command args` is what rhc does with a command line that names a file
     of Haskell, or asks for one of the commands above; NONE for any other.
     The compiler's own options that a compile of a file may have, `-o`
     and its file and `--target=`, are taken and change nothing yet;
     `--typecheck-only` checks as far as the parse. *)
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
            fun known a =
              isSource a orelse isSome (modeOf a) orelse a = "--no-spans" orelse a = "--typecheck-only"
              orelse String.isPrefix "--target=" a orelse String.isPrefix "--lint" a
            fun check [] = ()
              | check ("-o" :: _ :: rest) = check rest
              | check (a :: rest) = if known a then check rest else raise RhcOptions.Usage ("unknown option or argument: " ^ a)
            val () = check args
            val mode =
              case modes of
                [] => if List.exists (fn a => a = "--typecheck-only") args then ParseOnly else Compile
              | [m] => m
              | _ => raise RhcOptions.Usage "one of --parse-only, --print, --print-layout, --print-exact, --dump-tokens and --dump-ast"
          in
            case files of
              [file] => go (mode, spans, file)
            | [] => raise RhcOptions.Usage "no file of Haskell to read: give FILE.hs"
            | _ => raise RhcOptions.Usage "one file of Haskell at a time, until modules are read (M12)"
          end)
    end
end

(* The driver of the syntax tests of Haskell 98 (tests/hs/syntax/README.md):
   lexer, layout, parser and printers of lib/language/haskell, over files
   given on the command line or in lists.

     hs-syntax [--hier] check FILE...        parse each; OK, or its first error
     hs-syntax [--hier] roundtrip FILE...    the tree, token and exact round trips of each
     hs-syntax [--hier] explicit FILE        the explicit print
     hs-syntax [--hier] implicit FILE        the implicit print
     hs-syntax [--hier] exact FILE           the exact print
     hs-syntax [--hier] tokens FILE          the tokens of L, a line each
     hs-syntax [--hier] dump FILE            the tree as text, with spans (dump-bare: without)
     hs-syntax generate-files SEED N DIR     N trees of the generator as DIR/gen-K.hs and DIR/gen-K.tree
     hs-syntax [--hier] speed N FILE...      lex and parse every file N times
     hs-syntax cases DIR                     the crafted cases of DIR/cases.tsv
     hs-syntax check-roundtrip FILE...       the round trips, a line FAIL for each that fails
     hs-syntax errors DIR                    the diagnostics of DIR/NAME.hs against DIR/NAME.expected
     hs-syntax generate SEED N DEPTH         N trees of the generator from SEED on, printed and read back

   `--list FILE` stands for the files FILE names, a line each. *)
structure SyntaxDriver =
struct
  structure T = HsToken
  structure P = HsParser

  val hier = ref false

  fun lexOpts () : HsLexer.options = {hierarchical = !hier}
  fun opts a : P.options = {lexer = lexOpts (), annotations = a}

  fun readFile path =
    let
      val f = BinIO.openIn path
      val v = BinIO.inputAll f
    in
      BinIO.closeIn f; Byte.bytesToString v
    end

  fun say s = TextIO.output (TextIO.stdOut, s)

  fun clean s = String.map (fn c => if c = #"\t" orelse c = #"\n" orelse c = #"\r" then #" " else c) s

  fun program (path, bytes) = if HsLiterate.isLiterate path then HsLiterate.unlit (path, bytes) else bytes

  fun tokensOf (path, text) = HsLexer.tokens (lexOpts (), path, text)

  (* the first line of the diagnostic of a failure *)
  fun failure (path, bytes, e) =
    case e of
      HsSource.Error (sp, msg) => HsSource.message (HsSource.text {file = path, bytes = bytes}, sp, msg)
    | IO.Io _ => path ^ ": error: cannot read the file"
    | _ => raise e

  (* ---- the token view of a program ---- *)

  (* Empty items and a trailing comma are all that the source can say and
     the tree does not hold. *)
  fun normalise (ts : T.token list) : T.token list =
    let
      fun semis ([], acc) = List.rev acc
        | semis (T.SEMI :: r, acc) =
            (case (acc, r) of
               ([], _) => semis (r, acc)
             | (T.LBRACE :: _, _) => semis (r, acc)
             | (T.SEMI :: _, _) => semis (r, acc)
             | (_, T.RBRACE :: _) => semis (r, acc)
             | _ => semis (r, T.SEMI :: acc))
        | semis (T.RBRACE :: r, T.SEMI :: acc) = semis (T.RBRACE :: r, acc)
        | semis (t :: r, acc) = semis (r, t :: acc)
      (* `(,)` as the list of an import or of the module's exports, which
         the tree keeps as an empty list, is `()` *)
      fun opens t = case t of T.IMPORT => true | T.MODULE => true | _ => false
      fun word t = case t of T.CONID _ => true | T.QCONID _ => true | T.VARID _ => true | _ => false
      fun lists ([], acc) = List.rev acc
        | lists (t :: r, acc) =
            if opens t then
              let
                fun head (T.LPAREN :: T.COMMA :: T.RPAREN :: rest, acc) = lists (rest, T.RPAREN :: T.LPAREN :: acc)
                  | head (u :: rest, acc) = if word u then head (rest, u :: acc) else lists (u :: rest, acc)
                  | head ([], acc) = lists ([], acc)
              in
                head (r, t :: acc)
              end
            else lists (r, t :: acc)
      fun commas ([], acc) = List.rev acc
        | commas (T.COMMA :: T.RPAREN :: r, p :: acc) =
            (case p of
               T.LPAREN => commas (T.RPAREN :: r, T.COMMA :: p :: acc)
             | T.COMMA => commas (T.RPAREN :: r, T.COMMA :: p :: acc)
             | _ => commas (T.RPAREN :: r, p :: acc))
        | commas (t :: r, acc) = commas (r, t :: acc)
    in
      commas (lists (semis (List.map T.plain ts, []), []), [])
    end

  fun firstDiff (a, b, k) =
    case (a, b) of
      ([], []) => NONE
    | (x :: r, y :: s) => if x = y then firstDiff (r, s, k + 1) else SOME (k, T.show x, T.show y)
    | (x :: _, []) => SOME (k, T.show x, "<end>")
    | ([], y :: _) => SOME (k, "<end>", T.show y)

  (* The round trips of one file: for each print, the tree and the token
     tests; and the exact print. A field says ok, or what differed. *)
  fun roundTrip path =
    let
      val bytes = readFile path
      val text = program (path, bytes)
      val items = tokensOf (path, text)
      val (full, trace) = P.parseTraced (opts P.Full, path, items)
      val tree = P.parse (opts P.Bare, path, items)
      val exact = HsPrint.exact (bytes, full)
      val exactNote =
        if exact = bytes then "exact-ok"
        else
          let
            fun at k = if k < size exact andalso k < size bytes andalso String.sub (exact, k) = String.sub (bytes, k)
                       then at (k + 1) else k
          in
            "exact-DIFF at byte " ^ Int.toString (at 0)
          end
      fun trip (label, printer) =
        let
          val out = printer tree
          val name = path ^ "." ^ label
          val items2 = tokensOf (name, out)
          val (tree2, trace2) = P.parseTraced (opts P.Bare, name, items2)
          val treeNote = if tree = tree2 then "tree-ok" else "tree-DIFF"
          val tokNote =
            case firstDiff (normalise trace, normalise trace2, 0) of
              NONE => "tok-ok"
            | SOME (k, x, y) => "tok-DIFF at " ^ Int.toString k ^ ": " ^ x ^ " / " ^ y
        in
          [label ^ "-" ^ treeNote, label ^ "-" ^ tokNote]
        end
        handle e => [label ^ "-REPARSE " ^ clean (failure (path ^ "." ^ label, printer tree, e))]
    in
      String.concatWith "\t"
        (["OK", path, Int.toString (Vector.length items - 1)]
         @ trip ("explicit", HsPrint.explicit) @ trip ("implicit", HsPrint.implicit) @ [exactNote]) ^ "\n"
    end

  fun check path =
    let
      val bytes = readFile path
      val text = program (path, bytes)
      val items = tokensOf (path, text)
      val _ = P.parse (opts P.Spans, path, items)
    in
      "OK\t" ^ path ^ "\t" ^ Int.toString (Vector.length items - 1) ^ "\n"
    end

  fun guarded f path =
    say (f path)
    handle e => say ("ERR\t" ^ path ^ "\t" ^ clean (failure (path, (readFile path handle _ => ""), e)) ^ "\n")

  fun printWith printer path =
    let
      val bytes = readFile path
      val m = P.parse (opts P.Full, path, tokensOf (path, program (path, bytes)))
    in
      say (printer (bytes, m))
    end

  fun tokens path =
    let
      val bytes = readFile path
      val (_, trace) = P.parseTraced (opts P.Bare, path, tokensOf (path, program (path, bytes)))
    in
      List.app (fn t => say (T.show t ^ "\n")) trace
    end

  (* what `speed` does to each file: lex, or lex and parse with the given
     annotations *)
  val speedWhat : P.annotations option ref = ref (SOME P.Spans)

  fun speed (rounds, paths) =
    let
      val sources = List.mapPartial (fn p => SOME (p, program (p, readFile p)) handle _ => NONE) paths
      val total = ref 0
      fun once (p, s) =
        (let val items = tokensOf (p, s)
         in
           case !speedWhat of
             SOME a => ignore (P.parse (opts a, p, items))
           | NONE => ();
           total := !total + Vector.length items - 1
         end)
        handle HsSource.Error _ => ()
      fun loop 0 = ()
        | loop k = (List.app once sources; loop (k - 1))
    in
      loop rounds;
      say ("tokens\t" ^ Int.toString (!total) ^ "\n")
    end

  (* ---- the crafted cases ---- *)

  (* cases.tsv: a case a line, its name, then `accept` or `reject`, then
     why; the case is DIR/NAME/Main.hs. A case passes when the parser does
     what the line wants. *)
  fun cases dir =
    let
      val lines = String.tokens (fn c => c = #"\n") (readFile (dir ^ "/cases.tsv"))
      val failed = ref 0
      val total = ref 0
      fun one line =
        case String.fields (fn c => c = #"\t") line of
          name :: want :: _ =>
            if name = "case" then ()
            else
              let
                val path = dir ^ "/" ^ name ^ "/Main.hs"
                val got =
                  (ignore (P.parse (opts P.Spans, path, tokensOf (path, readFile path))); "accept")
                  handle HsSource.Error _ => "reject"
                val () = total := !total + 1
                fun roundTripOk () =
                  let
                    val fields = String.fields (fn c => c = #"\t") (roundTrip path)
                    val bad = List.filter (fn t => not (String.isSuffix "-ok" t orelse String.isSuffix "-ok\n" t))
                                (List.drop (fields, 3))
                  in
                    if null bad then ()
                    else (failed := !failed + 1;
                          say ("FAIL cases " ^ name ^ ": its round trips: " ^ String.concatWith "; " (List.map clean bad) ^ "\n"))
                  end
              in
                if got = want then (if got = "accept" then roundTripOk () else ())
                else (failed := !failed + 1; say ("FAIL cases " ^ name ^ ": wanted " ^ want ^ ", got " ^ got ^ "\n"))
              end
        | _ => ()
    in
      List.app one lines;
      say ("cases\t" ^ Int.toString (!total) ^ "\tfailed\t" ^ Int.toString (!failed) ^ "\n")
    end

  fun sort xs =
    let
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if String.<= (x, y) then x :: y :: ys else y :: insert (x, ys)
    in
      List.foldl insert [] xs
    end

  (* ---- the checks of make check, which print a line FAIL for what they find ---- *)

  (* the round trips of each file, a line FAIL for each test it fails *)
  fun checkRoundTrips paths =
    let
      val failed = ref 0
      fun one path =
        let
          val fields = String.fields (fn c => c = #"\t") (roundTrip path)
          val bad =
            case fields of
              "OK" :: _ :: _ :: tests => List.filter (fn t => not (String.isSuffix "-ok" t orelse String.isSuffix "-ok\n" t)) tests
            | _ => ["it does not parse"]
        in
          if null bad then ()
          else (failed := !failed + 1; say ("FAIL roundtrip " ^ path ^ ": " ^ String.concatWith "; " (List.map clean bad) ^ "\n"))
        end
        handle e => (failed := !failed + 1; say ("FAIL roundtrip " ^ path ^ ": " ^ clean (failure (path, "", e)) ^ "\n"))
    in
      List.app one paths;
      say ("roundtrip\t" ^ Int.toString (length paths) ^ "\tfailed\t" ^ Int.toString (!failed) ^ "\n")
    end

  (* Each NAME.hs or NAME.lhs of DIR with NAME.expected: its first error's
     first line contains what NAME.expected says, as tests/errors holds the
     compiler's. *)
  fun errors dir =
    let
      fun entries () =
        let
          val d = OS.FileSys.openDir dir
          fun go acc = case OS.FileSys.readDir d of SOME e => go (e :: acc) | NONE => acc
        in
          sort (go []) before OS.FileSys.closeDir d
        end
      val failed = ref 0
      val total = ref 0
      fun one e =
        if String.isSuffix ".hs" e orelse String.isSuffix ".lhs" e then
          let
            val path = dir ^ "/" ^ e
            val base = String.substring (e, 0, size e - (if String.isSuffix ".hs" e then 3 else 4))
            val want =
              case String.tokens (fn c => c = #"\n") (readFile (dir ^ "/" ^ base ^ ".expected")) of
                l :: _ => l
              | [] => ""
            val got =
              (ignore (P.parseFile (opts P.Spans, e, readFile path)); "accepted")
              handle e' as HsSource.Error _ => failure (e, readFile path, e')
          in
            total := !total + 1;
            if want <> "" andalso String.isSubstring want got then ()
            else (failed := !failed + 1; say ("FAIL errors " ^ path ^ ": wanted " ^ want ^ "; got " ^ got ^ "\n"))
          end
        else ()
    in
      List.app one (entries ());
      say ("errors\t" ^ Int.toString (!total) ^ "\tfailed\t" ^ Int.toString (!failed) ^ "\n")
    end

  (* The syntax generator: `count` trees from `seed` on, each printed both
     ways and read back, a line FAIL for each print whose tree is not the
     one drawn, and for each tree whose two prints' tokens differ. *)
  fun generate (seed, count, depth) =
    let
      val failed = ref 0
      fun one k =
        let
          val m = SyntaxGen.module (seed + k, depth)
          fun back (label, printer) =
            let
              val text = printer m
              val name = "generated-" ^ Int.toString (seed + k) ^ "." ^ label
              val (m2, trace) = P.parseTraced (opts P.Bare, name, tokensOf (name, text))
            in
              if m2 = m then SOME trace
              else
                let val again = HsPrint.explicit m2
                in
                  failed := !failed + 1;
                  say ("FAIL generated " ^ name ^ ": read back as another tree" ^
                       (if again = HsPrint.explicit m then ", which prints the same" else "") ^ ":\n" ^ text ^
                       "-- read back as:\n" ^ again);
                  NONE
                end
            end
            handle e =>
              (failed := !failed + 1;
               say ("FAIL generated " ^ Int.toString (seed + k) ^ "." ^ label ^ ": " ^
                    clean (failure (label, printer m, e)) ^ "\n" ^ printer m);
               NONE)
        in
          case (back ("explicit", HsPrint.explicit), back ("implicit", HsPrint.implicit)) of
            (SOME a, SOME b) =>
              (case firstDiff (normalise a, normalise b, 0) of
                 NONE => ()
               | SOME (i, x, y) =>
                   (failed := !failed + 1;
                    say ("FAIL generated " ^ Int.toString (seed + k) ^ ": the prints' tokens differ at " ^
                         Int.toString i ^ ": " ^ x ^ " / " ^ y ^ "\n")))
          | _ => ()
        end
    in
      List.app one (List.tabulate (count, fn k => k));
      say ("generated\t" ^ Int.toString count ^ "\tfailed\t" ^ Int.toString (!failed) ^ "\n")
    end

  (* `count` trees of the generator from `seed` on, each as DIR/gen-K.hs, its
     explicit print for an even K and its implicit one for an odd, and
     DIR/gen-K.tree, its dump with no spans, for a harness that reads them
     back with another program *)
  fun generateFiles (seed, count, dir) =
    let
      fun put (path, text) = let val f = TextIO.openOut path in TextIO.output (f, text); TextIO.closeOut f end
      fun one k =
        let val m = SyntaxGen.module (seed + k, 3)
        in
          put (dir ^ "/gen-" ^ Int.toString k ^ ".hs", if k mod 2 = 0 then HsPrint.explicit m else HsPrint.implicit m);
          put (dir ^ "/gen-" ^ Int.toString k ^ ".tree", HsDump.module {spans = false} m)
        end
    in
      List.app one (List.tabulate (count, fn k => k))
    end

  fun readList path = String.tokens (fn c => c = #"\n") (readFile path)

  fun files args =
    case args of
      [] => []
    | "--list" :: f :: r => readList f @ files r
    | a :: r => a :: files r

  fun main () =
    let
      fun go args =
        case args of
          "--hier" :: r => (hier := true; go r)
        | "--lex-only" :: r => (speedWhat := NONE; go r)
        | "--full" :: r => (speedWhat := SOME P.Full; go r)
        | "--bare" :: r => (speedWhat := SOME P.Bare; go r)
        | "check" :: r => List.app (guarded check) (files r)
        | "roundtrip" :: r => List.app (guarded roundTrip) (files r)
        | ["explicit", f] => printWith (fn (_, m) => HsPrint.explicit m) f
        | ["implicit", f] => printWith (fn (_, m) => HsPrint.implicit m) f
        | ["exact", f] => printWith HsPrint.exact f
        | ["tokens", f] => tokens f
        | ["dump", f] => printWith (fn (_, m) => HsDump.module {spans = true} m) f
        | ["dump-bare", f] => printWith (fn (_, m) => HsDump.module {spans = false} m) f
        | ["generate-files", a, n, d] => generateFiles (valOf (Int.fromString a), valOf (Int.fromString n), d)
        | "speed" :: n :: r => speed (valOf (Int.fromString n), files r)
        | ["cases", d] => cases d
        | "check-roundtrip" :: r => checkRoundTrips (files r)
        | ["errors", d] => errors d
        | ["generate", a, n, d] => generate (valOf (Int.fromString a), valOf (Int.fromString n), valOf (Int.fromString d))
        | _ => (say "usage: hs-syntax [--hier] check|roundtrip|explicit|implicit|exact|tokens|speed|cases ...\n";
                OS.Process.exit OS.Process.failure)
    in
      go (CommandLine.arguments ())
      handle e as HsSource.Error _ =>
        (say (clean (failure ("", "", e)) ^ "\n"); OS.Process.exit OS.Process.failure)
    end
end

val () = SyntaxDriver.main ()

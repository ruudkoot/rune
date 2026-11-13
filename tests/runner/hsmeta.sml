(* rhc's metamorphic relations (D55; the haskell98 roadmap's *Generators
   and metamorphic relations*; docs/testing.md, rhc's metamorphic
   relations): pairs of programs that must behave alike, each relation citing
   the clauses that say so. No second compiler is needed: rhc compiles both
   programs of a pair, bin/runevm runs both, and their exit and standard
   output must be equal.

   Made from each program of tests/hs/lang, by rhc itself or by an edit of
   its text:
   - braces: the program with every block in explicit braces and
     semicolons, as `bin/rhc --print` writes it (2.7, 9.3; lay.intro.optional);
   - layout: that print printed again by layout, `bin/rhc --print-layout`,
     the way back (the same rows);
   - import: the program with `import Char ()` added after its header, which
     brings in nothing but instances, and Char has none to add (5.3.1;
     mod.imp.list.empty).
   Written by hand, in tests/hs/meta: NAME.hs and NAME.pair.hs, the first
   line of NAME.hs naming the rows (`-- rows: ID ...`), NAME beginning with
   the relation: rename (alpha renaming of bound variables: 3.3, 3.12),
   reorder (the order of declarations: 4.5.1, and of the top level, 5).

   A pair is held while its program's rows are Planned (HsConformance) or
   any row its relation cites is: what rhc cannot yet compile and run is no
   pair. *)
structure HsMeta =
struct
  open Sh

  val mechanical = [("braces", ["lay.intro.optional"]), ("layout", ["lay.intro.optional"]), ("import", ["mod.imp.list.empty"]),
                    ("reorder", ["dec.dep.order", "dec.scope.decls.top"]), ("split", ["mod.flatten"]),
                    ("rename", ["tr.lambda.fresh", "exp.let.lexical"])]

  (* rename: every local name of the program's own module, as rhc's names
     resolve it (bin/rhc --dump-binders: BIND and USE, its renamed name x#k
     and its bytes), renamed at each occurrence to a fresh name of its own
     length, so that the layout is kept; a symbolic one is kept *)
  fun rename (src, text) =
    let
      val out = run ^ "/hs-meta/binders-" ^ OS.Path.base (OS.Path.file src)
      val _ = exec {cmd = [fromRoot "bin/rhc", "--dump-binders", src], dir = NONE, stdin = "", stdout = out, stderr = out ^ ".err",
                    timeout = 300}
      fun edit l =
        case String.fields (fn c => c = #"\t") l of
          [_, name, place] =>
            (case (String.fields (fn c => c = #"#") name, List.rev (String.fields (fn c => c = #":") place)) of
               ([orig, k], range :: _) =>
                 (case String.fields (fn c => c = #"-") range of
                    [a, b] => (case (Int.fromString a, Int.fromString b) of
                                 (SOME a, SOME b) => if size orig > 0 andalso Char.isAlpha (String.sub (orig, 0))
                                                     then SOME (a, b, orig, "", name) else NONE
                               | _ => NONE)
                  | _ => NONE)
             | _ => NONE)
        | _ => NONE
      val all = List.mapPartial edit (lines (read out))
      (* a name is renamed only where every occurrence's span is the name
         itself (or it in backquotes): a span that covers more, as a function
         binding's head does, is left, and with it every occurrence of the name *)
      fun exact (a, b, orig, _, _) = b - a = size orig orelse b - a = size orig + 2
      val inexact = List.map #5 (List.filter (not o exact) all)
      val kept = List.filter (fn e => not (List.exists (fn n => n = #5 e) inexact)) all
      (* each binder's new name is as long as its old one, so that no column
         moves and the layout is the program's (a longer name on a line
         before a do block's first statement moved the block's column:
         lib.io.try_literal); fresh in the whole text, and no keyword; a
         binder for which no such name is found keeps its own *)
      fun idChar c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"
      val used = ref (String.tokens (not o idChar) text
                      @ ["case", "class", "data", "default", "deriving", "do", "else", "if", "import", "in", "infix",
                         "infixl", "infixr", "instance", "let", "module", "newtype", "of", "then", "type", "where",
                         "as", "qualified", "hiding"])
      fun isUsed n = List.exists (fn u => u = n) (!used)
      val letters = "abcdefghijklmnopqrstuvwxyz"
      val tail = letters ^ "0123456789"
      fun fresh orig =
        let
          val n = size orig
          (* orig with its character at i replaced, from the last *)
          fun at (i, cs) = List.map (fn c => String.substring (orig, 0, i) ^ str c ^ String.extract (orig, i + 1, NONE))
                                    (String.explode cs)
          val cands = List.concat (List.tabulate (n, fn j => let val i = n - 1 - j in at (i, if i = 0 then letters else tail) end))
        in
          case List.find (fn c => c <> orig andalso not (isUsed c)) cands of
            SOME c => (used := c :: !used; SOME c)
          | NONE => NONE
        end
      val keys = List.foldl (fn ((_, _, orig, _, key), acc) => if List.exists (fn (k, _) => k = key) acc then acc
                                                               else (key, fresh orig) :: acc) [] kept
      val edits = List.mapPartial (fn (a, b, orig, _, key) =>
                                     case List.find (fn (k, _) => k = key) keys of
                                       SOME (_, SOME new) => SOME (a, b, orig, new)
                                     | _ => NONE) kept
      (* each at its span, where the name stands in it, from the last *)
      fun apply ((a, b, orig, new), t) =
        if b > size t then t
        else case CompilerMutants.places (String.substring (t, a, b - a), orig) of
               i :: _ => String.substring (t, 0, a + i) ^ new ^ String.extract (t, a + i + size orig, NONE)
             | [] => t
      val sorted = List.foldl (fn (e, acc) => let fun ins [] = [e] | ins (x :: xs) = if #1 e > #1 x then e :: x :: xs else x :: ins xs in ins acc end) [] edits
    in List.foldl apply text sorted end

  (* a program's text as its header -- its first lines to the module's
     header and its imports, with their comments and the lines that
     continue them -- and its top-level blocks: runs of lines separated by
     blank lines, each starting at column 1. The header ends at the first
     line of a declaration, and the comment lines right above that line
     (no blank between) are the declaration's, not the header's: a comment
     between the imports and the first declaration, in a block of its own or
     above it, stays below where the header ends (O's case, ruling 63). *)
  fun blocks text =
    let
      val ls = String.fields (fn c => c = #"\n") text
      fun blank l = CharVector.all Char.isSpace l
      fun group ([], cur, acc) = List.rev (if null cur then acc else List.rev cur :: acc)
        | group (l :: rest, cur, acc) =
            if blank l then group (rest, [], if null cur then acc else List.rev cur :: acc) else group (rest, l :: cur, acc)
      fun comment l = String.isPrefix "--" l
      fun headLine l = String.isPrefix "module " l orelse String.isPrefix "import " l
      fun indented l = size l > 0 andalso Char.isSpace (String.sub (l, 0))
      fun count (l, s) = length (CompilerMutants.places (l, s))
      (* the lines before the first declaration: blank, comments (a {- -}
         comment by its nesting), the header's lines and their continuations *)
      fun headOf ([], _, _, acc) = (List.rev acc, [])
        | headOf (l :: rest, depth, cont, acc) =
            if depth > 0 orelse String.isPrefix "{-" l then
              headOf (rest, Int.max (0, depth + count (l, "{-") - count (l, "-}")), cont, l :: acc)
            else if blank l orelse comment l then headOf (rest, depth, cont, l :: acc)
            else if headLine l then headOf (rest, depth, true, l :: acc)
            else if indented l andalso cont then headOf (rest, depth, true, l :: acc)
            else (List.rev acc, l :: rest)
      val (head, body) = headOf (ls, 0, false, [])
      (* the comment lines at the header's end that touch the declaration *)
      fun moveBack (h, b) =
        case List.rev h of
          l :: _ => if comment l andalso not (null b) then moveBack (List.take (h, length h - 1), l :: b) else (h, b)
        | [] => (h, b)
      val (head, body) = moveBack (head, body)
      (* a body's blocks: a blank line ends one only where the next line
         that is not blank starts at column 1, so that a class's, an
         instance's or a where's lines stay together; and blocks that define
         one name, a function's clauses or a signature and its binding, are
         one block, which no relation separates *)
      fun bodyGroups ls =
        let
          fun nextIndented [] = false
            | nextIndented (l :: rest) = if blank l then nextIndented rest else indented l
          fun go ([], cur, acc) = List.rev (if null cur then acc else List.rev cur :: acc)
            | go (l :: rest, cur, acc) =
                if blank l then
                  if not (null cur) andalso nextIndented rest then go (rest, l :: cur, acc)
                  else go (rest, [], if null cur then acc else List.rev cur :: acc)
                else go (rest, l :: cur, acc)
          fun name b = case List.filter (not o comment) b of
                         l :: _ => (case String.tokens Char.isSpace l of w :: _ => SOME w | [] => NONE)
                       | [] => NONE
          fun merge (a :: b :: rest) =
                if isSome (name a) andalso name a = name b then merge ((a @ [""] @ b) :: rest) else a :: merge (b :: rest)
            | merge bs = bs
        in merge (go (ls, [], [])) end
    in (group (head, [], []), bodyGroups body) end
  fun unblocks bs = String.concatWith "\n\n" (List.map (String.concatWith "\n") bs) ^ "\n"
  (* reorder: the top-level blocks in the reverse order *)
  fun reorder text = let val (h, bs) = blocks text in unblocks (h @ List.rev bs) end
  (* split: every block but main's to a module Lib, which Main imports; the
     imports in both; NONE where a default declaration or a qualified Main
     name makes the split change the program *)
  fun split text =
    let
      val (h, bs) = blocks text
      fun first b = case b of l :: _ => l | [] => ""
      fun isMain b = String.isPrefix "main " (first b) orelse String.isPrefix "main=" (first b)
      (* the header's imports, each with the lines that continue it *)
      fun importsOf ([], acc) = List.rev acc
        | importsOf (l :: rest, acc) =
            if String.isPrefix "import " l then
              let fun cont (m :: more, got) = if size m > 0 andalso Char.isSpace (String.sub (m, 0)) then cont (more, m :: got)
                                              else (List.rev got, m :: more)
                    | cont ([], got) = (List.rev got, [])
                  val (more, rest') = cont (rest, [])
              in importsOf (rest', (l :: more) :: acc) end
            else importsOf (rest, acc)
      val imports = importsOf (List.concat h, [])
      val lib = List.filter (not o isMain) bs
      val mainBs = List.filter isMain bs
      fun has s = List.exists (fn b => List.exists (String.isSubstring s) b) bs
    in
      if has "Main." orelse List.exists (fn b => String.isPrefix "default " (first b)) bs orelse null mainBs
         orelse not (List.exists (fn b => String.isPrefix "module Main" (first b) orelse List.exists (String.isPrefix "module Main") b) h)
      then NONE
      else SOME (unblocks (h @ [["import Lib"]] @ mainBs), unblocks ([["module Lib where"]] @ imports @ lib))
    end
  val dir = "tests/hs/meta"

  (* the edit of `import`: the line after the module's header, or the
     first line where there is none *)
  fun addImport text =
    let
      val ls = String.fields (fn c => c = #"\n") text
      fun header l = String.isPrefix "module " l andalso List.exists (fn w => w = "where") (String.tokens Char.isSpace l)
      fun go (_, []) = NONE
        | go (seen, l :: rest) = if header l then SOME (List.rev (l :: seen) @ ["import Char ()"] @ rest) else go (l :: seen, rest)
    in
      String.concatWith "\n" (case go ([], ls) of SOME ls' => ls' | NONE => "import Char ()" :: ls)
    end

  (* the second program of a relation, written into work *)
  fun second (relation, src, work) =
    let
      val b = work ^ "/b.hs"
      fun print (opts, from, to) =
        let val code = exec {cmd = [fromRoot "bin/rhc"] @ opts @ [from], dir = NONE, stdin = "", stdout = to,
                             stderr = work ^ "/print.err", timeout = 120}
        in if code = 0 then NONE else SOME ("bin/rhc " ^ String.concatWith " " opts ^ " failed: " ^ firstNonEmpty (work ^ "/print.err")) end
    in
      case relation of
        "braces" => (case print (["--print"], fromRoot src, b) of NONE => SOME b | SOME why => (say ("FAIL " ^ why ^ "\n"); NONE))
      | "layout" =>
          (case print (["--print"], fromRoot src, work ^ "/braces.hs") of
             SOME why => (say ("FAIL " ^ why ^ "\n"); NONE)
           | NONE => (case print (["--print-layout"], work ^ "/braces.hs", b) of
                        NONE => SOME b
                      | SOME why => (say ("FAIL " ^ why ^ "\n"); NONE)))
      | "import" => (write (b, addImport (read (fromRoot src))); SOME b)
      | "reorder" => (write (b, reorder (read (fromRoot src))); SOME b)
      | "rename" => (write (b, rename (fromRoot src, read (fromRoot src))); SOME b)
      | "split" =>
          (case split (read (fromRoot src)) of
             SOME (m, l) => (mkdirs (work ^ "/split"); write (work ^ "/split/Main.hs", m); write (work ^ "/split/Lib.hs", l);
                             SOME (work ^ "/split/Main.hs"))
           | NONE => (say "PASS not split: a default declaration, a qualified Main name or no main\n"; NONE))
      | _ => (say ("FAIL no relation " ^ relation ^ "\n"); NONE)
    end

  (* a program compiled by rhc and run: its exit and its output, or why not *)
  datatype ran = Ran of int * string | Broke of string
  fun runOne (src, stdin, vmargs, work, tag) =
    let
      (* prog.rbc, as Lang names it, so that getProgName is prog in both *)
      val () = mkdirs (work ^ "/" ^ tag)
      val rbc = work ^ "/" ^ tag ^ "/prog.rbc"
      val err = work ^ "/" ^ tag ^ ".cerr"
      val code = exec {cmd = [fromRoot "bin/rhc", src, "-o", rbc], dir = SOME work, stdin = "", stdout = err, stderr = err, timeout = 600}
    in
      if code <> 0 then Broke ("bin/rhc " ^ src ^ " failed: " ^ firstNonEmpty err)
      else
        let
          val out = work ^ "/" ^ tag ^ ".out"
          val c = exec {cmd = [fromRoot "bin/runevm"] @ vmargs @ [rbc], dir = SOME work, stdin = stdin, stdout = out,
                        stderr = work ^ "/" ^ tag ^ ".err", timeout = 600}
        in Ran (c, read out) end
    end

  fun compare (name, a, b, (stdin, vmargs)) =
    let
      val work = run ^ "/hs-meta/" ^ String.translate (fn #"/" => "_" | c => str c) name
      val () = (rmTree work; mkdirs work)
    in
      case (runOne (a, stdin, vmargs, work, "a"), runOne (b, stdin, vmargs, work, "b")) of
        (Broke why, _) => say ("FAIL " ^ name ^ ": the first program: " ^ why ^ "\n")
      | (_, Broke why) => say ("FAIL " ^ name ^ ": the second program: " ^ why ^ "\n")
      | (Ran (ca, oa), Ran (cb, ob)) =>
          if ca <> cb then say ("FAIL " ^ name ^ ": exit " ^ Int.toString ca ^ " against " ^ Int.toString cb ^ "\n")
          else if oa <> ob then say ("FAIL " ^ name ^ ": the outputs differ (" ^ work ^ "/a.out, b.out)\n")
          else rmTree work
    end

  (* the program's standard input and its VM's options, its .stdin and
     .vmargs (Lang's header) *)
  fun stdinOf src =
    let
      val b = String.substring (src, 0, size src - 3)
      val s = b ^ ".stdin"
    in
      (if exists s then fromRoot s else "",
       if exists (b ^ ".vmargs") then String.tokens Char.isSpace (read (b ^ ".vmargs")) else [])
    end

  fun mechanicalOne (relation, src) () =
    let val work = run ^ "/hs-meta/" ^ relation ^ "-" ^ OS.Path.base (OS.Path.file src) ^ "-made"
    in
      rmTree work; mkdirs work;
      case second (relation, src, work) of
        SOME b => compare (relation ^ "/" ^ src, fromRoot src, b, stdinOf src)
      | NONE => ()
    end
  fun pairOne src () =
    compare ("pair/" ^ src, fromRoot src, fromRoot (String.substring (src, 0, size src - 3) ^ ".pair.hs"), stdinOf src)

  (* the check that runs today, as far as rhc goes: its names on both
     programs. The second resolves as the first: as many scope errors in the
     program's own modules, and Main's exports, fixities and instances the
     same *)
  fun namesOne (relation, src) () =
    let
      val work = run ^ "/hs-meta/names-" ^ relation ^ "-" ^ OS.Path.base (OS.Path.file src)
      val () = (rmTree work; mkdirs work)
      fun names (file, tag) =
        let
          val out = work ^ "/" ^ tag ^ ".names"
          val _ = exec {cmd = [fromRoot "bin/rhc", "--dump-names", file], dir = SOME (OS.Path.dir file), stdin = "", stdout = out,
                        stderr = out, timeout = 300}
          val own = List.filter (fn l => not (String.isSubstring "haskell98:" l)) (lines (read out))
          val errors = length (List.filter (String.isPrefix "ERROR") own)
          (* Main's lines; a split moves its instances and fixities to Lib, so
             Lib's are Main's under another name *)
          fun asMain l = String.concatWith "Main" (String.fields (fn c => c = #"\u0000") (replace (l, "Lib", "\u0000")))
          and replace (l, a, b) =
            let fun go i = if i > size l - size a then String.extract (l, i, NONE)
                           else if String.substring (l, i, size a) = a then b ^ go (i + size a)
                           else String.str (String.sub (l, i)) ^ go (i + 1)
            in go 0 end
          fun kept l = case String.fields (fn c => c = #"\t") l of
                         k :: "Main" :: _ => true
                       | k :: "Lib" :: _ => k <> "EXPORT"
                       | _ => false
          val mains = List.map asMain (List.filter kept own)
        in (errors, sort mains) end
    in
      case second (relation, src, work) of
        NONE => ()
      | SOME b =>
          let val (ea, ma) = names (fromRoot src, "a")
              val (eb, mb) = names (b, "b")
          in
            if ea <> eb then say ("FAIL names/" ^ relation ^ "/" ^ src ^ ": " ^ Int.toString ea ^ " scope errors against " ^ Int.toString eb ^ " (" ^ work ^ ")\n")
            else if ma <> mb then say ("FAIL names/" ^ relation ^ "/" ^ src ^ ": Main's exports, fixities or instances differ (" ^ work ^ ")\n")
            else rmTree work
          end
    end

  (* the relations' own test, with no rhc: texts whose split and reorder
     are known, the header's end among them *)
  fun selfTest () =
    let
      fun check (name, got, want) =
        if got = want then () else say ("FAIL hs-meta-self " ^ name ^ ": got\n" ^ getOpt (got, "NONE") ^ "\nwanted\n" ^ getOpt (want, "NONE") ^ "\n")
      fun splitBoth t = Option.map (fn (a, b) => a ^ "--- Lib\n" ^ b) (split t)
      val commented = String.concatWith "\n"
        ["module Main (main) where", "", "import Char", "", "-- a helper, with its comment", "f :: Int -> Int",
         "f x = x + 1", "", "main :: IO ()", "main = print (f 1)", ""]
      val touching = String.concatWith "\n"
        ["module Main (main) where", "import Char", "-- a helper", "f :: Int -> Int", "f x = x + 1", "",
         "main :: IO ()", "main = print (f 1)", ""]
      val continued = String.concatWith "\n"
        ["-- rows: x", "module Main (main) where", "", "import List (sort,", "             nub)", "{- a block", "   comment -}",
         "", "g :: [Int] -> [Int]", "g = sort . nub", "", "main :: IO ()", "main = print (g [2, 1, 2])", ""]
      val bodies = String.concatWith "\n"
        ["module Main (main) where", "", "class C a where", "  c :: a -> Int", "", "  d :: a -> Int", "  d = c", "",
         "f :: Int -> Int", "", "f 0 = 1", "", "f n = n", "", "main :: IO ()", "main = print (f 2)", ""]
    in
      check ("comment-block", splitBoth commented,
             SOME (String.concatWith "\n" ["module Main (main) where", "", "import Char", "", "import Lib", "",
                                           "main :: IO ()", "main = print (f 1)", "--- Lib",
                                           "module Lib where", "", "import Char", "", "-- a helper, with its comment",
                                           "f :: Int -> Int", "f x = x + 1", ""]));
      check ("comment-touching", splitBoth touching,
             SOME (String.concatWith "\n" ["module Main (main) where", "import Char", "", "import Lib", "",
                                           "main :: IO ()", "main = print (f 1)", "--- Lib",
                                           "module Lib where", "", "import Char", "", "-- a helper",
                                           "f :: Int -> Int", "f x = x + 1", ""]));
      check ("continued-import", splitBoth continued,
             SOME (String.concatWith "\n" ["-- rows: x", "module Main (main) where", "", "import List (sort,",
                                           "             nub)", "{- a block", "   comment -}", "", "import Lib", "",
                                           "main :: IO ()", "main = print (g [2, 1, 2])", "--- Lib",
                                           "module Lib where", "", "import List (sort,", "             nub)", "",
                                           "g :: [Int] -> [Int]", "g = sort . nub", ""]));
      check ("reorder-bodies", SOME (reorder bodies),
             SOME (String.concatWith "\n" ["module Main (main) where", "", "main :: IO ()", "main = print (f 2)", "",
                                           "f :: Int -> Int", "", "f 0 = 1", "", "f n = n", "",
                                           "class C a where", "  c :: a -> Int", "", "  d :: a -> Int", "  d = c", ""]));
      check ("reorder", SOME (reorder commented),
             SOME (String.concatWith "\n" ["module Main (main) where", "", "import Char", "", "main :: IO ()",
                                           "main = print (f 1)", "", "-- a helper, with its comment", "f :: Int -> Int",
                                           "f x = x + 1", ""]))
    end

  fun command args =
    case args of
      ["hs-meta-self"] => SOME selfTest
    | ["hs-meta", relation, src] => SOME (mechanicalOne (relation, src))
    | ["hs-meta-names", relation, src] => SOME (namesOne (relation, src))
    | ["hs-meta-pair", src] => SOME (pairOne src)
    | _ => NONE

  (* ---- the jobs *)
  fun rowsOf file =
    case String.tokens Char.isSpace (case lines (read (fromRoot file)) of l :: _ => l | [] => "") of
      "--" :: "rows:" :: ws => List.filter (fn w => not (String.isPrefix "R" w andalso size w > 1 andalso Char.isDigit (String.sub (w, 1)))
                                                     andalso w <> "deviation") ws
    | _ => []
  fun hold (why, t) = case why of SOME w => Test.pending w t | NONE => t
  fun job (name, args) = Oracles.jobIn ("", name, args, [], 1, 600, 1800)
  val covers = ["covers:tests/hs/lang/*", "covers:tests/hs/meta/*", "covers:lib/language/haskell/*", "covers:src/rhc/*",
                "covers:tests/runner/hsmeta.sml"]
  fun tree () =
    let
      val progs = glob ("tests/hs/lang", ".hs")
      val pairs = List.filter (fn f => not (String.isSuffix ".pair.hs" f)) (glob (dir, ".hs"))
      fun mechOf srcs (relation, rows) =
        List.map (fn src =>
                    let val n = OS.Path.base (OS.Path.file src)
                    in hold (case HsConformance.pendingFile src of SOME w => SOME w | NONE => HsConformance.pendingUntil rows,
                             Test.requires ["rhc"] (job (relation ^ "/" ^ n, ["hs-meta", relation, src])))
                    end) srcs
      val mech = mechOf progs
      fun base src = OS.Path.base (OS.Path.file src)
      (* rhc's names on an even sample, which runs today *)
      fun names relation =
        List.map (fn src => Test.requires ["rhc"] (job ("names/" ^ relation ^ "/" ^ OS.Path.base (OS.Path.file src), ["hs-meta-names", relation, src])))
                 (CompilerMutants.evenSample (progs, 30))
      fun pair src =
        let val n = OS.Path.base (OS.Path.file src)
        in hold (HsConformance.pendingUntil (rowsOf src), Test.requires ["rhc"] (job ("pairs/" ^ n, ["hs-meta-pair", src]))) end
      (* make check's: one mechanical relation (braces) on the sample of
         ruling 47 (HsLang.sampled, never a program of lang-nightly.txt), the
         pairs and one relation of names (reorder); nightly every program in
         every relation (the roadmap's D56, the lead's rulings 45 and 47) *)
      fun inCheck (relation, _) = relation = "braces"
      val (inSample, rest) = List.partition (HsLang.sampled o base) progs
      val checked = List.map (Test.tag "nightly") (List.concat (List.map (mechOf inSample) (List.filter inCheck mechanical)))
                    @ List.map pair pairs @ names "reorder"
                    (* the relations' own texts, with no rhc *)
                    @ [job ("@self", ["hs-meta-self"])]
      val nightly = List.concat (List.map (mechOf rest) (List.filter inCheck mechanical))
                    @ List.concat (List.map mech (List.filter (not o inCheck) mechanical)) @ names "split" @ names "rename"
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.tag "hs" (Test.describe "hs" [Test.describe "meta"
           [Test.tag "check" (Test.describe "" checked), Test.tag "nightly" (Test.describe "" nightly)]]))
        covers
    end
end

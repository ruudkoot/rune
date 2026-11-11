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
     and its bytes), renamed x'k at each occurrence; a symbolic one is kept *)
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
                                                     then SOME (a, b, orig, orig ^ "'" ^ k, name) else NONE
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
      val edits = List.map (fn (a, b, orig, new, _) => (a, b, orig, new))
                    (List.filter (fn e => not (List.exists (fn n => n = #5 e) inexact)) all)
      (* each at its span, where the name stands in it, from the last *)
      fun apply ((a, b, orig, new), t) =
        if b > size t then t
        else case CompilerMutants.places (String.substring (t, a, b - a), orig) of
               i :: _ => String.substring (t, 0, a + i) ^ new ^ String.extract (t, a + i + size orig, NONE)
             | [] => t
      val sorted = List.foldl (fn (e, acc) => let fun ins [] = [e] | ins (x :: xs) = if #1 e > #1 x then e :: x :: xs else x :: ins xs in ins acc end) [] edits
    in List.foldl apply text sorted end

  (* a program's text as its header -- its first lines to the module's
     header and its imports -- and its top-level blocks: runs of lines
     separated by blank lines, each starting at column 1 *)
  fun blocks text =
    let
      val ls = String.fields (fn c => c = #"\n") text
      fun blank l = CharVector.all Char.isSpace l
      fun group ([], cur, acc) = List.rev (if null cur then acc else List.rev cur :: acc)
        | group (l :: rest, cur, acc) =
            if blank l then group (rest, [], if null cur then acc else List.rev cur :: acc) else group (rest, l :: cur, acc)
      val bs = group (ls, [], [])
      fun isHead b = case b of
                       l :: _ => String.isPrefix "--" l orelse String.isPrefix "module " l orelse String.isPrefix "import " l
                     | [] => true
      fun split (h, b :: rest) = if isHead b then split (h @ [b], rest) else (h, b :: rest)
        | split (h, []) = (h, [])
    in split ([], bs) end
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
      val imports = List.filter (fn b => String.isPrefix "import " (first b)) h
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

  fun command args =
    case args of
      ["hs-meta", relation, src] => SOME (mechanicalOne (relation, src))
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
      val nightly = List.concat (List.map (mechOf rest) (List.filter inCheck mechanical))
                    @ List.concat (List.map mech (List.filter (not o inCheck) mechanical)) @ names "split" @ names "rename"
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.tag "hs" (Test.describe "hs" [Test.describe "meta"
           [Test.tag "check" (Test.describe "" checked), Test.tag "nightly" (Test.describe "" nightly)]]))
        covers
    end
end

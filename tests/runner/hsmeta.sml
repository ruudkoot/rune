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

  val mechanical = [("braces", ["lay.intro.optional"]), ("layout", ["lay.intro.optional"]), ("import", ["mod.imp.list.empty"])]
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
      | _ => (say ("FAIL no relation " ^ relation ^ "\n"); NONE)
    end

  (* a program compiled by rhc and run: its exit and its output, or why not *)
  datatype ran = Ran of int * string | Broke of string
  fun runOne (src, stdin, work, tag) =
    let
      val rbc = work ^ "/" ^ tag ^ ".rbc"
      val err = work ^ "/" ^ tag ^ ".cerr"
      val code = exec {cmd = [fromRoot "bin/rhc", src, "-o", rbc], dir = SOME work, stdin = "", stdout = err, stderr = err, timeout = 600}
    in
      if code <> 0 then Broke ("bin/rhc " ^ src ^ " failed: " ^ firstNonEmpty err)
      else
        let
          val out = work ^ "/" ^ tag ^ ".out"
          val c = exec {cmd = [fromRoot "bin/runevm", rbc], dir = SOME work, stdin = stdin, stdout = out,
                        stderr = work ^ "/" ^ tag ^ ".err", timeout = 600}
        in Ran (c, read out) end
    end

  fun compare (name, a, b, stdin) =
    let
      val work = run ^ "/hs-meta/" ^ String.translate (fn #"/" => "_" | c => str c) name
      val () = (rmTree work; mkdirs work)
    in
      case (runOne (a, stdin, work, "a"), runOne (b, stdin, work, "b")) of
        (Broke why, _) => say ("FAIL " ^ name ^ ": the first program: " ^ why ^ "\n")
      | (_, Broke why) => say ("FAIL " ^ name ^ ": the second program: " ^ why ^ "\n")
      | (Ran (ca, oa), Ran (cb, ob)) =>
          if ca <> cb then say ("FAIL " ^ name ^ ": exit " ^ Int.toString ca ^ " against " ^ Int.toString cb ^ "\n")
          else if oa <> ob then say ("FAIL " ^ name ^ ": the outputs differ (" ^ work ^ "/a.out, b.out)\n")
          else rmTree work
    end

  fun stdinOf src =
    let val s = String.substring (src, 0, size src - 3) ^ ".stdin" in if exists s then fromRoot s else "" end

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

  fun command args =
    case args of
      ["hs-meta", relation, src] => SOME (mechanicalOne (relation, src))
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
      fun mech (relation, rows) =
        List.map (fn src =>
                    let val n = OS.Path.base (OS.Path.file src)
                    in hold (case HsConformance.pendingFile src of SOME w => SOME w | NONE => HsConformance.pendingUntil rows,
                             Test.requires ["rhc"] (job (relation ^ "/" ^ n, ["hs-meta", relation, src])))
                    end) progs
      fun pair src =
        let val n = OS.Path.base (OS.Path.file src)
        in hold (HsConformance.pendingUntil (rowsOf src), Test.requires ["rhc"] (job ("pairs/" ^ n, ["hs-meta-pair", src]))) end
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.tag "check" (Test.tag "hs" (Test.describe "hs" [Test.describe "meta"
           (List.concat (List.map mech mechanical) @ List.map pair pairs)])))
        covers
    end
end

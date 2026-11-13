(* rhc's mutants (D55; the haskell98 roadmap's *rhc's mutants*;
   docs/testing.md, rhc's mutants): bugs seeded in rhc's sources, each one
   or more exact edits of a file of rhc.plan, and the jobs of bin/rune-test
   that must fail on the rhc it builds (tests/runner/hsmutants.sml). A job
   named is one that runs: its rows are out of Planned. F's parser mutants
   (tests/runner/hssyntax.sml) are another kind, edits applied in the
   runner's own process to the parser's round trips; these build an rhc of
   their own, as Rune's do (tests/runner/compilermutantlist.sml), and are
   judged by the suites as they run: rhc's lexer, literate reader, layout and
   parser, and since M8 CoreLint, Core's interpreter and Core's text reader,
   whose jobs are hs/core's. *)
structure HsMutantList =
struct
  type mutant = {id : string, stage : string, note : string, edits : CompilerMutantList.edit list, caughtBy : string list}

  val h = "lib/language/haskell/"
  fun one (id, stage, note, file, old, new, caughtBy) : mutant =
    {id = id, stage = stage, note = note, edits = [{file = h ^ file, old = old, new = new}], caughtBy = caughtBy}
  (* one of rhc's own sources, src/rhc *)
  fun rhc (id, stage, note, file, old, new, caughtBy) : mutant =
    {id = id, stage = stage, note = note, edits = [{file = "src/rhc/" ^ file, old = old, new = new}], caughtBy = caughtBy}
  val holes = "hs/units/holes/"

  val mutants : mutant list =
    [one ("HL01", "lexer", "{- inside a block comment no longer nests: the first -} ends it (2.3)",
          "lexer.sml", "col := !col + 2; loop (depth + 1))", "col := !col + 2; loop depth)",
          ["hs/accept/lex.comment.nested"]),
     one ("HL02", "lexer", "=> is no reserved operator: a context is a varsym in a type (2.4)",
          "token.sml", "| \"~\" => SOME TILDE | \"=>\" => SOME DARROW", "| \"~\" => SOME TILDE",
          ["hs/accept/ty.ctx.many"]),
     one ("HL03", "literate", "a program line next to commentary is let through (9.4)",
          "literate.sml", "(if prev = Commentary then", "(if false then",
          ["hs/errors/register/lit.bird.adjacent.after"]),
     one ("HY01", "layout", "a block whose first lexeme is at its enclosing context's column opens, not {} (9.3, L's n > m)",
          "layout.sml", "m :: _ => if n > m then openBlock () else emptyBlock ()",
          "m :: _ => if n >= m then openBlock () else emptyBlock ()",
          ["hs/accept/lay.informal.empty"]),
     one ("HY02", "layout", "an explicit { opens no context of its own: layout goes on inside braces (9.3, Note 3)",
          "layout.sml", "T.LBRACE => ctx := 0 :: !ctx", "T.LBRACE => ()",
          ["hs/accept/lay.note4.allbraces", "hs/accept/mod.structure.braces"]),
     one ("HP01", "parser", "if's branches swapped (3.6)",
          "parser.sml", "mkE s (A.EIf (c, a, b))", "mkE s (A.EIf (c, b, a))",
          ["hs/roundtrip/rhc/accept/exp.if.form.hs"]),
     one ("HP02", "parser", "[e1, e2 .. e3] loses its limit (3.10)",
          "parser.sml", "mkE s (A.EEnum (e1, e2, SOME e3))", "mkE s (A.EEnum (e1, e2, NONE))",
          ["hs/roundtrip/rhc/accept/syn.exp.1_tour.hs"]),
     one ("HP03", "parser", "an as-pattern loses its variable (3.17)",
          "parser.sml", "in mkP s (A.PAs (n, p)) end", "in p end",
          ["hs/roundtrip/rhc/accept/syn.pat.1_tour.hs"]),
     one ("HP04", "parser", "prefix negation dropped (3.4)",
          "parser.sml", "operand2 (A.ENeg :: acc)", "operand2 acc",
          ["hs/roundtrip/rhc/accept/exp.neg.form_positions.hs"]),
     one ("HC01", "CoreLint", "an unbound variable passes the scope rule",
          "corelint.sml", "| NONE => breach (env, \"scope\", \"the variable \" ^ x ^ \" is not bound\"))",
          "| NONE => TEval (litTy (LInt (IntInf.fromInt 0))))",
          ["hs/core/lint-scope"]),
     one ("HC02", "CoreLint", "a Char one past Unicode's range passes the lit rule",
          "corelint.sml", "orelse c > 1114111 then breach", "orelse c > 1114112 then breach",
          ["hs/core/lint-lit"]),
     one ("HI01", "interpreter", "a thunk forced is not updated with its value: it stays a hole, and sharing is lost",
          "coreinterp.sml", "| Update (c, _, _) :: rest => (c := Value v; loop (Return v, rest, depth - 1, steps))",
          "| Update (c, _, _) :: rest => (loop (Return v, rest, depth - 1, steps))",
          ["hs/core/sharing", "hs/core/knot"]),
     one ("HT01", "Core's text", "the escape \\n of a string reads as a space",
          "coretext.sml", "| #\"n\" => (10, i + 1)", "| #\"n\" => (32, i + 1)",
          ["hs/core/text-forms", "hs/core/prims"]),
     one ("HT02", "Core's text", "a keyword is let through where a name is wanted",
          "coretext.sml", "if isKeyword w then fail (l, \"a word of the syntax where a name is wanted: \"",
          "if false then fail (l, \"a word of the syntax where a name is wanted: \"",
          ["hs/core/text-keyword"]),
     one ("HD01", "deriving", "a derived instance's context leaves out its data type's own context (4.3.3)",
          "infer.sml", "simplify (dataCtx @ List.concat", "simplify (List.concat",
          ["hs/types/derive/module"]),
     one ("HD02", "deriving", "a derived instance's context too wide: each parameter's, not the fields' types' (10.1)",
          "infer.sml", "reduce h {cls = cls, ty = f}) fields)", "reduce h {cls = cls, ty = f}) (fields @ List.tabulate (vars, T.TGen)))",
          ["hs/types/derive/module"]),
     (* the roadmap's seeds for types and classes (M16), in F's checker, each
        seen by HsLint's second inference or its replay, as M16's done-when
        asks (H's hs/hslint/dump jobs, which run the checker at level 2) *)
     one ("HK01", "checker", "Rule 1 off: a restricted group's constrained variables are generalised (4.5.5)",
          "infer.sml", "val restricted = List.exists (fn PatB _ => true | _ => false) bs", "val restricted = false",
          ["hs/hslint/dump/restricted", "hs/hslint/dump/simple", "hs/types/defaults/module"]),
     one ("HK02", "checker", "Rule 2 by group: what a group leaves open is defaulted at its end, not the module's (4.5.5, R20)",
          "infer.sml", "      wanted := deferred @ savedW\n    end", "      (defaultAll (deferred, \" by group\"); wanted := savedW)\n    end",
          ["hs/hslint/dump/rule2", "hs/types/rule2/module"]),
     one ("HK03", "checker", "defaulting without a numeric class: an ambiguity of standard classes alone is defaulted (4.3.4, R22)",
          "infer.sml", "if not simple orelse not (List.exists isNumeric classes) orelse not (List.all isStandard classes) then false",
          "if not simple orelse not (List.all isStandard classes) then false",
          ["hs/hslint/dump/ambiguous"]),
     one ("HK04", "checker", "a superclass path wrong: the path to a superclass drops its steps (4.3.1)",
          "classes.sml", "| (d, NONE) => Option.map (fn p => c :: p) (superPath (env, d, s)))",
          "| (d, NONE) => Option.map (fn p => p) (superPath (env, d, s)))",
          ["hs/hslint/dump/dicts"]),
     one ("HK05", "checker", "a method slot swapped: a class's methods reversed, and its dictionary's slots with them (D31)",
          "infer.sml", "methods = List.map #1 methods, kind = kind}", "methods = List.rev (List.map #1 methods), kind = kind}",
          ["hs/hslint/dump/dicts"]),
     one ("HD03", "deriving", "a derived Ord's and Ix's constructor positions are bare literals, which the module's default types",
          "derive.sml",
          "fun tag x =\n        e (A.ESig (e (A.EParen (ecase (x, ListPair.map (fn (c, i) => alt (pany c, int i))\n" ^
          "                                             (constrs, List.tabulate (length constrs, fn i => i))))),\n" ^
          "                   NONE, intType ()))",
          "fun tag x = ecase (x, ListPair.map (fn (c, i) => alt (pany c, int i)) (constrs, List.tabulate (length constrs, fn i => i)))",
          ["hs/types/derive/module"]),
     (* D's seeds of M15 (rhc's desugaring, D34): each caught by
        tests/hs/desugar, the Report's translation run on the interpreter *)
     one ("HM01", "desugaring", "a match's clauses tried last first: the Report's top-to-bottom order reversed (3.17.2, 4.4.3.1)",
          "match.sml", "      case rows of\n        [] => raise Fail \"HsMatch: a match of no clause\"",
          "      case List.rev rows of\n        [] => raise Fail \"HsMatch: a match of no clause\"",
          ["hs/desugar/report/order", "hs/desugar/report/guards", "hs/desugar/report/patterns"]),
     one ("HM02", "desugaring", "~p made strict: an irrefutable pattern matched at once (3.17.2's 4, 3.17.3's rule (d))",
          "match.sml", "    | A.PLazy q =>\n        if lazy q then", "    | A.PLazy q =>\n        if true then",
          ["hs/desugar/report/lazy"]),
     one ("HM03", "desugaring", "a newtype's constructor pattern forces its value (3.17.2's 5, 3.17.3's rules (k), (l))",
          "match.sml",
          "              SOME rep => C.atom (C.cast ((Core.Atom a, t), rep),\n" ^
          "                                  fn occ' => pattern (env, occ', hd ps, success, failure))",
          "              SOME rep => C.atom (C.cast ((Core.Atom a, t), rep),\n" ^
          "                                  fn occ' => C.force ((Core.Atom (#1 occ'), #2 occ'), fn (v, vt) => pattern (env, (Core.Var v, vt), hd ps, success, failure)))",
          ["hs/desugar/report/newtype"]),
     (* E13's holes H1 to H9 (the haskell98 roadmap's section What a cache
        hit must satisfy), each a usage or a key of rhc's units dropped: each
        caught by its case of tests/hs/units/holes, the units' compile
        against the whole one (M21) *)
     one ("HU01", "units", "H1: a name looked up is no read: a name an import comes to give, or to clash with, is not seen (5.5.2)",
          "rename.sml", "case (HsUsage.read (HsUsage.Name {within = !home, space = spaceText space, qual = qual, name = name});",
          "case ((); ", [holes ^ "h1-name"]),
     one ("HU02", "units", "H2: an instance looked up is no read: one absent, then present two imports away, moves no default (4.3.4)",
          "classes.sml", "(HsUsage.read (HsUsage.Instance {cls = cls, tycon = tycon}); M.find (instances, instanceId (cls, tycon)))",
          "(M.find (instances, instanceId (cls, tycon)))", [holes ^ "h2-default", holes ^ "h5-context"]),
     rhc ("HU03", "units", "H3: what a unit sees taken from its entry: a usage stands whatever the units before give now",
          "store.sml", "case List.find (fn (k, v) => current k <> v) usages of", "case List.find (fn (k, v) => false) usages of",
          [holes ^ "h1-name", holes ^ "h2-default"]),
     rhc ("HU04", "units", "H4: a unit's key without its members' texts, the default declaration's among them",
          "driver.sml", "(#id f, #hash f)) found)", "(#id f, \"\")) found)", [holes ^ "h2-default"]),
     one ("HU05", "units", "H5: an instance's fingerprint without its context: a context moved from one variable to another, " ^
                   "naming the same classes, is not seen, and a derived instance keeps the old one",
          "modiface.sml", "context (#ctx i) ^ (if #derived i", "\"\" ^ (if #derived i", [holes ^ "h5-context"]),
     one ("HU06", "units", "H6: an entity's fingerprint without its fixity",
          "modiface.sml", "fun fixOf k = fixityText (M.find (fix, k))", "fun fixOf k = \"\"", [holes ^ "h6-fixity"]),
     one ("HU07", "units", "H7: `module M` in an export list reads none of M's exports: a module that re-exports one stays as it was",
          "modules.sml", "then HsUsage.read (HsUsage.Exports target)", "then ()", [holes ^ "h7-reexport"]),
     rhc ("HU08", "units", "H8: a cycle's key over its first member alone",
          "driver.sml", "(#id f, #hash f)) found)", "(#id f, #hash f)) [hd found])", [holes ^ "h8-cycle"]),
     rhc ("HU09", "units", "H9: the Prelude's names the translations ask for are no reads",
          "names.sml", "HsUsage.read (HsUsage.Standard {space = space, name = name});", "();",
          ["hs/iface/usages/reads"]),
     rhc ("HU10", "units",
          "equivalent: a unit taken keeps its fingerprints without asking whether what they asked of the units before is " ^
          "what it was. Not seen by any program: the fingerprints a unit asked of another are of what its interface mentions, " ^
          "which its compile read, so a usage of it refuses the entry first wherever an answer moved (M21's fingerprint reuse)",
          "driver.sml", "if List.all (fn (k, v) => M.find (prints, k) = v) (#asked kept) then kept else printsFor (modules, prints)",
          "kept", []),
     rhc ("HU11", "units", "H8: a unit's fingerprints module by module, not by recursive group over its members: a type " ^
                   "group that spans a cycle's modules hashed apart, so a client of one of its types does not see an edit " ^
                   "of another",
          "driver.sml", "HsModIface.fingerprints Pickle.hash (mods, external)",
          "List.concat (List.map (fn i => HsModIface.fingerprints Pickle.hash ([i], external)) mods)",
          [holes ^ "h8-group"])]
end

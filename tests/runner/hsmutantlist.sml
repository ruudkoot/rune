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
          "infer.sml", "reduce {cls = cls, ty = f}) fields)", "reduce {cls = cls, ty = f}) (fields @ List.tabulate (vars, T.TGen)))",
          ["hs/types/derive/module"]),
     (* the roadmap's seeds for types and classes (M16), in F's checker: two
        are seen today, Rule 1 off by the checker's own tests (hs/types), Rule
        2 by group by the Rule 2 test; HsLint's jobs see neither, and three
        more seeds (defaulting without a numeric class, a superclass path
        wrong, a method slot swapped) no job sees yet: impl/progress/t.md *)
     one ("HK01", "checker", "Rule 1 off: a restricted group's constrained variables are generalised (4.5.5)",
          "infer.sml", "val restricted = List.exists (fn PatB _ => true | _ => false) bs", "val restricted = false",
          ["hs/types/defaults/module"]),
     one ("HK02", "checker", "Rule 2 by group: what a group leaves open is defaulted at its end, not the module's (4.5.5, R20)",
          "infer.sml", "      wanted := deferred @ savedW\n    end", "      (defaultAll (deferred, \" by group\"); wanted := savedW)\n    end",
          ["hs/hslint/dump/rule2", "hs/types/rule2/module"])]
end

(* rhc's mutants (D55; the haskell98 roadmap's *rhc's mutants*;
   docs/testing.md, rhc's mutants): bugs seeded in rhc's sources, each one
   or more exact edits of a file of rhc.plan, and the jobs of bin/rune-test
   that must fail on the rhc it builds (tests/runner/hsmutants.sml). A job
   named is one that runs: its rows are out of Planned. F's parser mutants
   (tests/runner/hssyntax.sml) are another kind, edits applied in the
   runner's own process to the parser's round trips; these build an rhc of
   their own, as Rune's do (tests/runner/compilermutantlist.sml), and are
   judged by the suites as they run. Core's code has no caller in rhc yet,
   and CoreLint and Core's interpreter are not in the tree: their sites come
   with them. *)
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
          ["hs/roundtrip/rhc/accept/exp.neg.form_positions.hs"])]
end

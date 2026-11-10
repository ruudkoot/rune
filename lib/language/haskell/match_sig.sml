(* Pattern matching in the Report's order (the haskell98 roadmap's M15,
   D34), and decision trees in Sestoft's order as an option.

   The rules of 3.17.3 are taken literally, at `-O0`; the trees are built
   for D34's measurement.

   The Report's order: the clauses one after another, and in each the
   patterns from left to right, each from the outside in (3.17.2). A
   clause that fails goes to the next, which a lazy `let` of the rest of
   the match holds (rule (c)'s `y`), so no clause is copied (defect 14).
   A constructor's pattern forces its value and matches its fields left
   to right (rule (g)); a newtype's casts and forces nothing (rules (k),
   (l)); a numeric literal compares by `==` at its type with the
   dictionaries the checker chose (rule (h)), a character literal by a
   case on its code point, a string literal as the list of its characters
   (defect 7); `~p` binds each variable of `p` to a match of its own that
   is made only when the variable is forced (rule (d)); `x@p` binds `x`
   to the value (rule (e)); `n+k` compares by `>=` and binds `n` to the
   value less `k` (rule (s)); a record pattern tests its constructor and
   matches its fields in the pattern's order (rules (m) to (o)).

   Sestoft's order (Sestoft 1996) matches the same patterns in the same
   order, but makes no test whose outcome the tests made already decide:
   a decision tree whose right-hand sides are functions of their
   variables, so that none is copied. Its only freedom is in tests on
   values already forced (D34). A clause with a pattern it does not take
   apart (a literal, `~p`, `n+k`, a newtype's or a record's) is matched
   from there on in the Report's way.

   Area: Languages *)
signature HS_MATCH =
sig
  (* How clauses are matched. *)
  datatype order = Report | Sestoft

  (* `order` is the order of every match: `Report`, `-O0`'s, unless rhc is
     told otherwise. *)
  val order : order ref

  (* What is matched: an atom of Core and its type. *)
  type occurrence = Core.atom * Core.ty

  (* A clause: its patterns, and its right-hand side, made in the scope of
     the patterns' variables and given what to do where its guards all
     fail. *)
  type clause = HsAst.pat list * (HsDsEnv.env * HsDsCore.texp -> HsDsCore.texp)

  (* `clauses (env, occurrences, rows, failure)` matches the occurrences
     against each clause of `rows` in turn.

     Each pattern is matched against its occurrence; the match is the
     right-hand side of the first clause that matches, or `failure t` where
     none does, `t` the type of the match. *)
  val clauses : HsDsEnv.env * occurrence list * clause list * (Core.ty -> HsDsCore.texp) -> HsDsCore.texp

  (* `pattern (env, occurrence, p, success, failure)` matches one
     occurrence against `p` in the Report's way.

     It is `success` in the scope of `p`'s variables where it matches, and
     `failure`, an atom, where it does not. *)
  val pattern : HsDsEnv.env * occurrence * HsAst.pat * (HsDsEnv.env -> HsDsCore.texp) * HsDsCore.texp
                -> HsDsCore.texp

  (* `variables p` is the variables `p` binds, in order, by their names in
     the renamed tree. *)
  val variables : HsAst.pat -> HsAst.name list

  (* `lazy p` is whether `p` never fails and forces nothing: a variable,
     `_`, `~p` and `x@p` of one of these. *)
  val lazy : HsAst.pat -> bool
end

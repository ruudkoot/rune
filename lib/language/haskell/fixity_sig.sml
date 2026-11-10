(* Haskell 98's fixity resolution (the Report's 10.6, 3.4, 3.5 and 4.4.2;
   the haskell98 roadmap's M12): the flat sequences of operators the parser
   leaves, `HsAst.ESeq` and `HsAst.PSeq`, made into trees by the fixities of
   the operators' entities, read after names (D29), so that a renamed tree
   is resolved with no iteration.

   A resolved sequence is a tree of sequences of two kinds only: an
   operator with its operands, `[EA l, EO op, EA r]`, and a negation,
   `[ENeg, EA e]`; in a pattern `[PA l, PO op, PA r]`, a negative literal
   staying a `PNegLit`. What is refused, each where the source has it:

   - two operators of one precedence, either of them non-associative or
     the two of different associativity (10.6), `do a == b == c` among
     them, which the Report's 9.3 gives a parse and every oracle refuses
     (R1, and R9 for `let`, as D38 pins);
   - a negation where the grammar has none: after an operator of
     precedence 6 or more, `a * - b` (R10, 3.4);
   - a section whose operator does not bind more loosely than its
     operand's, or as loosely on the side it associates to: `(a + b ^)`,
     `(-5 ^)`, `(+ a + b)` (3.5, R10);
   - a left-hand side `p1 op p2` whose operands bind more loosely than
     its operator, `x : xs +++ ys = ...` with `+++` tighter (4.4.3);
   - a negative literal as the left operand of an operator tighter than
     negation, in a pattern: `-1 :* x` (the grammar's `lpat`).

   Area: Languages *)
signature HS_FIXITY =
sig
  (* The associativity and the precedence of an operator. *)
  type fixity = HsAst.fixity * int

  (* An operator with no fixity declaration: `infixl 9` (4.4.2). *)
  val default : fixity

  (* `show f` is `f` as a declaration writes it: `infixl 6`. *)
  val show : fixity -> string

  (* `resolve {fixityOf} m` is the module `m`, a renamed one, with every
     sequence of operators resolved, and the errors of resolution in the
     order of the source. `fixityOf q` is the fixity of the operator
     named `q` in the renamed tree, `NONE` for the default. *)
  val resolve : {fixityOf : HsAst.qname -> fixity option} -> HsAst.module
                -> HsAst.module * (HsSource.span * string) list
end

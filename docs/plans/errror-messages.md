- error recovery / multiple error per pass in lexer, parser, type checker
- data type instead of string to report errors
  - automatic documention via runedoc

## What the linting roadmap laid for this

[correctness/linting.md](correctness/linting.md) (D6, M11, M14) needed these
for types on the syntax. None of them changes a message.

- **Node ids.** Every `Ast` node has one, given by both parsers and fresh in
  `SyntaxAst.copy`, so an error held as data can name its nodes rather than
  a span. Spans are not unique: an infix application and its tuple share one.
- **Spans** on clauses, record labels and sequences of type variables. A
  match rule's is worked out.
- **Each top-level declaration's status** (`Witness.status`): whether it
  elaborated, so that nothing reads what a failed declaration left behind.
- **`SourceTy`** (`elab/sourcety.sml`), the types of the source, with records'
  labels and each name's equality, and a printer that names a type variable
  alike across a unit. AstLint and hover use it. Messages do not yet: they
  print `Types.ty` with `Types.toString`, and moving them is this plan's.

Left to this plan:
- an error type, so that a failed declaration still binds its names and the
  next error is not "unbound" (D6 B);
- recovery, and more than one error per declaration;
- errors as data.

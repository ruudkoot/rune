(* The abstract syntax of Haskell 98 as text, for `rhc --dump-ast` and for
   the tree round trip of a test that compares trees by their text.

   A node is a line: its constructor and what it holds that is not a node,
   a name, a literal as written, an associativity; the nodes below it
   follow, each on its line, two spaces further in. With spans, a node's
   line ends with its span, `@START-STOP` in bytes of its file; without
   them, two trees print the same exactly where they are equal read with
   no annotations. A node's own tokens are not shown.

   Area: Languages *)
signature HS_DUMP =
sig
  (* `module {spans} m` is `m` as text, with every node's span if `spans`. *)
  val module : {spans : bool} -> HsAst.module -> string

  (* `exp {spans} e` is the expression `e` as text, as `module` writes it. *)
  val exp : {spans : bool} -> HsAst.exp -> string
end

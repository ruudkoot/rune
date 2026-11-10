(* Printers of Haskell 98's abstract syntax (the haskell98 roadmap's D28).

   Three prints share one walk of the tree. `explicit` writes every block
   in braces with semicolons, so that no layout rule applies to what it
   writes; `implicit` writes every block by layout, each item on a line of
   its own; both print every token a node stands for and nothing else, so
   that reading a print back gives the tree printed, and its tokens are
   those of `L` of the source but for empty items and a trailing comma
   (the tree and token round trips of the roadmap's section Round trips).
   `exact` prints a tree read with `Full` annotations as its file, byte for
   byte: every token where the source had it, with the comments, pragmas
   and white space before it. A node with no annotation, which a tool made,
   is printed by `exact` as `explicit` prints it.

   Area: Languages *)
signature HS_PRINT =
sig
  (* `explicit m` is `m` with every block in braces. *)
  val explicit : HsAst.module -> string

  (* `implicit m` is `m` with every block by layout, but an empty one,
     which is `{}`. *)
  val implicit : HsAst.module -> string

  (* `exact (bytes, m)` is the file whose bytes, `bytes`, `m` was read
     from with `Full` annotations; for a tree a tool changed, the file with
     the change. *)
  val exact : string * HsAst.module -> string

  (* `exp e`, `pat p`, `ty t` and `decl d` are nodes as `explicit` prints
     them, for a message. *)
  val exp : HsAst.exp -> string
  val pat : HsAst.pat -> string
  val ty : HsAst.ty -> string
  val decl : HsAst.decl -> string
end

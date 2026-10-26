(* dump: --dump-witnesses *)
(* What the elaborator records of the nodes of the syntax by their ids
   (Witness, the linting roadmap's M11), as --dump-witnesses prints it after
   Elaborate.finish, with each node's span and its types read as SourceTy:
   the instance of a constructor in a pattern; the type of a wildcard, of a
   raise and of a [] pattern; the type names a datatype declaration made,
   with their equality; the explicit type variables a val scopes; the type
   variables each binding of a group generalised, at the binding; the
   default an overloaded constant or identifier was given where its context
   ended; and whether each declaration at top level elaborated. *)
datatype 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
datatype t = A | B of int -> int
fun size Leaf = 0
  | size (Node (l, _, r)) = size l + 1 + size r
fun first [] = raise Match
  | first (x :: _) = x
val 'a id = fn (x : 'a) => x
fun pair x = (x, x) and swap (a, b) = (b, a)
val w = 0w7
fun twice x = x + x
val n = size (Node (Leaf, w, Leaf)) + twice 2

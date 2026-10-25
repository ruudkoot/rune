(* dump: --passes=expand --dump-after=expand *)
(* The expansion (functors-units.md, M6): Sum's function (g1) stays, and the
   application I is its body copied as definitions of the top level, at int --
   the datatype tree an instance of its own (tree/2), sum a global function
   that adds ints and calls itself, the parameter's slots the argument's
   globals, and the casts through unit gone; n calls the copy's sum. *)
signature S = sig type t val add : t * t -> t val zero : t end
functor Sum (X : S) = struct
  datatype tree = Leaf | Node of tree * X.t * tree
  fun sum Leaf = X.zero | sum (Node (l, x, r)) = X.add (sum l, X.add (x, sum r))
end
structure I = Sum (struct type t = int fun add (a : int, b) = a + b val zero = 0 end)
val n = I.sum (I.Node (I.Leaf, 3, I.Leaf))

(* dump: --passes= --dump-after=midcanon *)
(* Mid numbered canonically (MidCanon), the stage after `mid` on a whole
   program: every variable, global, join point, type name and type
   variable numbered by where it first appears, so that the same program
   compiled whole and made of its units' Mid is the same. The dump numbers
   variables afresh anyway; what shows is that the program is unchanged:
   the datatype and the polymorphic function as `mid` made them. *)
datatype 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
fun size Leaf = 0
  | size (Node (l, _, r)) = size l + 1 + size r
val n = size (Node (Leaf, "x", Leaf))

structure Determinism =
struct
  datatype 'a tree = Leaf of 'a | Branch of 'a tree * 'a tree
  fun map f (Leaf x) = Leaf (f x)
    | map f (Branch (left, right)) = Branch (map f left, map f right)
  fun identity x = x
  val value = map identity (Branch (Leaf (), Leaf ()))
end

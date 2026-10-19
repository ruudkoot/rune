(* Tree datatype shared with the classic SML/NJ binary-trees source.
   Preserve binary-trees/LICENSE (BSD 3-Clause, SML/NJ 2024).
   Each benchmark retains its own generator/checker evaluation order. *)
structure BenchBinaryTree =
struct
  datatype tree = Empty | Node of tree * tree
end

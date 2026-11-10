(* Strongly connected components, for the dependency analyses of Haskell
   98's checker: of type declarations for kinds (4.6), and of bindings for
   declaration groups (4.5.1).

   Area: Languages *)
signature HS_SCC =
sig
  (* `sccs (nodes, edges)` is the components of the graph of `nodes`, each
     after every one it depends on.

     `edges n` is the nodes `n` depends on, those not among `nodes`
     ignored; a component's members are in the order of `nodes`. *)
  val sccs : string list * (string -> string list) -> string list list
end

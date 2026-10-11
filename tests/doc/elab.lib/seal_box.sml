(* What a program sees of Box, Crate and Chest. *)
structure Box : BOX where type elem = int = Box
structure Crate : BOX where type elem = int = Crate
structure Chest : BOX where type elem = string = Chest

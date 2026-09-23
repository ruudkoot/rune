(* What a program sees of Runtime: the members RUNTIME names. Nothing here is
   abstract -- `stats` is a record of ints in the signature too -- so the seal
   is transparent. *)
structure Runtime : RUNTIME = Runtime

(* What a program sees of the structure of windows.sml: the members that its
   signature names, with the types it keeps abstract made so (a key of the
   registry, a conversation of DDE, a process). The library itself is
   compiled before this file and has the structure whole. *)
structure Windows :> WINDOWS = Windows

(* What a program sees of the structures of timer.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
(* the two timers are abstract: no other signature names them *)
structure Timer :> TIMER = Timer

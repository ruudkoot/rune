(* What a program sees of the structures of date.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
(* `date` is abstract: no other signature names it *)
structure Date :> DATE where type weekday = Date.weekday where type month = Date.month = Date

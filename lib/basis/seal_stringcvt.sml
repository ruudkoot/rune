(* What a program sees of the structures of stringcvt.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
(* `cs` is abstract: nothing but `scanString` and the functions given to it
   know of it. The two datatypes are those that the other signatures name. *)
structure StringCvt :> STRING_CVT where type radix = StringCvt.radix where type realfmt = StringCvt.realfmt = StringCvt

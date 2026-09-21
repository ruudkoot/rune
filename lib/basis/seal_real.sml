(* What a program sees of the structures of real.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure LargeReal : REAL = LargeReal
structure Math : MATH where type real = Real.real = Math
structure Real : REAL where type real = real = Real
structure Real64 : REAL = Real64

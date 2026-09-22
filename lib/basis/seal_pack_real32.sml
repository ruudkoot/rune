(* What a program sees of the structures of pack_real32.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure PackReal32Big : PACK_REAL where type real = Real32.real = PackReal32Big
structure PackReal32Little : PACK_REAL where type real = Real32.real = PackReal32Little

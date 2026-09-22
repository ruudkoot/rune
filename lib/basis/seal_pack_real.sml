(* What a program sees of the structures of pack_real.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure PackReal64Big : PACK_REAL where type real = Real64.real = PackReal64Big
structure PackReal64Little : PACK_REAL where type real = Real64.real = PackReal64Little
structure PackRealBig : PACK_REAL where type real = Real.real = PackRealBig
structure PackRealLittle : PACK_REAL where type real = Real.real = PackRealLittle

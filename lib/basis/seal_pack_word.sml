(* What a program sees of the structures of pack_word.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure PackWord16Big : PACK_WORD = PackWord16Big
structure PackWord16Little : PACK_WORD = PackWord16Little
structure PackWord32Big : PACK_WORD = PackWord32Big
structure PackWord32Little : PACK_WORD = PackWord32Little
structure PackWord64Big : PACK_WORD = PackWord64Big
structure PackWord64Little : PACK_WORD = PackWord64Little

(* What a program sees of the structures of textprimio.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure TextPrimIO : PRIM_IO where type array = CharArray.array where type vector = CharVector.vector where type elem = Char.char = TextPrimIO

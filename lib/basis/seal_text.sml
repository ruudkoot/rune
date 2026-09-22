(* What a program sees of the structures of text.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Text : TEXT where type Char.char = Char.char where type String.string = String.string where type Substring.substring = Substring.substring where type CharArray.array = CharArray.array where type CharVectorSlice.slice = CharVectorSlice.slice where type CharArraySlice.slice = CharArraySlice.slice = Text

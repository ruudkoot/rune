(* What a program sees of the structures of widetextio.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure WideTextPrimIO : PRIM_IO where type array = WideCharArray.array where type vector = WideCharVector.vector where type elem = WideChar.char where type vector_slice = WideCharVectorSlice.slice where type array_slice = WideCharArraySlice.slice = WideTextPrimIO

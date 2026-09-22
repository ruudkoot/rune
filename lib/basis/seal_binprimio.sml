(* What a program sees of the structures of binprimio.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure BinPrimIO : PRIM_IO where type array = Word8Array.array where type vector = Word8Vector.vector where type elem = Word8.word where type pos = Position.int where type vector_slice = Word8VectorSlice.slice where type array_slice = Word8ArraySlice.slice = BinPrimIO

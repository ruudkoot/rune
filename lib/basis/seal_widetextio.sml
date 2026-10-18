(* What a program sees of the structures of widetextio.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure WideTextPrimIO : PRIM_IO where type array = WideCharArray.array where type vector = WideCharVector.vector where type elem = WideChar.char where type vector_slice = WideCharVectorSlice.slice where type array_slice = WideCharArraySlice.slice = WideTextPrimIO
(* `StreamIO.out_pos` is abstract, as `TextIO`'s is; the streams stay what
   they are, as `TextIO`'s do. *)
structure WideTextIO :> TEXT_IO
  where type StreamIO.vector = WideCharVector.vector
  where type StreamIO.elem = WideChar.char
  where type StreamIO.substring = WideSubstring.substring
  where type StreamIO.reader = WideTextPrimIO.reader
  where type StreamIO.writer = WideTextPrimIO.writer
  where type StreamIO.pos = WideTextPrimIO.pos
  where type instream = WideTextIO.instream
  where type outstream = WideTextIO.outstream
  where type StreamIO.instream = WideTextIO.StreamIO.instream
  where type StreamIO.outstream = WideTextIO.StreamIO.outstream = WideTextIO

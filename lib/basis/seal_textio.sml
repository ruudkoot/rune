(* What a program sees of the structures of textio.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
(* `StreamIO.out_pos` is abstract: no other signature names it. The streams
   are those that the signatures of `Unix`, `Posix` and the readers name. *)
structure TextIO :> TEXT_IO
  where type instream = TextIO.instream
  where type outstream = TextIO.outstream
  where type StreamIO.instream = TextIO.StreamIO.instream
  where type StreamIO.outstream = TextIO.StreamIO.outstream = TextIO

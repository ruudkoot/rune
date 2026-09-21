(* What a program sees of the structures of os.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
(* `FileSys.file_id`, `IO.iodesc_kind`, `IO.poll_desc` and `IO.poll_info` are
   abstract: no other signature names them. The types that the signatures of
   `Posix`, `Unix`, the sockets and the readers name stay what they are. *)
structure OS :> OS
  where type syserror = OS.syserror
  where type Process.status = OS.Process.status
  where type IO.iodesc = OS.IO.iodesc
  where type FileSys.dirstream = OS.FileSys.dirstream
  where type FileSys.access_mode = OS.FileSys.access_mode = OS

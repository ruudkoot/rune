(* What a program sees of the structures of posix.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Posix :> POSIX where type Signal.signal = Posix.Signal.signal where type Process.exit_status = Posix.Process.exit_status where type FileSys.dirstream = OS.FileSys.dirstream where type FileSys.access_mode = OS.FileSys.access_mode = Posix

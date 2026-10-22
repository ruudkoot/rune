(* File-system include resolution for a C translation unit.

   Area: Languages *)
signature C_FILES =
sig
  (* `read path` reads original bytes without newline conversion and uses
     the canonical file name as the source identity.

     Raises: `IO.Io` or `OS.SysErr` for unreadable sources. *)
  val read : string -> {file : string, text : string}
  (* `resolver roots` searches quoted includes beside their source before
     searching the ordered include roots.

     Angle includes search roots.
     `include_next` continues after the root containing the source.
     A found but unreadable source reports its I/O error.

     Raises: `OS.SysErr` for an invalid include root. *)
  val resolver : string list -> CPreprocess.resolver
end

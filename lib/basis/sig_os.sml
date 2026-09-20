(* The operating system: its errors, its file system, its paths, its
   processes and its I/O descriptors, gathered into one structure.

   The four substructures are what a program uses; what stands here besides
   them is the error reporting they share. Every operation of `OS` that the
   system refuses raises `SysErr`, with the text the system gave and a
   `syserror` naming the condition.

   `POSIX` goes further for the systems that have it, and `UNIX` runs other
   programs.

   Area: The operating system

   See also: `OS_FILE_SYS`, `OS_PATH`, `OS_PROCESS`, `OS_IO`, `POSIX`

   Transcription-fix: `OS/opaque-in-the-page`. The page declares `structure
   OS :> OS`, so the types that no `where` clause fixes are abstract; the
   suite matches `OS` against this signature both transparently and
   opaquely. *)
signature OS =
sig
  (* The file system: directories, the kind of a file, and its times and sizes. *)
  structure FileSys : OS_FILE_SYS

  (* The descriptors the system knows a stream by, and polling them. *)
  structure IO : OS_IO

  (* Paths as text, taken apart and put together. *)
  structure Path : OS_PATH

  (* The process: its environment, its exit and the commands it runs. *)
  structure Process : OS_PROCESS

  (* The type of a condition the system reports.

     Deviation: `OS.syserror/is-an-int`. The specification leaves the type
     abstract; in Rune it is the `errno` of the system, an `int`, and the
     structure is not sealed, so that shows. *)
  eqtype syserror

  (* Raised when the system refuses an operation: the message it gave, and the condition when there is one. *)
  exception SysErr of string * syserror option

  (* `errorMsg e` is the text the system gives for `e`, meant for a person to read. *)
  val errorMsg : syserror -> string

  (* `errorName e` is a short name for `e`, meant for a program.

     Implementation: `OS.errorName/posix-names`. The names are those of
     `Posix.Error`, lower case and without the `E`: `"noent"` rather than
     `"ENOENT"`.

     Pinned by: `OS.errorName/*` *)
  val errorName : syserror -> string

  (* `syserror s` is `SOME` of the condition that `errorName` calls `s`, or `NONE` when there is none.

     Reading: `OS.syserror/one-name-one-condition`. "A unique name" is read
     as: one condition gives one error and one name, whichever function met
     it, and different conditions have different names, so `syserror` and
     `errorName` invert each other.

     Pinned by: `OS.syserror/same-condition`, `OS.errorName/different-errors` *)
  val syserror : string -> syserror option
end

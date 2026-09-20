(* The conditions the system reports when a call fails, and their names.

   A failing POSIX call raises `OS.SysErr` with a `syserror`, which is the
   `errno` the call left behind. The values below are the conditions POSIX
   names; comparing with one of them is how a program asks why a call failed:

   ```
   f () handle OS.SysErr (_, SOME e) => if e = Posix.Error.noent then ... else ...
   ```

   Which condition a call reports is POSIX's business, not this library's,
   and POSIX leaves some of it open: removing a directory that is not empty
   may give `exist` or `notempty`, and a system may report something no name
   here covers. `errorName` names those too.

   Area: The operating system

   Status: optional

   See also: `OS`, `POSIX`, `POSIX_FILE_SYS`, `POSIX_IO`

   Erratum: `POSIX_ERROR.syserror/spec-writes-OS.Process`. The
   page writes `eqtype syserror = OS.Process.syserror`; `OS.Process` has no
   such type, the description says it "is identical to the type
   `OS.syserror`", and `eqtype t = ty` is not a specification SML allows. It
   is written `type syserror = OS.syserror`, which admits equality.

   Reading: `Posix.Error/which-error-is-posix's`. Which condition a failing
   call reports is prescribed by POSIX and not by this library; where POSIX
   allows two, the suite accepts either.

   Pinned by: `Posix.Error.notempty/rmDir-nonempty` *)
signature POSIX_ERROR =
sig
  (* The type of a condition the system reports: the `syserror` of `OS`.

     Deviation: `Posix.Error.syserror/is-an-int`. It is the `errno` of the
     system, an `int`, and the structure is not sealed, so that shows. *)
  type syserror = OS.syserror

  (* `toWord e` is the number the system gives `e`, its `errno` value. *)
  val toWord : syserror -> SysWord.word

  (* `fromWord w` is the condition whose `errno` value is `w`. *)
  val fromWord : SysWord.word -> syserror

  (* `errorMsg e` is the text the system gives for `e`, meant for a person to read. *)
  val errorMsg : syserror -> string

  (* `errorName e` is a short name for `e`, meant for a program.

     Implementation: `Posix.Error.errorName/the-posix-names`. For the
     conditions POSIX names it is the name below -- `"noent"` for `noent` --
     and for the others it is the name `OS.errorName` invents.

     Example: `errorName noent = "noent"` *)
  val errorName : syserror -> string

  (* `syserror s` is `SOME` of the condition that `errorName` calls `s`, or `NONE`.

     Law: `syserror (errorName e) = SOME e` for every condition, named here
     or not.

     Example: `syserror "noent" = SOME noent` *)
  val syserror : string -> syserror option

  (* ---- The conditions POSIX names ---- *)

  (* Permission is refused.

     Implementation: `Posix.Error.acces/not-for-the-superuser`. Permission
     bits do not stop a privileged process, so the suite's checks of this and
     of `perm` hold for an ordinary user and pass trivially as root.

     Pinned by: `Posix.Error.acces/open-unreadable-file` *)
  val acces : syserror

  (* Nothing is ready; try again. *)
  val again : syserror

  (* The file descriptor is not open, or not open the right way. *)
  val badf : syserror

  (* The message is not of the right kind. *)
  val badmsg : syserror

  (* What was asked for is in use. *)
  val busy : syserror

  (* The operation was cancelled. *)
  val canceled : syserror

  (* The process has no child to wait for. *)
  val child : syserror

  (* Waiting would deadlock. *)
  val deadlk : syserror

  (* The argument is outside the domain of the function. *)
  val dom : syserror

  (* The file is there already. *)
  val exist : syserror

  (* An address given to the system is not one the process may use. *)
  val fault : syserror

  (* The file would grow past what the system or the process allows. *)
  val fbig : syserror

  (* The operation has started and is not finished. *)
  val inprogress : syserror

  (* A signal arrived before anything was done. *)
  val intr : syserror

  (* An argument is not one the call accepts.

     Implementation: `Posix.Error.inval/rename-into-itself`. Renaming a
     directory into itself is taken to report this condition.

     Pinned by: `Posix.Error.inval/rename-into-itself` *)
  val inval : syserror

  (* The device reported a failure. *)
  val io : syserror

  (* The name is a directory where one is not allowed. *)
  val isdir : syserror

  (* Too many symbolic links were followed; they may lead in a circle. *)
  val loop : syserror

  (* The process has as many files open as it may. *)
  val mfile : syserror

  (* The file has as many links as it may. *)
  val mlink : syserror

  (* The message is longer than may be sent at once. *)
  val msgsize : syserror

  (* The name, or one of its arcs, is too long. *)
  val nametoolong : syserror

  (* The system has as many files open as it may. *)
  val nfile : syserror

  (* The device does not offer this operation. *)
  val nodev : syserror

  (* The name names nothing. *)
  val noent : syserror

  (* The file is not a program the system can run. *)
  val noexec : syserror

  (* No lock is free. *)
  val nolck : syserror

  (* There is not enough memory. *)
  val nomem : syserror

  (* There is no room left on the device. *)
  val nospc : syserror

  (* The system does not have this call. *)
  val nosys : syserror

  (* The name is not a directory where one is needed. *)
  val notdir : syserror

  (* The directory is not empty. *)
  val notempty : syserror

  (* The operation is not supported here. *)
  val notsup : syserror

  (* The descriptor is not a terminal. *)
  val notty : syserror

  (* The device or the address is not there. *)
  val nxio : syserror

  (* The operation is not permitted, whatever the permission bits say. *)
  val perm : syserror

  (* A pipe or a socket is written that nobody reads.

     Reading: `Posix.Error.pipe/or-the-signal`. Writing to such a pipe either
     ends the writer with `Posix.Signal.pipe` or, when that signal is ignored
     or caught, fails with this condition; the suite accepts both.

     Pinned by: `Posix.Error.pipe/write-without-reader` *)
  val pipe : syserror

  (* The result is outside the range the type can hold. *)
  val range : syserror

  (* The file system may only be read. *)
  val rofs : syserror

  (* The descriptor cannot be positioned: it is a pipe, a socket or a terminal. *)
  val spipe : syserror

  (* There is no such process. *)
  val srch : syserror

  (* The argument list is longer than the system allows. *)
  val toobig : syserror

  (* The link would cross from one file system to another. *)
  val xdev : syserror
end

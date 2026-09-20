(* The password and group databases: turning a user or group name into a
   number, and back.

   These read what the system keeps about its users and groups -- on a
   classic Unix the files `/etc/passwd` and `/etc/group`, and in general
   whatever the system's name service offers. They do not change anything.

   Area: The operating system

   Status: optional

   See also: `POSIX_PROC_ENV`, `POSIX`, `POSIX_FILE_SYS`

   Erratum: `POSIX_SYS_DB/flexible-types`. The types `uid` and `gid` are left
   flexible here, as on the page, which says only that they are "identical to
   `Posix.ProcEnv.uid`"; `POSIX` fixes them.

   Implementation: `Posix.SysDB/what-a-check-can-assume`. The suite assumes
   that the user and the group numbered 0 exist and are called `root`, which
   holds on Linux and the BSDs, and compares the other fields with what
   `getent` prints.

   Pinned by: `Posix.SysDB.getpwuid/root`, `Posix.SysDB.getgrgid/root` *)
signature POSIX_SYS_DB =
sig
  (* The type of the number that names a user, the one of `Posix.ProcEnv`. *)
  eqtype uid

  (* The type of the number that names a group. *)
  eqtype gid

  (* What the system knows about a user. *)
  structure Passwd :
  sig
    (* The type of an entry of the password database. *)
    type passwd

    (* `name pw` is the login name of `pw`. *)
    val name : passwd -> string

    (* `uid pw` is the number of the user `pw`. *)
    val uid : passwd -> uid

    (* `gid pw` is the number of that user's own group. *)
    val gid : passwd -> gid

    (* `home pw` is the path of that user's home directory. *)
    val home : passwd -> string

    (* `shell pw` is the path of the program that user gets at login. *)
    val shell : passwd -> string
  end

  (* What the system knows about a group. *)
  structure Group :
  sig
    (* The type of an entry of the group database. *)
    type group

    (* `name gr` is the name of `gr`. *)
    val name : group -> string

    (* `gid gr` is the number of the group `gr`. *)
    val gid : group -> gid

    (* `members gr` is the login names of the users that belong to `gr` besides those whose own group it is. *)
    val members : group -> string list
  end

  (* `getgrgid g` is what the system knows about the group numbered `g`.

     Raises: `OS.SysErr` if there is no such group. *)
  val getgrgid : gid -> Group.group

  (* `getgrnam name` is what the system knows about the group called `name`.

     Raises: `OS.SysErr` if there is no such group, and at once for an empty
     name. *)
  val getgrnam : string -> Group.group

  (* `getpwuid u` is what the system knows about the user numbered `u`.

     Raises: `OS.SysErr` if there is no such user.

     Reading: `Posix.SysDB/missing-raises-SysErr`. The C library reports a
     name it does not find without setting an `errno`; this raises
     `OS.SysErr` for it all the same, since the alternative would be to
     return something that names nobody.

     Pinned by: `Posix.SysDB.getpwnam/unknown*` *)
  val getpwuid : uid -> Passwd.passwd

  (* `getpwnam name` is what the system knows about the user called `name`.

     Raises: `OS.SysErr` if there is no such user, and at once for an empty
     name, which the primitive would otherwise take for a lookup by
     number. *)
  val getpwnam : string -> Passwd.passwd
end

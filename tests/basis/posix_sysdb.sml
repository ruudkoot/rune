(* requires: Posix OS TextIO *)
(* uses: fn/posix_child.sml *)
(* Posix.SysDB (signature POSIX_SYS_DB), after
   https://smlfamily.github.io/Basis/posix-sys-db.html: the entries of the
   user and group databases, compared with what getent(1) prints for them
   ("name:password:uid:gid:gecos:home:shell" and "name:password:gid:members",
   members separated by commas). Root is the user and the group with ID 0,
   called root (as on Linux and the BSDs). *)
structure TestPosixSysDB =
struct
  structure D = Posix.SysDB
  structure E = Posix.ProcEnv
  structure C = PosixChild
  val eqB = T.eq T.bool
  val eqS = T.eq T.string

  (* agree (label, expected, actual): the two thunks give the same string;
     both are computed inside the check. *)
  fun agree (label, expected : unit -> string, actual : unit -> string) =
    eqS (label, "agree",
         fn () => let val e = expected () val a = actual ()
                  in if e = a then "agree" else "got " ^ T.string a ^ ", expected " ^ T.string e end)

  (* field (database, key, n): field n (from 0) of what getent prints. *)
  fun field (database : string, key : string, n : int) : string =
    List.nth (String.fields (fn c => c = #":") (C.shell ("getent " ^ database ^ " " ^ key)), n)
  val decU = fn u => SysWord.fmt StringCvt.DEC (E.uidToWord u)
  val decG = fn g => SysWord.fmt StringCvt.DEC (E.gidToWord g)
  fun members (g : D.Group.group) : string = String.concatWith "," (D.Group.members g)

  (* ---- root ---- *)
  val () = eqS ("Posix.SysDB.getpwnam/root", "root", fn () => D.Passwd.name (D.getpwnam "root"))
  val () = eqS ("Posix.SysDB.getpwuid/root", "root", fn () => D.Passwd.name (D.getpwuid (E.wordToUid 0w0)))
  val () = eqS ("Posix.SysDB.getgrnam/root", "root", fn () => D.Group.name (D.getgrnam "root"))
  val () = eqS ("Posix.SysDB.getgrgid/root", "root", fn () => D.Group.name (D.getgrgid (E.wordToGid 0w0)))
  val () = eqS ("Posix.SysDB.Passwd.name/root", "root", fn () => D.Passwd.name (D.getpwnam "root"))
  val () = eqB ("Posix.SysDB.Passwd.uid/root", true, fn () => D.Passwd.uid (D.getpwnam "root") = E.wordToUid 0w0)
  val () = eqB ("Posix.SysDB.Passwd.gid/root", true,
                fn () => decG (D.Passwd.gid (D.getpwnam "root")) = field ("passwd", "root", 3))
  val () = agree ("Posix.SysDB.Passwd.home/root", fn () => field ("passwd", "root", 5),
                  fn () => D.Passwd.home (D.getpwnam "root"))
  val () = agree ("Posix.SysDB.Passwd.shell/root", fn () => field ("passwd", "root", 6),
                  fn () => D.Passwd.shell (D.getpwnam "root"))
  val () = eqS ("Posix.SysDB.Group.name/root", "root", fn () => D.Group.name (D.getgrgid (E.wordToGid 0w0)))
  val () = eqB ("Posix.SysDB.Group.gid/root", true, fn () => D.Group.gid (D.getgrnam "root") = E.wordToGid 0w0)
  val () = agree ("Posix.SysDB.Group.members/root", fn () => field ("group", "root", 3),
                  fn () => members (D.getgrnam "root"))

  (* ---- the user of this process and its group ---- *)
  fun me () = D.getpwuid (E.getuid ())
  val () = agree ("Posix.SysDB.getpwuid/current-user", fn () => C.shell "id -un", fn () => D.Passwd.name (me ()))
  val () = eqB ("Posix.SysDB.Passwd.uid/current-user", true, fn () => D.Passwd.uid (me ()) = E.getuid ())
  val () = eqB ("Posix.SysDB.getpwnam/current-user", true,
                fn () => let val p = D.getpwnam (D.Passwd.name (me ()))
                         in D.Passwd.uid p = E.getuid () andalso D.Passwd.home p = D.Passwd.home (me ()) end)
  val () = agree ("Posix.SysDB.Passwd.gid/current-user", fn () => field ("passwd", decU (E.getuid ()), 3),
                  fn () => decG (D.Passwd.gid (me ())))
  val () = agree ("Posix.SysDB.Passwd.home/current-user", fn () => field ("passwd", decU (E.getuid ()), 5),
                  fn () => D.Passwd.home (me ()))
  val () = agree ("Posix.SysDB.Passwd.shell/current-user", fn () => field ("passwd", decU (E.getuid ()), 6),
                  fn () => D.Passwd.shell (me ()))
  fun mine () = D.getgrgid (E.getgid ())
  val () = agree ("Posix.SysDB.getgrgid/current-group", fn () => field ("group", decG (E.getgid ()), 0),
                  fn () => D.Group.name (mine ()))
  val () = eqB ("Posix.SysDB.Group.gid/current-group", true, fn () => D.Group.gid (mine ()) = E.getgid ())
  val () = agree ("Posix.SysDB.Group.members/current-group", fn () => field ("group", decG (E.getgid ()), 3),
                  fn () => members (mine ()))
  val () = eqB ("Posix.SysDB.getgrnam/current-group", true,
                fn () => D.Group.gid (D.getgrnam (D.Group.name (mine ()))) = E.getgid ())
  val () = agree ("Posix.SysDB.Group.name/current-group", fn () => C.shell "id -gn", fn () => D.Group.name (mine ()))
  (* Every supplementary group of this process, some of them with
     members. *)
  val () = eqB ("Posix.SysDB.Group.members/with-members", true,
                fn () => List.all (fn g => members (D.getgrgid g) = field ("group", decG g, 3)) (E.getgroups ()))

  (* ---- "It raises OS.SysErr if there is no group or user with the given ID
     or name." ---- *)
  val isSysErr = fn OS.SysErr _ => true | _ => false
  val () = T.raises ("Posix.SysDB.getpwnam/unknown", isSysErr, fn () => D.getpwnam "rune-basis-no-such-user")
  val () = T.raises ("Posix.SysDB.getgrnam/unknown", isSysErr, fn () => D.getgrnam "rune-basis-no-such-group")
  val () = T.raises ("Posix.SysDB.getpwuid/unknown", isSysErr, fn () => D.getpwuid (E.wordToUid 0w1999999999))
  val () = T.raises ("Posix.SysDB.getgrgid/unknown", isSysErr, fn () => D.getgrgid (E.wordToGid 0w1999999999))
  val () = T.raises ("Posix.SysDB.getpwnam/empty", isSysErr, fn () => D.getpwnam "")

  val () = OS.FileSys.remove "posix-shell-out.txt" handle _ => ()
end

(* requires: Posix *)
(* uses: spec-sigs/POSIX_SYS_DB.sml *)
(* Posix.SysDB matches POSIX_SYS_DB, and its uid and gid are those of
   Posix.ProcEnv ("identical to Posix.ProcEnv.uid"). *)
structure TestPosixSysDBSig =
struct
  structure C : SPEC_POSIX_SYS_DB = Posix.SysDB
  val () = T.check ("Posix.SysDB:POSIX_SYS_DB/matches", fn () => true)
  val () = T.check ("Posix.SysDB:POSIX_SYS_DB/uid-is-ProcEnv.uid",
                    fn () => C.Passwd.uid (C.getpwuid (Posix.ProcEnv.getuid ())) = Posix.ProcEnv.getuid ())
  val () = T.check ("Posix.SysDB:POSIX_SYS_DB/gid-is-ProcEnv.gid",
                    fn () => C.Group.gid (C.getgrgid (Posix.ProcEnv.getgid ())) = Posix.ProcEnv.getgid ())
end

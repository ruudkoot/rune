(* The entries of the user and the group of the process, and those of root.
   getpwuid comes first: getpwnam and getgrnam as the first look-up of the
   program crash for another reason (their C functions are called with the
   stack misaligned). *)
structure D = Posix.SysDB
structure E = Posix.ProcEnv
fun show f = f () handle e => "raised " ^ exnName e
val () = print ("getpwuid (getuid ()): name " ^ show (fn () => D.Passwd.name (D.getpwuid (E.getuid ()))) ^ "\n")
val () = print ("getgrgid (getgid ()): name " ^ show (fn () => D.Group.name (D.getgrgid (E.getgid ()))) ^ "\n")
val () = print ("getpwnam \"root\": home " ^ show (fn () => D.Passwd.home (D.getpwnam "root")) ^ "\n")
val () = print ("getgrnam \"root\": name " ^ show (fn () => D.Group.name (D.getgrnam "root")) ^ "\n")

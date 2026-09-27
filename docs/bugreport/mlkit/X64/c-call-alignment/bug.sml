(* The first look-up in the group database: glibc reads /etc/nsswitch.conf
   and runs code that needs the stack aligned as the x86-64 ABI says. *)
val () = print "calling Posix.SysDB.getgrnam\n"
val g = Posix.SysDB.getgrnam "root"
val () = print "returned\n"

(* The primitives of Core that face the operating system (the haskell98
   roadmap, M18): what the Report's Directory, System, Time, CPUTime and
   Random's global generator need, each an action over one of Mid's
   primitives, through runtime/sys/sys.h as the SML Basis reaches it. A
   family of CorePrim's (CorePrimFamily): its primitives take Int and Str,
   evaluated, and give an Int, a Str or a Bool; each is lowered to a Mid
   function of its own (`gsys...`, in `midText`), which is one of Mid's
   primitives or a few of them, and the interpreter runs it over the SML
   Basis (OS.FileSys, OS.Process, Posix.FileSys, Time, Timer, Date).

   Where one fails it gives ~1 (or "" where it gives a Str) and leaves the
   system's error for sys_errno (CorePrimIo's), as Mid's primitive does.

   The primitives, each an action (World -> (utuple World T), the token
   dropped in Mid):
   - the file system: `os_mkdir`, `os_rmdir`, `os_chdir`, `os_remove` of a
     path and `os_rename` of two, 0 or ~1; `os_getcwd`, "" where it fails;
     `os_access` of a path and the bits 1 read, 2 write, 4 run (none: whether
     it is there), 1 or 0; `os_file_kind`, 0 a file, 1 a directory, 3 anything
     else, ~1 where nothing is there (links followed, so never 2, a link's
     number); `os_mod_time`, seconds since the epoch; `os_open_dir`, the
     number of a stream, `os_read_dir`, its next name, without . and .., ""
     at the end, `os_close_dir`; `os_file_mode`, the bits of the mode (07777,
     as stat gives them), and `os_set_mode`;
   - the process: `os_system`, what a command run by the shell exited with,
     or 256 and the signal that ended it; `os_getenv`, a variable's value, ""
     where it has none, and `os_has_env`, whether it has one;
     `command_arg_count` and `command_arg`, the program's arguments ("" past
     the last), and `command_name`, the program's file without its
     extension (ruling 33: getProgName is the part after the last /);
   - time: `time_now`, microseconds since the epoch; `time_cpu`, the
     processor's time in user and system mode, microseconds; `date_offset`,
     the seconds local time is ahead of UTC at a time in seconds (Domain
     where the system cannot say), `date_zone_name`, the local zone's name
     then (strftime's %Z), and `date_is_dst`, whether it is summer time then;
   - `random_seed`, 56 bits of the system's randomness, the clock's
     microseconds where it has none.

   Area: Languages *)
signature CORE_PRIM_SYS =
sig
  (* `family` is the primitives, their Mid text and how the interpreter runs
     each, which CorePrim lists among its families. *)
  val family : CorePrimFamily.family

  (* `program` is what the interpreter's `command_name` and `command_arg`
     give: rhc sets it to the file it interprets, and the arguments given it
     for the program. *)
  val program : {name : string, args : string list} ref

  (* `withoutExtension path` is path without the extension of its last arc:
     the part from its last dot on, where that dot is neither the arc's first
     character nor its last ("a/b.c" is "a/b", "a/.b" and "a." stay). *)
  val withoutExtension : string -> string
end

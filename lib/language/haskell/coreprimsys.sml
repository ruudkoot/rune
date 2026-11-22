(* The primitives of Core that face the operating system, a family of
   CorePrim's (coreprimsys_sig.sml): their types as Core text, the Mid
   function each is lowered to, and how the interpreter runs each. *)
structure CorePrimSys : CORE_PRIM_SYS =
struct
  structure F = CorePrimFamily

  val program = ref {name = "", args = [] : string list}

  fun withoutExtension s =
    let
      val n = size s
      fun go i =
        if i < 1 then s
        else case String.sub (s, i) of
               #"/" => s
             | #"." => if i < n - 1 andalso String.sub (s, i - 1) <> #"/" then String.substring (s, 0, i) else s
             | _ => go (i - 1)
    in go (n - 1) end

  (* ---- The interpreter's, over the SML Basis ---- *)

  (* a call that failed: its error kept for sys_errno, and ~1 *)
  fun failed (e as OS.SysErr _) = (CoreFiles.sysErrno := CoreFiles.errnoOf e; ~1)
    | failed e = raise e

  (* 0 where f returns, ~1 where it fails *)
  fun status f = (f (); 0) handle e as OS.SysErr _ => failed e

  (* the streams os_open_dir opens, by number *)
  val streams : (int * OS.FileSys.dirstream) list ref = ref []
  val nextStream = ref 1
  fun stream h = Option.map #2 (List.find (fn (k, _) => k = h) (!streams))

  fun openDir p =
    let val d = OS.FileSys.openDir p
        val h = !nextStream
    in nextStream := h + 1; streams := (h, d) :: !streams; h end
    handle e as OS.SysErr _ => failed e

  fun readDir h =
    case stream h of
      NONE => ""
    | SOME d => (case OS.FileSys.readDir d of SOME name => name | NONE => "") handle e as OS.SysErr _ => (ignore (failed e); "")

  fun closeDir h =
    case stream h of
      NONE => ~1
    | SOME d => (streams := List.filter (fn (k, _) => k <> h) (!streams); status (fn () => OS.FileSys.closeDir d))

  fun access (p, bits) =
    let
      val modes = List.mapPartial (fn (b, m) => if (bits div b) mod 2 = 1 then SOME m else NONE)
                                  [(1, OS.FileSys.A_READ), (2, OS.FileSys.A_WRITE), (4, OS.FileSys.A_EXEC)]
    in if OS.FileSys.access (p, modes) then 1 else 0 end
    handle e as OS.SysErr _ => failed e

  fun fileKind p =
    let
      val st = Posix.FileSys.stat p
      open Posix.FileSys.ST
    in if isReg st then 0 else if isDir st then 1 else if isLink st then 2 else 3 end
    handle e as OS.SysErr _ => failed e

  fun fileMode p =
    SysWord.toInt (SysWord.andb (Posix.FileSys.S.toWord (Posix.FileSys.ST.mode (Posix.FileSys.stat p)), 0wxFFF))
    handle e as OS.SysErr _ => failed e

  fun setMode (p, m) = status (fn () => Posix.FileSys.chmod (p, Posix.FileSys.S.fromWord (SysWord.fromInt m)))

  fun modTime p = Int.fromLarge (Time.toSeconds (OS.FileSys.modTime p)) handle e as OS.SysErr _ => failed e

  fun system c =
    let val signal = SysWord.toInt o Posix.Signal.toWord
    in
      case Posix.Process.fromStatus (OS.Process.system c) of
        Posix.Process.W_EXITED => 0
      | Posix.Process.W_EXITSTATUS w => Word8.toInt w
      | Posix.Process.W_SIGNALED s => 256 + signal s
      | Posix.Process.W_STOPPED s => 512 + signal s
    end
    handle e as OS.SysErr _ => failed e

  fun getenv n = OS.Process.getEnv n handle e as OS.SysErr _ => (ignore (failed e); NONE)

  fun arg i = if i < 0 then "" else (case List.drop (#args (!program), i) of a :: _ => a | [] => "") handle Subscript => ""

  fun micros t = Int.fromLarge (Time.toMicroseconds t)

  fun local' t = Date.fromTimeLocal (Time.fromSeconds (LargeInt.fromInt t))

  (* the date's fields read as UTC's, less the time: how far ahead of UTC
     local time is *)
  fun offset t =
    let
      val d = local' t
      val u = Date.date {year = Date.year d, month = Date.month d, day = Date.day d, hour = Date.hour d,
                         minute = Date.minute d, second = Date.second d, offset = SOME Time.zeroTime}
    in Int.fromLarge (Time.toSeconds (Date.toTime u)) - t end
    handle Date.Date => raise Domain | Time.Time => raise Domain | Overflow => raise Domain

  (* seven bytes of the system's randomness as a number, or the clock where
     there is no /dev/urandom (Mid's rt_random_bytes reads it, or
     RtlGenRandom on Windows) *)
  fun seed () =
    let
      val bytes = let val f = BinIO.openIn "/dev/urandom" in BinIO.inputN (f, 7) before BinIO.closeIn f end
                  handle IO.Io _ => Word8Vector.fromList []
    in
      if Word8Vector.length bytes = 0 then micros (Time.now ())
      else Word8Vector.foldl (fn (b, acc) => acc * 256 + Word8.toInt b) 0 bytes
    end

  (* ---- The table ---- *)

  (* an action's type of Core: its arguments, evaluated, then the token *)
  fun action (args, r) =
    "(-> " ^ String.concat (List.map (fn a => "!" ^ a ^ " ") args) ^ "World (utuple World !" ^ r ^ "))"

  fun bad name = raise Fail ("CorePrimSys: " ^ name ^ " given what its type does not allow")
  fun onStr name f = fn [F.Str p] => F.Int (f p) | _ => bad name
  fun onInt name f = fn [F.Int h] => f h | _ => bad name
  fun none name f = fn [] => f () | [F.Unit] => f () | _ => bad name

  val prims : F.prim list =
    [{name = "os_mkdir", ty = action (["Str"], "Int"), doc = "makes a directory: 0, or ~1",
      run = onStr "os_mkdir" (fn p => status (fn () => OS.FileSys.mkDir p)), mid = "gsysMkdir"},
     {name = "os_rmdir", ty = action (["Str"], "Int"), doc = "removes an empty directory: 0, or ~1",
      run = onStr "os_rmdir" (fn p => status (fn () => OS.FileSys.rmDir p)), mid = "gsysRmdir"},
     {name = "os_chdir", ty = action (["Str"], "Int"), doc = "changes the working directory: 0, or ~1",
      run = onStr "os_chdir" (fn p => status (fn () => OS.FileSys.chDir p)), mid = "gsysChdir"},
     {name = "os_remove", ty = action (["Str"], "Int"), doc = "removes a file: 0, or ~1",
      run = onStr "os_remove" (fn p => status (fn () => OS.FileSys.remove p)), mid = "gsysRemove"},
     {name = "os_rename", ty = action (["Str", "Str"], "Int"), doc = "renames the first to the second: 0, or ~1",
      run = fn [F.Str a, F.Str b] => F.Int (status (fn () => OS.FileSys.rename {old = a, new = b})) | _ => bad "os_rename",
      mid = "gsysRename"},
     {name = "os_getcwd", ty = action ([], "Str"), doc = "the working directory, \"\" where it fails",
      run = none "os_getcwd" (fn () => F.Str (OS.FileSys.getDir () handle e as OS.SysErr _ => (ignore (failed e); ""))),
      mid = "gsysGetcwd"},
     {name = "os_access", ty = action (["Str", "Int"], "Int"),
      doc = "whether a path can be read (bit 1), written (2) and run (4), or is there (none): 1 or 0",
      run = fn [F.Str p, F.Int bits] => F.Int (access (p, bits)) | _ => bad "os_access", mid = "gsysAccess"},
     {name = "os_file_kind", ty = action (["Str"], "Int"),
      doc = "0 a file, 1 a directory, 2 a link, 3 anything else, ~1 nothing there; following links",
      run = onStr "os_file_kind" fileKind, mid = "gsysFileKind"},
     {name = "os_mod_time", ty = action (["Str"], "Int"), doc = "when a file was last changed, seconds since the epoch; ~1",
      run = onStr "os_mod_time" modTime, mid = "gsysModTime"},
     {name = "os_open_dir", ty = action (["Str"], "Int"), doc = "opens a directory: the number of its stream, or ~1",
      run = onStr "os_open_dir" openDir, mid = "gsysOpenDir"},
     {name = "os_read_dir", ty = action (["Int"], "Str"), doc = "a stream's next name, without . and ..; \"\" at the end",
      run = onInt "os_read_dir" (F.Str o readDir), mid = "gsysReadDir"},
     {name = "os_close_dir", ty = action (["Int"], "Int"), doc = "closes a stream: 0, or ~1",
      run = onInt "os_close_dir" (F.Int o closeDir), mid = "gsysCloseDir"},
     {name = "os_file_mode", ty = action (["Str"], "Int"), doc = "the bits of a path's mode, 07777 of stat's; ~1",
      run = onStr "os_file_mode" fileMode, mid = "gsysFileMode"},
     {name = "os_set_mode", ty = action (["Str", "Int"], "Int"), doc = "sets those bits: 0, or ~1",
      run = fn [F.Str p, F.Int m] => F.Int (setMode (p, m)) | _ => bad "os_set_mode", mid = "gsysSetMode"},
     {name = "os_system", ty = action (["Str"], "Int"),
      doc = "runs a command by the shell: what it exited with, 256 and the signal that ended it, or ~1",
      run = onStr "os_system" system, mid = "gsysSystem"},
     {name = "os_getenv", ty = action (["Str"], "Str"), doc = "an environment variable's value, \"\" where it has none",
      run = fn [F.Str n] => F.Str (getOpt (getenv n, "")) | _ => bad "os_getenv", mid = "gsysGetenv"},
     {name = "os_has_env", ty = action (["Str"], "Bool"), doc = "whether an environment variable has a value",
      run = fn [F.Str n] => F.Bool (isSome (getenv n)) | _ => bad "os_has_env", mid = "gsysHasEnv"},
     {name = "command_arg_count", ty = action ([], "Int"), doc = "the number of the program's arguments",
      run = none "command_arg_count" (fn () => F.Int (length (#args (!program)))), mid = "gsysArgCount"},
     {name = "command_arg", ty = action (["Int"], "Str"), doc = "the program's argument at an index from 0; \"\" outside",
      run = onInt "command_arg" (F.Str o arg), mid = "gsysArg"},
     {name = "command_name", ty = action ([], "Str"),
      doc = "the program's file without its extension (ruling 33: getProgName is the part after the last /)",
      run = none "command_name" (fn () => F.Str (withoutExtension (#name (!program)))), mid = "gsysName"},
     {name = "time_now", ty = action ([], "Int"), doc = "microseconds since the epoch",
      run = none "time_now" (fn () => F.Int (micros (Time.now ()))), mid = "gsysTimeNow"},
     {name = "time_cpu", ty = action ([], "Int"), doc = "the processor's time of the program, user and system, microseconds",
      run = none "time_cpu" (fn () =>
        let val {usr, sys} = Timer.checkCPUTimer (Timer.totalCPUTimer ()) in F.Int (micros usr + micros sys) end),
      mid = "gsysTimeCpu"},
     {name = "date_offset", ty = action (["Int"], "Int"),
      doc = "the seconds local time is ahead of UTC at a time in seconds; Domain where the system cannot say",
      run = onInt "date_offset" (F.Int o offset), mid = "gsysDateOffset"},
     {name = "date_zone_name", ty = action (["Int"], "Str"), doc = "the local zone's name at a time (strftime's %Z)",
      run = onInt "date_zone_name" (fn t => F.Str (Date.fmt "%Z" (local' t) handle Date.Date => "" | Time.Time => "")),
      mid = "gsysZoneName"},
     {name = "date_is_dst", ty = action (["Int"], "Bool"), doc = "whether local time is summer time at a time",
      run = onInt "date_is_dst" (fn t => F.Bool (Date.isDst (local' t) = SOME true handle Date.Date => false | Time.Time => false)),
      mid = "gsysIsDst"},
     {name = "random_seed", ty = action ([], "Int"),
      doc = "56 bits of the system's randomness, the clock's microseconds where it has none",
      run = none "random_seed" (fn () => F.Int (seed ())), mid = "gsysRandomSeed"}]

  (* ---- Mid's, each prim a function over Mid's primitives ---- *)

  val midText = String.concatWith "\n"
    ["(funs",
     "  (fn gsysMkdir ((vyMkP : string)) : int \"os_mkdir\"",
     "    (return (prim os_mkdir vyMkP : string -> int)))",
     "  (fn gsysRmdir ((vyRmP : string)) : int \"os_rmdir\"",
     "    (return (prim os_rmdir vyRmP : string -> int)))",
     "  (fn gsysChdir ((vyCdP : string)) : int \"os_chdir\"",
     "    (return (prim os_chdir vyCdP : string -> int)))",
     "  (fn gsysRemove ((vyRvP : string)) : int \"os_remove\"",
     "    (return (prim os_remove vyRvP : string -> int)))",
     "  (fn gsysRename ((vyRnA : string) (vyRnB : string)) : int \"os_rename\"",
     "    (return (prim os_rename vyRnA vyRnB : (string * string) -> int)))",
     "  (fn gsysGetcwd ((vyGcU : unit)) : string \"os_getcwd\"",
     "    (return (prim os_getcwd () : unit -> string)))",
     "  (fn gsysAccess ((vyAcP : string) (vyAcM : int)) : int \"os_access\"",
     "    (return (prim os_access vyAcP vyAcM 0 : (string * int * int) -> int)))",
     (* Mid's gives 4 to 7 for a FIFO, a socket and devices: 3 here *)
     "  (fn gsysFileKind ((vyFkP : string)) : int \"os_file_kind\"",
     "    (let (vyFkK : int) (prim os_file_kind vyFkP : string -> int)",
     "    (let (vyFkO : bool) (prim int_gt vyFkK 3 : (int * int) -> bool)",
     "    (if vyFkO (return 3) (return vyFkK)))))",
     "  (fn gsysModTime ((vyMtP : string)) : int \"os_mod_time\"",
     "    (return (prim os_mod_time vyMtP : string -> int)))",
     "  (fn gsysOpenDir ((vyOdP : string)) : int \"os_open_dir\"",
     "    (return (prim os_open_dir vyOdP : string -> int)))",
     "  (fn gsysReadDir ((vyRdH : int)) : string \"os_read_dir\"",
     "    (let (vyRdO : string option) (prim os_read_dir vyRdH : int -> string option)",
     "    (let (vyRdT : int) (tag vyRdO)",
     "    (let (vyRdS : bool) (prim poly_eq vyRdT 1 : (int * int) -> bool)",
     "    (if vyRdS (return (decon 1 vyRdO : string option)) (return \"\"))))))",
     "  (fn gsysCloseDir ((vyClH : int)) : int \"os_close_dir\"",
     "    (return (prim os_close_dir vyClH : int -> int)))",
     (* stat's fields: the kind, then the mode *)
     "  (fn gsysFileMode ((vyFmP : string)) : int \"os_file_mode\"",
     "    (let (vyFmL : int list) (prim posix_stat vyFmP 0 0 : (string * int * int) -> int list)",
     "    (return (app gsysNthInt vyFmL 1))))",
     "  (fn gsysSetMode ((vySmP : string) (vySmM : int)) : int \"os_set_mode\"",
     "    (return (prim posix_chmod vySmP ~1 vySmM : (string * int * int) -> int)))",
     "  (fn gsysSystem ((vySyC : string)) : int \"os_system\"",
     "    (return (prim os_system vySyC : string -> int)))",
     "  (fn gsysGetenv ((vyGeN : string)) : string \"os_getenv\"",
     "    (let (vyGeO : string option) (prim os_getenv vyGeN : string -> string option)",
     "    (let (vyGeT : int) (tag vyGeO)",
     "    (let (vyGeS : bool) (prim poly_eq vyGeT 1 : (int * int) -> bool)",
     "    (if vyGeS (return (decon 1 vyGeO : string option)) (return \"\"))))))",
     "  (fn gsysHasEnv ((vyHeN : string)) : bool \"os_has_env\"",
     "    (let (vyHeO : string option) (prim os_getenv vyHeN : string -> string option)",
     "    (let (vyHeT : int) (tag vyHeO)",
     "    (return (prim poly_eq vyHeT 1 : (int * int) -> bool)))))",
     (* a list's element at an index from 0, or \"\" and ~1 outside *)
     "  (fn gsysNth ((vyNsL : string list) (vyNsI : int)) : string \"nth\"",
     "    (let (vyNsT : int) (tag vyNsL)",
     "    (let (vyNsE : bool) (prim poly_eq vyNsT 0 : (int * int) -> bool)",
     "    (let (vyNsZ : bool) (prim int_lt vyNsI 0 : (int * int) -> bool)",
     "    (if vyNsE (return \"\")",
     "    (if vyNsZ (return \"\")",
     "      (let (vyNsC : string * string list) (decon 1 vyNsL : string list)",
     "      (let (vyNsH : bool) (prim poly_eq vyNsI 0 : (int * int) -> bool)",
     "      (if vyNsH (let (vyNsX : string) (select 0 vyNsC) (return vyNsX))",
     "        (let (vyNsR : string list) (select 1 vyNsC)",
     "        (let (vyNsJ : int) (prim int_sub vyNsI 1 : (int * int) -> int)",
     "        (return (app gsysNth vyNsR vyNsJ)))))))))))))",
     "  (fn gsysNthInt ((vyNiL : int list) (vyNiI : int)) : int \"nth\"",
     "    (let (vyNiT : int) (tag vyNiL)",
     "    (let (vyNiE : bool) (prim poly_eq vyNiT 0 : (int * int) -> bool)",
     "    (let (vyNiZ : bool) (prim int_lt vyNiI 0 : (int * int) -> bool)",
     "    (if vyNiE (return ~1)",
     "    (if vyNiZ (return ~1)",
     "      (let (vyNiC : int * int list) (decon 1 vyNiL : int list)",
     "      (let (vyNiH : bool) (prim poly_eq vyNiI 0 : (int * int) -> bool)",
     "      (if vyNiH (let (vyNiX : int) (select 0 vyNiC) (return vyNiX))",
     "        (let (vyNiR : int list) (select 1 vyNiC)",
     "        (let (vyNiJ : int) (prim int_sub vyNiI 1 : (int * int) -> int)",
     "        (return (app gsysNthInt vyNiR vyNiJ)))))))))))))",
     "  (fn gsysLength ((vyLnL : string list) (vyLnN : int)) : int \"length\"",
     "    (let (vyLnT : int) (tag vyLnL)",
     "    (let (vyLnE : bool) (prim poly_eq vyLnT 0 : (int * int) -> bool)",
     "    (if vyLnE (return vyLnN)",
     "      (let (vyLnC : string * string list) (decon 1 vyLnL : string list)",
     "      (let (vyLnR : string list) (select 1 vyLnC)",
     "      (let (vyLnM : int) (prim int_add vyLnN 1 : (int * int) -> int)",
     "      (return (app gsysLength vyLnR vyLnM)))))))))",
     "  (fn gsysArgCount ((vyAnU : unit)) : int \"command_arg_count\"",
     "    (let (vyAnL : string list) (prim command_args () : unit -> string list)",
     "    (return (app gsysLength vyAnL 0))))",
     "  (fn gsysArg ((vyAgI : int)) : string \"command_arg\"",
     "    (let (vyAgL : string list) (prim command_args () : unit -> string list)",
     "    (return (app gsysNth vyAgL vyAgI))))",
     (* withoutExtension, from the index i down *)
     "  (fn gsysStem ((vyStS : string) (vyStI : int)) : string \"without_extension\"",
     "    (let (vyStA : bool) (prim int_lt vyStI 1 : (int * int) -> bool)",
     "    (if vyStA (return vyStS)",
     "      (let (vyStC : char) (prim string_sub vyStS vyStI : (string * int) -> char)",
     "      (let (vyStK : int) (prim char_ord vyStC : char -> int)",
     "      (let (vyStL : bool) (prim poly_eq vyStK 47 : (int * int) -> bool)",
     "      (if vyStL (return vyStS)",
     "        (let (vyStD : bool) (prim poly_eq vyStK 46 : (int * int) -> bool)",
     "        (if vyStD",
     "          (let (vyStN : int) (prim string_size vyStS : string -> int)",
     "          (let (vyStM : int) (prim int_sub vyStN 1 : (int * int) -> int)",
     "          (let (vyStE : bool) (prim int_lt vyStI vyStM : (int * int) -> bool)",
     "          (let (vyStJ : int) (prim int_sub vyStI 1 : (int * int) -> int)",
     "          (let (vyStB : char) (prim string_sub vyStS vyStJ : (string * int) -> char)",
     "          (let (vyStO : int) (prim char_ord vyStB : char -> int)",
     "          (let (vyStP : bool) (prim poly_eq vyStO 47 : (int * int) -> bool)",
     "          (if vyStP (return vyStS)",
     "          (if vyStE (return (prim string_extract vyStS 0 vyStI : (string * int * int) -> string))",
     "            (return vyStS))))))))))",
     "          (let (vyStR : int) (prim int_sub vyStI 1 : (int * int) -> int)",
     "          (return (app gsysStem vyStS vyStR))))))))))))",
     "  (fn gsysName ((vyNmU : unit)) : string \"command_name\"",
     "    (let (vyNmS : string) (prim command_name () : unit -> string)",
     "    (let (vyNmN : int) (prim string_size vyNmS : string -> int)",
     "    (let (vyNmI : int) (prim int_sub vyNmN 1 : (int * int) -> int)",
     "    (return (app gsysStem vyNmS vyNmI))))))",
     "  (fn gsysTimeNow ((vyTnU : unit)) : int \"time_now\"",
     "    (return (prim time_now () : unit -> int)))",
     "  (fn gsysTimeCpu ((vyTcU : unit)) : int \"time_cpu\"",
     "    (let (vyTcA : int) (prim time_user () : unit -> int)",
     "    (let (vyTcB : int) (prim time_sys () : unit -> int)",
     "    (return (prim int_add vyTcA vyTcB : (int * int) -> int)))))",
     "  (fn gsysDateOffset ((vyDoT : int)) : int \"date_offset\"",
     "    (return (prim date_offset vyDoT : int -> int)))",
     (* date_parts gives [] where it fails, which date_format refuses *)
     "  (fn gsysZoneName ((vyZnT : int)) : string \"date_zone_name\"",
     "    (let (vyZnL : int list) (prim date_parts vyZnT 1 : (int * int) -> int list)",
     "    (let (vyZnG : int) (tag vyZnL)",
     "    (let (vyZnE : bool) (prim poly_eq vyZnG 0 : (int * int) -> bool)",
     "    (if vyZnE (return \"\")",
     "      (return (prim date_format \"%Z\" vyZnL 1 : (string * int list * int) -> string)))))))",
     (* the ninth of date_parts: above 0 in summer time *)
     "  (fn gsysIsDst ((vyDsT : int)) : bool \"date_is_dst\"",
     "    (let (vyDsL : int list) (prim date_parts vyDsT 1 : (int * int) -> int list)",
     "    (let (vyDsD : int) (app gsysNthInt vyDsL 8)",
     "    (return (prim int_gt vyDsD 0 : (int * int) -> bool)))))",
     "  (fn gsysFold ((vyFoS : string) (vyFoI : int) (vyFoA : int)) : int \"fold_bytes\"",
     "    (let (vyFoN : int) (prim string_size vyFoS : string -> int)",
     "    (let (vyFoE : bool) (prim int_ge vyFoI vyFoN : (int * int) -> bool)",
     "    (if vyFoE (return vyFoA)",
     "      (let (vyFoC : char) (prim string_sub vyFoS vyFoI : (string * int) -> char)",
     "      (let (vyFoB : int) (prim char_ord vyFoC : char -> int)",
     "      (let (vyFoM : int) (prim int_mul vyFoA 256 : (int * int) -> int)",
     "      (let (vyFoR : int) (prim int_add vyFoM vyFoB : (int * int) -> int)",
     "      (let (vyFoJ : int) (prim int_add vyFoI 1 : (int * int) -> int)",
     "      (return (app gsysFold vyFoS vyFoJ vyFoR)))))))))))",
     "  (fn gsysRandomSeed ((vyRsU : unit)) : int \"random_seed\"",
     "    (let (vyRsB : string) (prim rt_random_bytes 7 : int -> string)",
     "    (let (vyRsN : int) (prim string_size vyRsB : string -> int)",
     "    (let (vyRsE : bool) (prim poly_eq vyRsN 0 : (int * int) -> bool)",
     "    (if vyRsE (return (prim time_now () : unit -> int))",
     "      (return (app gsysFold vyRsB 0 0))))))))\n"]

  val family : F.family = {name = "sys", prims = prims, midText = midText}
end

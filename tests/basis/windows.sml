(* requires: Windows OS Posix *)
(* uses: fn/posix_child.sml *)
(* Windows (signature WINDOWS). Expected values follow the text of
   https://smlfamily.github.io/Basis/windows.html.

   The structure is Windows' own, and a call of it that asks Windows raises
   OS.SysErr on any other system, where every check of such a call checks
   that. On Windows the registry is used under a key of its own in
   HKEY_CURRENT_USER\Software, which is deleted again; the programs are
   cmd.exe (COMSPEC). DDE, launchApplication and openDocument are checked
   only in what they refuse: the suite opens no windows and has no server
   of DDE to talk to. *)
structure TestWindows =
struct
  structure K = Windows.Key
  structure R = Windows.Reg
  structure C = Windows.Config
  structure S = Windows.Status
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  fun showW (w : SysWord.word) = "0wx" ^ SysWord.toString w
  val eqW = T.eq showW

  val onWindows = (ignore (C.getComputerName ()); true) handle OS.SysErr _ => false
  fun sysErr f = (ignore (f ()); false) handle OS.SysErr _ => true
  (* names in order *)
  fun sort (l : string list) = List.foldr (fn (x, acc) => let val (lo, hi) = List.partition (fn y => y < x) acc in lo @ x :: hi end) [] l
  (* on Windows what the call does, elsewhere that it raises OS.SysErr *)
  fun both (label, onWin : unit -> bool, call : unit -> 'a) =
    T.check (label, fn () => if onWindows then onWin () else sysErr call)

  (*<< key *)
  (* ---- Key: "allAccess: The union of the queryValue, enumerateSubKeys,
     notify, createSubKey, createLink, and setValue flags"; "read" and
     "write" are unions too, and "execute: Permission for read access". *)
  val () = eqB ("Windows.Key.allAccess/union", true,
                fn () => K.allAccess = K.flags [K.queryValue, K.enumerateSubKeys, K.notify,
                                                K.createSubKey, K.createLink, K.setValue])
  val () = eqB ("Windows.Key.read/union", true, fn () => K.read = K.flags [K.queryValue, K.enumerateSubKeys, K.notify])
  val () = eqB ("Windows.Key.write/union", true, fn () => K.write = K.flags [K.setValue, K.createSubKey])
  val () = eqB ("Windows.Key.execute/is-read", true, fn () => K.execute = K.read)
  val () = eqB ("Windows.Key.createLink/one-flag", true, fn () => K.toWord K.createLink = 0wx20)
  val () = eqB ("Windows.Key.createSubKey/one-flag", true, fn () => K.toWord K.createSubKey = 0wx4)
  val () = eqB ("Windows.Key.enumerateSubKeys/one-flag", true, fn () => K.toWord K.enumerateSubKeys = 0wx8)
  val () = eqB ("Windows.Key.notify/one-flag", true, fn () => K.toWord K.notify = 0wx10)
  val () = eqB ("Windows.Key.queryValue/one-flag", true, fn () => K.toWord K.queryValue = 0wx1)
  val () = eqB ("Windows.Key.setValue/one-flag", true, fn () => K.toWord K.setValue = 0wx2)
  (* BIT_FLAGS *)
  val () = eqB ("Windows.Key.all/allAccess", true, fn () => K.all = K.allAccess)
  val () = eqW ("Windows.Key.toWord/fromWord", 0wx6, fn () => K.toWord (K.fromWord 0wx6))
  val () = eqW ("Windows.Key.fromWord/masked", 0wx3F, fn () => K.toWord (K.fromWord 0wxFFFF))
  val () = eqW ("Windows.Key.flags/empty", 0wx0, fn () => K.toWord (K.flags []))
  val () = eqB ("Windows.Key.intersect/read-write", true, fn () => K.intersect [K.read, K.write] = K.flags [])
  val () = eqB ("Windows.Key.clear/read", true,
                fn () => K.clear (K.read, K.allAccess) = K.flags [K.createSubKey, K.createLink, K.setValue])
  val () = eqB ("Windows.Key.allSet/read", true, fn () => K.allSet (K.read, K.allAccess) andalso not (K.allSet (K.allAccess, K.read)))
  val () = eqB ("Windows.Key.anySet/read-write", false, fn () => K.anySet (K.read, K.write))
  (*>> key *)

  (*<< registry *)
  (* ---- Reg: a key of the test's own under HKEY_CURRENT_USER\Software,
     beside those of runs on other VMs at the same time, not under a parent
     they share, which one could delete while another makes its key there *)
  val name = "Software\\RuneBasisSuite-" ^ SysWord.fmt StringCvt.DEC (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  fun withKey f =
    let
      val key = case R.createKeyEx (R.currentUser, name, K.allAccess) of
                  R.CREATED_NEW_KEY k => k
                | R.OPENED_EXISTING_KEY k => k
      fun cleanUp () =
        (R.closeKey key;
         R.deleteKey (R.currentUser, name) handle OS.SysErr _ => ())
    in
      (f key before cleanUp ()) handle e => (cleanUp (); raise e)
    end
  (* the roots are seven keys, all different *)
  val roots = [R.classesRoot, R.currentUser, R.localMachine, R.users, R.performanceData, R.currentConfig, R.dynData]
  fun alone r = List.length (List.filter (fn s => s = r) roots) = 1
  val () = eqB ("Windows.Reg.hkey/roots-differ", true, fn () => List.all alone roots)
  val () = eqB ("Windows.Reg.classesRoot/its-own", true, fn () => alone R.classesRoot)
  val () = eqB ("Windows.Reg.currentUser/its-own", true, fn () => alone R.currentUser)
  val () = eqB ("Windows.Reg.localMachine/its-own", true, fn () => alone R.localMachine)
  val () = eqB ("Windows.Reg.users/its-own", true, fn () => alone R.users)
  val () = eqB ("Windows.Reg.performanceData/its-own", true, fn () => alone R.performanceData)
  val () = eqB ("Windows.Reg.currentConfig/its-own", true, fn () => alone R.currentConfig)
  val () = eqB ("Windows.Reg.dynData/its-own", true, fn () => alone R.dynData)
  val () = both ("Windows.Reg.createKeyEx/new-then-existing",
                 fn () => withKey (fn _ =>
                            case R.createKeyEx (R.currentUser, name, K.read) of
                              R.OPENED_EXISTING_KEY k => (R.closeKey k; true)
                            | R.CREATED_NEW_KEY k => (R.closeKey k; false)),
                 fn () => R.createKeyEx (R.currentUser, name, K.read))
  val () = both ("Windows.Reg.CREATED_NEW_KEY/fresh-name",
                 fn () => withKey (fn key =>
                            case R.createKeyEx (key, "sub", K.allAccess) of
                              R.CREATED_NEW_KEY k => (R.closeKey k; R.deleteKey (key, "sub"); true)
                            | R.OPENED_EXISTING_KEY k => (R.closeKey k; R.deleteKey (key, "sub"); false)),
                 fn () => R.createKeyEx (R.currentUser, name, K.read))
  val () = both ("Windows.Reg.OPENED_EXISTING_KEY/software",
                 fn () => case R.createKeyEx (R.currentUser, "Software", K.read) of
                            R.OPENED_EXISTING_KEY k => (R.closeKey k; true)
                          | R.CREATED_NEW_KEY k => (R.closeKey k; false),
                 fn () => R.createKeyEx (R.currentUser, "Software", K.read))
  val () = both ("Windows.Reg.openKeyEx/missing-raises",
                 fn () => sysErr (fn () => R.openKeyEx (R.currentUser, name ^ "\\no-such-key", K.read)),
                 fn () => R.openKeyEx (R.currentUser, "Software", K.read))
  val () = both ("Windows.Reg.openKeyEx/closeKey",
                 fn () => let val k = R.openKeyEx (R.currentUser, "Software", K.read) in R.closeKey k; true end,
                 fn () => R.openKeyEx (R.currentUser, "Software", K.read))
  val () = both ("Windows.Reg.closeKey/twice-raises",
                 fn () => let val k = R.openKeyEx (R.currentUser, "Software", K.read)
                          in R.closeKey k; sysErr (fn () => R.closeKey k) end,
                 fn () => R.closeKey R.currentUser)
  val () = both ("Windows.Reg.setValueEx/SZ",
                 fn () => withKey (fn key => (R.setValueEx (key, "s", R.SZ "hello");
                                              R.queryValueEx (key, "s") = SOME (R.SZ "hello"))),
                 fn () => R.setValueEx (R.currentUser, "s", R.SZ "x"))
  val () = both ("Windows.Reg.DWORD/round-trip",
                 fn () => withKey (fn key => (R.setValueEx (key, "d", R.DWORD 0wxDEADBEEF);
                                              R.queryValueEx (key, "d") = SOME (R.DWORD 0wxDEADBEEF))),
                 fn () => R.queryValueEx (R.currentUser, "d"))
  val () = both ("Windows.Reg.BINARY/round-trip",
                 fn () => withKey (fn key =>
                            let val v = Word8Vector.fromList (List.map Word8.fromInt [0, 1, 128, 255])
                            in R.setValueEx (key, "b", R.BINARY v); R.queryValueEx (key, "b") = SOME (R.BINARY v) end),
                 fn () => R.queryValueEx (R.currentUser, "b"))
  val () = both ("Windows.Reg.MULTI_SZ/round-trip",
                 fn () => withKey (fn key => (R.setValueEx (key, "m", R.MULTI_SZ ["a", "bc", "def"]);
                                              R.queryValueEx (key, "m") = SOME (R.MULTI_SZ ["a", "bc", "def"]))),
                 fn () => R.queryValueEx (R.currentUser, "m"))
  val () = both ("Windows.Reg.EXPAND_SZ/round-trip",
                 fn () => withKey (fn key => (R.setValueEx (key, "e", R.EXPAND_SZ "%TEMP%\\x");
                                              R.queryValueEx (key, "e") = SOME (R.EXPAND_SZ "%TEMP%\\x"))),
                 fn () => R.queryValueEx (R.currentUser, "e"))
  (* "If the value does not exist in the key, the function returns NONE." *)
  val () = both ("Windows.Reg.queryValueEx/missing-is-NONE",
                 fn () => withKey (fn key => R.queryValueEx (key, "no-such-value") = NONE),
                 fn () => R.queryValueEx (R.currentUser, "no-such-value"))
  val () = both ("Windows.Reg.deleteValue/gone",
                 fn () => withKey (fn key => (R.setValueEx (key, "v", R.SZ "x"); R.deleteValue (key, "v");
                                              R.queryValueEx (key, "v") = NONE)),
                 fn () => R.deleteValue (R.currentUser, "v"))
  val () = both ("Windows.Reg.deleteKey/gone",
                 fn () => withKey (fn key =>
                            (case R.createKeyEx (key, "gone", K.allAccess) of
                               R.CREATED_NEW_KEY k => R.closeKey k
                             | R.OPENED_EXISTING_KEY k => R.closeKey k;
                             R.deleteKey (key, "gone");
                             sysErr (fn () => R.openKeyEx (key, "gone", K.read)))),
                 fn () => R.deleteKey (R.currentUser, "gone"))
  (* "To enumerate all the subkeys, start with the index at zero and
     increment it until the function returns NONE." *)
  val () = both ("Windows.Reg.enumKeyEx/all-then-NONE",
                 fn () => withKey (fn key =>
                            let
                              fun make n = case R.createKeyEx (key, n, K.allAccess) of
                                             R.CREATED_NEW_KEY k => R.closeKey k
                                           | R.OPENED_EXISTING_KEY k => R.closeKey k
                              val () = List.app make ["k1", "k2"]
                              fun names i = case R.enumKeyEx (key, i) of NONE => [] | SOME n => n :: names (i + 1)
                              val found = sort (names 0)
                            in List.app (fn n => R.deleteKey (key, n)) ["k1", "k2"]; found = ["k1", "k2"] end),
                 fn () => R.enumKeyEx (R.currentUser, 0))
  val () = both ("Windows.Reg.enumValueEx/all-then-NONE",
                 fn () => withKey (fn key =>
                            (R.setValueEx (key, "v1", R.SZ "1"); R.setValueEx (key, "v2", R.DWORD 0w2);
                             let fun names i = case R.enumValueEx (key, i) of NONE => [] | SOME n => n :: names (i + 1)
                             in sort (names 0) = ["v1", "v2"] end)),
                 fn () => R.enumValueEx (R.currentUser, 0))
  (* "The function raises the Subscript exception if ind is invalid." *)
  val () = T.raises ("Windows.Reg.enumKeyEx/negative-is-Subscript", T.isSubscript, fn () => R.enumKeyEx (R.currentUser, ~1))
  val () = T.raises ("Windows.Reg.enumValueEx/negative-is-Subscript", T.isSubscript, fn () => R.enumValueEx (R.currentUser, ~1))
  (*>> registry *)

  (*<< config *)
  (* ---- Config *)
  val () = eqB ("Windows.Config.platformWin32s/values", true,
                fn () => [C.platformWin32s, C.platformWin32Windows, C.platformWin32NT, C.platformWin32CE] = [0w0, 0w1, 0w2, 0w3])
  val () = eqB ("Windows.Config.platformWin32Windows/distinct", true, fn () => C.platformWin32Windows <> C.platformWin32NT)
  val () = eqB ("Windows.Config.platformWin32NT/distinct", true, fn () => C.platformWin32NT <> C.platformWin32CE)
  val () = eqB ("Windows.Config.platformWin32CE/distinct", true, fn () => C.platformWin32CE <> C.platformWin32s)
  (* every Windows of today is NT, from version 6 on *)
  val () = both ("Windows.Config.getVersionEx/is-NT",
                 fn () => let val v = C.getVersionEx ()
                          in #platformId v = C.platformWin32NT andalso #majorVersion v >= 0w6 andalso #buildNumber v > 0w0 end,
                 C.getVersionEx)
  (* the directory of Windows holds its system directory *)
  val () = both ("Windows.Config.getWindowsDirectory/holds-the-system-directory",
                 fn () => String.isPrefix (String.map Char.toUpper (C.getWindowsDirectory ()))
                                          (String.map Char.toUpper (C.getSystemDirectory ())),
                 C.getWindowsDirectory)
  val () = both ("Windows.Config.getSystemDirectory/is-a-directory",
                 fn () => OS.FileSys.isDir (C.getSystemDirectory ()), C.getSystemDirectory)
  val () = both ("Windows.Config.getComputerName/the-node",
                 fn () => let val node = #2 (valOf (List.find (fn (k, _) => k = "nodename") (Posix.ProcEnv.uname ())))
                          in String.map Char.toUpper (C.getComputerName ()) = String.map Char.toUpper node end,
                 C.getComputerName)
  val () = both ("Windows.Config.getUserName/the-login",
                 fn () => C.getUserName () = Posix.ProcEnv.getlogin (), C.getUserName)
  (*>> config *)

  (*<< dde *)
  (* ---- DDE: no service answers to a name made up here *)
  val () = T.raises ("Windows.DDE.startDialog/no-such-service-raises", fn OS.SysErr _ => true | _ => false,
                     fn () => Windows.DDE.startDialog ("RuneBasisSuiteNoSuchService", "nothing"))
  val () = eqB ("Windows.DDE.executeString/no-dialog-raises", true,
                fn () => sysErr (fn () => Windows.DDE.executeString (Windows.DDE.startDialog ("RuneBasisSuiteNoSuchService", "x"),
                                                                     "[]", 0, PosixChild.ms 10)))
  val () = eqB ("Windows.DDE.stopDialog/no-dialog-raises", true,
                fn () => sysErr (fn () => Windows.DDE.stopDialog (Windows.DDE.startDialog ("RuneBasisSuiteNoSuchService", "x"))))
  (*>> dde *)

  (*<< files *)
  (* ---- the volume of the drive the system is on, and the programs *)
  fun systemDrive () = String.substring (C.getSystemDirectory (), 0, 3)
  val () = both ("Windows.getVolumeInformation/system-drive",
                 fn () => let val v = Windows.getVolumeInformation (systemDrive ())
                          in #systemName v <> "" andalso #maximumComponentLength v >= 255 end,
                 fn () => Windows.getVolumeInformation "C:\\")
  (* the root as OS.FileSys writes the paths of a drive, /C:/ *)
  val () = both ("Windows.getVolumeInformation/root-as-OS.FileSys-writes-it",
                 fn () => let val d = systemDrive ()
                          in #serialNumber (Windows.getVolumeInformation ("/" ^ String.substring (d, 0, 2) ^ "/"))
                             = #serialNumber (Windows.getVolumeInformation d) end,
                 fn () => Windows.getVolumeInformation "/C:/")
  val () = both ("Windows.findExecutable/a-program-is-its-own",
                 fn () => isSome (Windows.findExecutable (C.getSystemDirectory () ^ "\\cmd.exe")),
                 fn () => Windows.findExecutable "C:\\Windows\\System32\\cmd.exe")
  val () = both ("Windows.findExecutable/missing-is-NONE",
                 fn () => Windows.findExecutable (C.getSystemDirectory () ^ "\\rune-no-such-file.txt") = NONE,
                 fn () => Windows.findExecutable "C:\\rune-no-such-file.txt")
  val () = T.raises ("Windows.launchApplication/missing-raises", fn OS.SysErr _ => true | _ => false,
                     fn () => Windows.launchApplication ("C:\\rune-no-such-program.exe", ""))
  val () = T.raises ("Windows.openDocument/missing-raises", fn OS.SysErr _ => true | _ => false,
                     fn () => Windows.openDocument "C:\\rune-no-such-document.txt")
  (*>> files *)

  (*<< processes *)
  (* ---- programs: cmd.exe *)
  fun cmd () = valOf (OS.Process.getEnv "COMSPEC")
  fun lines s = String.translate (fn #"\r" => "" | c => String.str c) s
  val () = both ("Windows.simpleExecute/status",
                 fn () => Windows.fromStatus (Windows.simpleExecute (cmd (), "/d /c exit 3")) = 0w3,
                 fn () => Windows.simpleExecute ("cmd.exe", "/c exit 3"))
  val () = both ("Windows.textInstreamOf/output-of-the-program",
                 fn () => let val p = Windows.execute (cmd (), "/d /c echo hello")
                              val s = lines (TextIO.inputAll (Windows.textInstreamOf p))
                          in Windows.reap p = OS.Process.success andalso s = "hello\n" end,
                 fn () => Windows.execute ("cmd.exe", "/c echo hello"))
  val () = both ("Windows.textOutstreamOf/to-the-program",
                 fn () => let val p = Windows.execute (cmd (), "/d /v:on /c set /p x=& echo got [!x!]")
                              val out = Windows.textOutstreamOf p
                              val () = (TextIO.output (out, "yes\n"); TextIO.closeOut out)
                              val s = lines (TextIO.inputAll (Windows.textInstreamOf p))
                          in ignore (Windows.reap p); s = "got [yes]\n" end,
                 fn () => Windows.execute ("cmd.exe", "/c echo"))
  val () = both ("Windows.binInstreamOf/bytes",
                 fn () => let val p = Windows.execute (cmd (), "/d /c echo ab")
                              val v = BinIO.inputAll (Windows.binInstreamOf p)
                          in ignore (Windows.reap p); Byte.bytesToString v = "ab\r\n" end,
                 fn () => Windows.execute ("cmd.exe", "/c echo ab"))
  val () = both ("Windows.binOutstreamOf/to-the-program",
                 fn () => let val p = Windows.execute (cmd (), "/d /v:on /c set /p x=& echo got [!x!]")
                              val out = Windows.binOutstreamOf p
                              val () = (BinIO.output (out, Byte.stringToBytes "bin\n"); BinIO.closeOut out)
                              val s = lines (TextIO.inputAll (Windows.textInstreamOf p))
                          in ignore (Windows.reap p); s = "got [bin]\n" end,
                 fn () => Windows.execute ("cmd.exe", "/c echo"))
  (* "If reap is applied again to pr, it should immediately return the
     previous exit status." *)
  val () = both ("Windows.reap/twice-same-status",
                 fn () => let val p = Windows.execute (cmd (), "/d /c exit 5")
                              val a = Windows.reap p
                          in a = Windows.reap p andalso Windows.fromStatus a = 0w5 end,
                 fn () => Windows.execute ("cmd.exe", "/c exit 5"))
  val () = T.raises ("Windows.execute/missing-program-raises", fn OS.SysErr _ => true | _ => false,
                     fn () => Windows.execute ("C:\\rune-no-such-program.exe", ""))
  (*>> processes *)

  (*<< status *)
  (* ---- Status: the codes of Windows (ntstatus.h) *)
  val () = eqW ("Windows.Status.accessViolation/value", 0wxC0000005, fn () => S.accessViolation)
  val () = eqW ("Windows.Status.arrayBoundsExceeded/value", 0wxC000008C, fn () => S.arrayBoundsExceeded)
  val () = eqW ("Windows.Status.breakpoint/value", 0wx80000003, fn () => S.breakpoint)
  val () = eqW ("Windows.Status.controlCExit/value", 0wxC000013A, fn () => S.controlCExit)
  val () = eqW ("Windows.Status.datatypeMisalignment/value", 0wx80000002, fn () => S.datatypeMisalignment)
  val () = eqW ("Windows.Status.floatDenormalOperand/value", 0wxC000008D, fn () => S.floatDenormalOperand)
  val () = eqW ("Windows.Status.floatDivideByZero/value", 0wxC000008E, fn () => S.floatDivideByZero)
  val () = eqW ("Windows.Status.floatInexactResult/value", 0wxC000008F, fn () => S.floatInexactResult)
  val () = eqW ("Windows.Status.floatInvalidOperation/value", 0wxC0000090, fn () => S.floatInvalidOperation)
  val () = eqW ("Windows.Status.floatOverflow/value", 0wxC0000091, fn () => S.floatOverflow)
  val () = eqW ("Windows.Status.floatStackCheck/value", 0wxC0000092, fn () => S.floatStackCheck)
  val () = eqW ("Windows.Status.floatUnderflow/value", 0wxC0000093, fn () => S.floatUnderflow)
  val () = eqW ("Windows.Status.guardPageViolation/value", 0wx80000001, fn () => S.guardPageViolation)
  val () = eqW ("Windows.Status.integerDivideByZero/value", 0wxC0000094, fn () => S.integerDivideByZero)
  val () = eqW ("Windows.Status.integerOverflow/value", 0wxC0000095, fn () => S.integerOverflow)
  val () = eqW ("Windows.Status.illegalInstruction/value", 0wxC000001D, fn () => S.illegalInstruction)
  val () = eqW ("Windows.Status.invalidDisposition/value", 0wxC0000026, fn () => S.invalidDisposition)
  val () = eqW ("Windows.Status.invalidHandle/value", 0wxC0000008, fn () => S.invalidHandle)
  val () = eqW ("Windows.Status.inPageError/value", 0wxC0000006, fn () => S.inPageError)
  val () = eqW ("Windows.Status.noncontinuableException/value", 0wxC0000025, fn () => S.noncontinuableException)
  val () = eqW ("Windows.Status.pending/value", 0wx103, fn () => S.pending)
  val () = eqW ("Windows.Status.privilegedInstruction/value", 0wxC0000096, fn () => S.privilegedInstruction)
  val () = eqW ("Windows.Status.singleStep/value", 0wx80000004, fn () => S.singleStep)
  val () = eqW ("Windows.Status.stackOverflow/value", 0wxC00000FD, fn () => S.stackOverflow)
  val () = eqW ("Windows.Status.timeout/value", 0wx102, fn () => S.timeout)
  val () = eqW ("Windows.Status.userAPC/value", 0wxC0, fn () => S.userAPC)
  val () = eqW ("Windows.fromStatus/success", 0wx0, fn () => Windows.fromStatus OS.Process.success)
  val () = eqB ("Windows.fromStatus/failure-is-not-success", true, fn () => Windows.fromStatus OS.Process.failure <> 0w0)
  (* exit ends the process with the code: in a child made by fork, waited
     for 5 seconds at most, since on some hosts such a child never ends *)
  val () = T.eq (T.option PosixChild.showStatus)
                ("Windows.exit/code", SOME (Posix.Process.W_EXITSTATUS (PosixChild.w8 7)),
                 fn () => PosixChild.waitBounded (PosixChild.fork (fn () => Windows.exit 0w7)))
  (*>> status *)
end

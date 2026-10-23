(* Acceptance coordination stays in SML. C compilers and native processes
   are independent subjects, bounded by Children and the outer runner. *)
structure FfiChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok, message) = if ok then () else raise Failed message
  fun field name value = case Json.member (name, value) of SOME v => v
    | NONE => raise Failed ("missing manifest member " ^ name)
  fun string (Json.String s) = s | string _ = raise Failed "expected string"
  fun array (Json.Array xs) = xs | array _ = raise Failed "expected array"
  fun json path = Json.decode (read (fromRoot path))
  fun source base manifest =
    let val files = array (field "files" manifest)
        fun one v =
          let val path = string (field "path" v)
              val () = need (not (OS.Path.isAbsolute path) andalso
                not (List.exists (fn s => s = "..") (String.fields (fn c => c = #"/") path)), "unsafe source path")
              val file = base ^ "/" ^ path
              val () = need (exists file, "missing original source " ^ path)
          in need (Hex.fromBytes (Sha256.digest (read file)) = string (field "sha256" v),
                   "original source hash differs: " ^ path) end
    in List.app one files; say ("PASS ffi/sources: " ^ Int.toString (length files) ^ " original files\n") end
  fun inventories () =
    let fun one (kind, count) =
          let val entries = array (field "entries" (json ("ffi/" ^ kind ^ "/inventory.json")))
              val names = List.map (string o field "foreign") entries
              fun unique [] = true | unique (x :: xs) = not (List.exists (fn y => x = y) xs) andalso unique xs
              val () = need (length names = count andalso unique names, "incomplete or duplicate " ^ kind ^ " inventory")
              val () = List.app (fn v =>
                (ignore (string (field "public" v)); ignore (field "source" v);
                 need (not (null (array (field "unresolved" v))) orelse string (field "implementation" v) = "complete",
                       "unreviewed policy lost its blocker"))) entries
          in say ("PASS ffi/inventory: " ^ kind ^ " " ^ Int.toString count ^ " declarations\n") end
        val requirements = array (field "requirements" (json "ffi/requirements.json"))
        val ids = List.map (string o field "id") requirements
        fun unique [] = true | unique (x :: xs) = not (List.exists (fn y => x = y) xs) andalso unique xs
        val () = need (unique ids, "duplicate requirement owner")
        val () = List.app (fn r => need (not (null (array (field "milestones" r))) andalso
          not (null (array (field "acceptanceOwners" r))), "requirement has no delivery/test owner")) requirements
        val () = List.app (fn n => need (List.exists (fn r => List.exists
          (fn m => string m = "M" ^ Int.toString n) (array (field "milestones" r))) requirements,
          "milestone has no requirement owner")) (List.tabulate (11, fn n => n))
        val sdl = array (field "entries" (json "ffi/sdl/inventory.json"))
        val () = need (not (List.exists (fn entry => string (field "foreign" entry) = "SDL_RunApp") sdl),
          "deferred SDL application-entry integration was selected")
    in one ("sdl", 53); one ("win32", 38);
       say ("PASS ffi/requirements: " ^ Int.toString (length ids) ^ " delivery/test owners\n") end
  val directory = run ^ "/ffi/" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  fun command name args =
    let val () = mkdirs directory
        val output = directory ^ "/" ^ name ^ ".out"
        val errors = directory ^ "/" ^ name ^ ".err"
        val start = Runtime.clock ()
        val status = Children.exec Subprocess.unlimited (fn e => e)
          {cmd = args, dir = SOME root, stdin = "", stdout = output, stderr = errors, timeout = 600}
        val seconds = Time.toString (Time.- (Runtime.clock (), start))
        val () = need (status = 0, name ^ " exited " ^ Int.toString status ^ ": " ^ read errors ^ read output)
    in say ("PASS ffi/" ^ name ^ " (" ^ seconds ^ "s)\n"); read output end
  fun compiler name = String.tokens Char.isSpace (env (name, if name = "CC" then "cc" else
    if name = "WINCC" then "x86_64-w64-mingw32-gcc" else "i686-w64-mingw32-gcc"))
  val flags = ["-std=c17", "-Wall", "-Wextra", "-Werror", "-pedantic", "-Itests/ffi"]
  fun layout profile output =
    let val actual = Json.decode (hd (lines (String.translate (fn #"\r" => "" | c => str c) output)))
        val target = json ("ffi/targets/" ^ profile ^ ".json")
        val widths = field "widths" target
        val expected = [("byteOrder", field "byteOrder" target), ("charSigned", field "charSigned" target)]
          @ List.map (fn n => (n, field n widths)) ["char", "short", "int", "long", "longLong", "pointer", "size", "wchar"]
          @ [("doubleAlign", field "double" (field "alignments" target)),
             ("pairSize", Json.int 16), ("pairAlign", Json.int 8), ("pairFraction", Json.int 8)]
    in List.app (fn (n, v) => need (field n actual = v, profile ^ " ABI mismatch: " ^ n)) expected;
       say ("PASS ffi/layout: " ^ profile ^ "\n") end
  fun contracts () =
    let val output = directory ^ "/contracts.rbc"
        val compiler = env ("RUNE", "bin/rune")
        fun one target vm =
          (ignore (command ("compile-" ^ target) [compiler, "--target=" ^ target,
                    "--build", "tests/ffi/contracts.build", "-o", output]);
           need (command ("contracts-" ^ target) [vm, output] =
             "PASS ffi/contracts: creation, paint cleanup, messages, timers, objects, destruction\n", "contract trace differs"))
    in one "registers" "bin/runevm"; one "stack" "bin/runevm-stack" end
  fun native withLibffi =
    let val executable = directory ^ "/oracle"
        val () = ignore (command "compile-c" (compiler "CC" @ flags @
          ["tests/ffi/fixture.c", "tests/ffi/oracle.c", "-o", executable]))
        val () = layout "linux-x86_64" (command "oracle-c" [executable])
        val () = if not withLibffi then () else
          let val ffiFlags = String.tokens Char.isSpace (command "pkg-config" ["pkg-config", "--cflags", "--libs", "libffi"])
              val () = ignore (command "compile-libffi" (compiler "CC" @ flags @
                ["-DRUNEFFI_TEST_LIBFFI", "tests/ffi/fixture.c", "tests/ffi/oracle.c", "-o", executable ^ "-ffi"] @ ffiFlags))
          in layout "linux-x86_64" (command "oracle-libffi" [executable ^ "-ffi"]) end
    in () end
  fun windows bits =
    let val cc = compiler (if bits = "64" then "WINCC" else "WINCC32")
        val executable = directory ^ "/oracle" ^ bits ^ ".exe"
        val gui = directory ^ "/gui" ^ bits ^ ".exe"
        val () = ignore (command ("compile-win" ^ bits) (cc @ flags @
          ["tests/ffi/fixture.c", "tests/ffi/oracle.c", "-o", executable]))
        val () = ignore (command ("compile-gui" ^ bits) (cc @ flags @
          ["tests/ffi/win32_oracle.c", "-luser32", "-lgdi32", "-o", gui]))
        val () = layout (if bits = "64" then "windows-x86_64" else "windows-x86")
          (command ("oracle-win" ^ bits) [executable])
    in ignore (command ("oracle-gui" ^ bits) [gui]) end
  fun runtime mode =
    let val ()=need(List.exists(fn value=>value=mode)["native","asan","windows32","windows64"],"unknown runtime mode")
        val compilerRune = env ("RUNE", "bin/rune")
        val library = directory ^ "/subject.so"
        val bytecode = directory ^ "/calls"
        fun compile target source output = ignore(command ("compile-" ^ target ^ "-" ^ OS.Path.file source)
          ([compilerRune,"--target=" ^ target] @ (if (source="tests/ffi/memory.sml" orelse source="tests/ffi/owner.sml") then ["--library","ffi/runtime"] else []) @ [source,"-o",output]))
        fun calls vm options output subject =
          need(String.isSubstring "PASS foreign calls:" (command (OS.Path.file vm ^ "-calls")
            (vm :: options @ [output,subject])),"foreign call fixture did not finish")
        fun callbacks vm options output subject =
          need(String.isSubstring "PASS foreign callbacks:" (command (OS.Path.file vm ^ "-callbacks")
            (vm :: options @ [output,subject])),"foreign callback fixture did not finish")
        fun memory vm options output subject =
          need(String.isSubstring "PASS native memory marshalling:" (command (OS.Path.file vm ^ "-memory")
            (vm :: options @ [output,subject])),"native memory fixture did not finish")
        fun owner vm options output subject =
          need(String.isSubstring "PASS explicit native owners:" (command (OS.Path.file vm ^ "-owner")
            (vm :: options @ [output,subject])),"native owner fixture did not finish")
        fun lifecycle vm output =
          let val image=output ^ ".image"
          in need(String.isSubstring "saved closed state" (command "save-closed" [vm,output,library,image]),"save fixture");
             need(String.isSubstring "restored closed state" (command "restore-closed" [vm,"--restore",image]),"restore fixture") end
        val disabled = directory ^ "/disabled-c"
        val () = ignore(command "compile-disabled-c" (compiler "CC" @ flags @ ["-Iruntime",
          "tests/runtime/foreign_disabled.c","runtime/foreign.c","-o",disabled]))
        val () = ignore(command "disabled-c" [disabled])
    in if not(RuneForeign.available()) then
         let val output=bytecode ^ "-disabled.rbc"
             val ()=compile "registers" "tests/ffi/disabled.sml" output
         in ignore(command "disabled-sml" ["bin/runevm",output]) end
       else if mode="windows32" orelse mode="windows64" then
         let val bits=if mode="windows32" then "32" else "64"
             val cc=compiler(if bits="32" then "WINCC32" else "WINCC")
             val dll=directory ^ "/subject" ^ bits ^ ".dll"
             val ()=ignore(command "compile-dll" (cc @ flags @ ["-shared","-Wl,--kill-at","tests/ffi/fixture.c","tests/ffi/ownership.c","tests/ffi/callback-fixture.c","-o",dll]))
             fun winpath path=String.translate (fn #"\r" => "" | #"\n" => "" | c => str c) (command "windows-path" ["wslpath","-w",fromRoot path])
             val subject=winpath dll
             fun one(target,vm)=
               let val output=bytecode ^ target ^ ".rbc"
                   val ()=compile target "tests/ffi/calls.sml" output
                   val bufferOutput=bytecode ^ target ^ "-memory.rbc"
                   val ()=compile target "tests/ffi/memory.sml" bufferOutput
                   val ownerOutput=bytecode ^ target ^ "-owner.rbc"
                   val ()=compile target "tests/ffi/owner.sml" ownerOutput
                   val callbackOutput=bytecode ^ target ^ "-callbacks.rbc"
                   val ()=compile target "tests/ffi/callbacks.sml" callbackOutput
               in owner vm ["--gc-stress","7","--gc-verify"] (winpath ownerOutput) subject;
                  callbacks vm ["--gc-stress","7","--gc-verify"] (winpath callbackOutput) subject;
                  calls vm ["--gc-stress","7","--gc-verify"] (winpath output) subject;
                  memory vm ["--gc-stress","7","--gc-verify"] (winpath bufferOutput) subject end
         in one("stack",if bits="32" then "bin/runevm-stack32.exe" else "bin/runevm-stack.exe");
            one("registers",if bits="32" then "bin/runevm32.exe" else "bin/runevm.exe") end
       else
         let val ()=ignore(command "compile-subject" (compiler "CC" @ flags @ ["-shared","-fPIC","tests/ffi/fixture.c","tests/ffi/ownership.c","tests/ffi/callback-fixture.c","-pthread","-o",library]))
             val ffiFlags=String.tokens Char.isSpace(command "runtime-pkg-config" ["pkg-config","--cflags","--libs","libffi"])
             val unit=directory ^ "/unit"
             val sanitize=if mode="asan" then ["-fsanitize=address,undefined","-fno-omit-frame-pointer"] else []
             val ()=ignore(command "compile-runtime-unit" (compiler "CC" @ flags @ sanitize @
               ["-DRUNE_FFI=1","-Iruntime","tests/runtime/foreign_test.c","runtime/foreign.c","runtime/sys/sys_posix.c",
                "-Wl,--wrap=calloc","-Wl,--wrap=realloc","-o",unit,"-ldl","-lm"] @ ffiFlags))
             val ()=ignore(command "runtime-unit" [unit,library])
             val disposal=directory ^ "/disposal-unit"
             val ()=ignore(command "compile-disposal-unit" (compiler "CC" @ flags @ sanitize @
               ["-DRUNE_FFI=1","-Iruntime","tests/runtime/foreign_dispose_test.c","runtime/foreign.c","runtime/sys/sys_posix.c",
                "-Wl,--wrap=calloc","-Wl,--wrap=realloc","-o",disposal,"-ldl","-lm"] @ ffiFlags))
             val ()=ignore(command "disposal-unit" [disposal,library])
             val callbackUnit=directory ^ "/callback-unit"
             val ()=ignore(command "compile-callback-unit" (compiler "CC" @ flags @ sanitize @
               ["-DRUNE_FFI=1","-Iruntime","tests/runtime/foreign_callback_test.c","runtime/foreign.c","runtime/sys/sys_posix.c",
                "-Wl,--wrap=calloc","-o",callbackUnit,"-ldl","-lm"] @ ffiFlags))
             val ()=ignore(command "callback-unit" [callbackUnit,library])
             val shutdownLibrary=directory ^ "/shutdown-provider.so"
             val ()=ignore(command "compile-shutdown-provider" (compiler "CC" @ flags @ sanitize @
               ["-shared","-fPIC","tests/runtime/foreign_shutdown_fixture.c","-o",shutdownLibrary]))
             val shutdownUnit=directory ^ "/shutdown-unit"
             val ()=ignore(command "compile-shutdown-unit" (compiler "CC" @ flags @ sanitize @
               ["-DRUNE_FFI=1","-Iruntime","tests/runtime/foreign_shutdown_test.c","runtime/foreign.c","runtime/sys/sys_posix.c",
                "-pthread","-o",shutdownUnit,"-ldl","-lm"] @ ffiFlags))
             val ()=ignore(command "shutdown-unit" [shutdownUnit,shutdownLibrary])
             fun one(target,vm,options)=
               let val output=bytecode ^ target ^ ".rbc"
                   val ()=compile target "tests/ffi/calls.sml" output
                   val ()=calls vm (options @ ["--gc-stress","7","--gc-verify"]) output library
                   val bufferOutput=bytecode ^ target ^ "-memory.rbc"
                   val ()=compile target "tests/ffi/memory.sml" bufferOutput
                   val ()=memory vm (options @ ["--gc-stress","7","--gc-verify"]) bufferOutput library
                   val ownerOutput=bytecode ^ target ^ "-owner.rbc"
                   val ()=compile target "tests/ffi/owner.sml" ownerOutput
                   val ()=owner vm (options @ ["--gc-stress","7","--gc-verify"]) ownerOutput library
                   val callbackOutput=bytecode ^ target ^ "-callbacks.rbc"
                   val ()=compile target "tests/ffi/callbacks.sml" callbackOutput
                   val ()=callbacks vm (options @ ["--gc-stress","7","--gc-verify"]) callbackOutput library
                   val life=bytecode ^ target ^ "-life.rbc"
               in if mode="asan" then () else
                    (compile target "tests/ffi/lifecycle.sml" life;lifecycle vm life;
                     compile target "tests/ffi/shutdown-exit.sml" (bytecode ^ target ^ "-shutdown.rbc");
                     ignore(command ("shutdown-exit-" ^ target) [vm,bytecode ^ target ^ "-shutdown.rbc",shutdownLibrary])) end
         in if mode="asan" then
              (one("stack","bin/runevm-stack-asan",[]);one("registers","bin/runevm-asan",["--jit=all","--jit-tier=2"]))
            else (one("stack","bin/runevm-stack",[]);
                  one("registers","bin/runevm",[]);
                  List.app(fn options=>calls "bin/runevm" (options @ ["--gc-stress","7","--gc-verify"])
                    (bytecode ^ "registers.rbc") library) [["--jit=all"],["--jit=all","--jit-tier=2"]];
                  List.app(fn options=>memory "bin/runevm" (options @ ["--gc-stress","7","--gc-verify"])
                    (bytecode ^ "registers-memory.rbc") library) [["--jit=all"],["--jit=all","--jit-tier=2"]];
                  List.app(fn options=>owner "bin/runevm" (options @ ["--gc-stress","7","--gc-verify"])
                    (bytecode ^ "registers-owner.rbc") library) [["--jit=all"],["--jit=all","--jit-tier=2"]];
                  List.app(fn options=>callbacks "bin/runevm" (options @ ["--gc-stress","7","--gc-verify"])
                    (bytecode ^ "registers-callbacks.rbc") library) [["--jit=all"],["--jit=all","--jit-tier=2"]];
                  ignore(command "shutdown-exit-jit" ["bin/runevm","--jit=all","--jit-tier=2",bytecode ^ "registers-shutdown.rbc",shutdownLibrary]);
                  ignore(command "compile-native-shutdown" ["bin/runeopt",bytecode ^ "stack-shutdown.rbc","-o",bytecode ^ "-native-shutdown"]);
                  ignore(command "native-shutdown" [bytecode ^ "-native-shutdown",shutdownLibrary]);
                  ignore(command "compile-native-callbacks" ["bin/runeopt",bytecode ^ "stack-callbacks.rbc","-o",bytecode ^ "-native-callbacks"]);
                  need(String.isSubstring "PASS foreign callbacks:" (command "native-callbacks" [bytecode ^ "-native-callbacks",library]),"native callback fixture");
                  ignore(command "compile-native-calls" ["bin/runeopt",bytecode ^ "stack.rbc","-o",bytecode ^ "-native"]);
                  need(String.isSubstring "PASS foreign calls:" (command "native-calls" [bytecode ^ "-native",library]),"native fixture");
                  ignore(command "compile-native-memory" ["bin/runeopt",bytecode ^ "stack-memory.rbc","-o",bytecode ^ "-native-memory"]);
                  need(String.isSubstring "PASS native memory marshalling:" (command "native-memory" [bytecode ^ "-native-memory",library]),"native memory fixture");
                  ignore(command "compile-native-owner" ["bin/runeopt",bytecode ^ "stack-owner.rbc","-o",bytecode ^ "-native-owner"]);
                  need(String.isSubstring "PASS explicit native owners:" (command "native-owner" [bytecode ^ "-native-owner",library]),"native owner fixture"))
         end
    end
  fun main ["sources"] = (source (fromRoot "ffi/sdl/upstream") (json "ffi/sdl/source.json"); inventories ())
    | main ["contracts"] = contracts ()
    | main ["native"] = native false
    | main ["libffi"] = native true
    | main ["windows", bits] = (need (bits = "32" orelse bits = "64", "expected 32 or 64"); windows bits)
    | main ["runtime",mode] = runtime mode
    | main ["sdk"] = source (env ("RUNEFFI_WINDOWS_SDK", "")) (json "ffi/win32/source.json")
    | main _ = raise Failed "expected sources, contracts, native, libffi, windows 32|64, or sdk"
end
val () = FfiChecks.main (CommandLine.arguments ()) handle e =>
  (TextIO.output (TextIO.stdErr, "FAIL ffi: " ^ (case e of FfiChecks.Failed s => s | _ => General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)

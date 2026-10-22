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
    in one ("sdl", 54); one ("win32", 38);
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
  fun main ["sources"] = (source (fromRoot "ffi/sdl/upstream") (json "ffi/sdl/source.json"); inventories ())
    | main ["contracts"] = contracts ()
    | main ["native"] = native false
    | main ["libffi"] = native true
    | main ["windows", bits] = (need (bits = "32" orelse bits = "64", "expected 32 or 64"); windows bits)
    | main ["sdk"] = source (env ("RUNEFFI_WINDOWS_SDK", "")) (json "ffi/win32/source.json")
    | main _ = raise Failed "expected sources, contracts, native, libffi, windows 32|64, or sdk"
end
val () = FfiChecks.main (CommandLine.arguments ()) handle e =>
  (TextIO.output (TextIO.stdErr, "FAIL ffi: " ^ (case e of FfiChecks.Failed s => s | _ => General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)

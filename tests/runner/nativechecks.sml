(* The native suites' assertions, with one command per independently rerunnable
   case. This module does not discover or schedule tests: Native owns the tree. *)
structure NativeChecks =
struct
  open Sh
  exception Check of string
  fun require (ok, message) = if ok then () else raise Check message
  val base = if env ("RUNE_TEST_RUN", "") = "" then root ^ "/tests/out/native" else run ^ "/native"
  val opt = env ("RUNEOPT", "bin/runeopt")
  fun nativeOpt () = env ("RUNEOPT", if exists "bin/runeopt-mlton" then "bin/runeopt-mlton" else opt)
  val rune = env ("RUNE_TEST_STACK_COMPILER", "bin/rune-stack")
  val vm = env ("RUNE_TEST_STACK_VM", "bin/runevm-stack")
  fun safe s = String.translate (fn #"/" => "_" | c => str c) s
  fun directory name = let val dir = base ^ "/" ^ safe name in mkdirs dir; dir end
  (* The compiler's generated assembly exceeds 64 MiB. Keep the temporary
     file bound separate from the supervisor's small diagnostic output. *)
  val limits = {addressSpace = NONE, cpuTime = SOME 600, fileSize = SOME (1024 * 1024 * 1024), core = SOME 0}
  fun execute envf dir name command input =
    Children.exec limits (envf o unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE", "DEBUGINFOD_URLS"])
      {cmd = command, dir = SOME root, stdin = input, stdout = dir ^ "/" ^ name ^ ".out",
       stderr = dir ^ "/" ^ name ^ ".err", timeout = 600}
  fun call dir name command = execute (fn e => e) dir name command ""
  fun sameFiles (label, a, b) = require (same (a, b), label ^ ": " ^ difference (a, b))
  val zero = BytecodeFixture.u32 0
  val one = BytecodeFixture.u32 1
  val two = BytecodeFixture.u32 2
  val huge = BytecodeFixture.le 4 4294967295
  val nodebug = String.concat (List.tabulate (6, fn _ => zero))
  fun bytes ns = String.implode (List.map Char.chr ns)
  fun single code = BytecodeFixture.header "runtime/stack/opcodes.def" ^ zero ^ zero ^ one
                    ^ zero ^ one ^ BytecodeFixture.text "f" ^ BytecodeFixture.u32 (size code) ^ code ^ nodebug
  fun refusals () =
    let val header = BytecodeFixture.header "runtime/stack/opcodes.def"
    in
      [("empty", "not a Rune bytecode file", ""),
       ("version1", "unsupported bytecode version", "RUNE" ^ one),
       ("string", "bad string constant", header ^ one ^ bytes [3, 240, 255, 255, 255]),
       ("name", "bad function name", header ^ zero ^ zero ^ one ^ zero ^ one ^ huge),
       ("code", "truncated code", header ^ zero ^ zero ^ one ^ zero ^ one ^ zero ^ huge),
       ("opcode", "invalid opcode 200 at 0", header ^ zero ^ zero ^ one ^ zero ^ one ^ zero ^ one ^ bytes [200] ^ nodebug),
       ("local", "bad operand for LOCAL at 0", header ^ zero ^ zero ^ one ^ zero ^ one ^ zero ^ BytecodeFixture.u32 5
                   ^ bytes [5] ^ one ^ nodebug),
       ("linepc", "line table out of range", header ^ zero ^ zero ^ one ^ zero ^ one ^ zero ^ one ^ bytes [0]
                    ^ one ^ BytecodeFixture.text "a" ^ one ^ BytecodeFixture.u32 5 ^ bytes [9, 0, 2, 2, 0]),
       ("runs-off", "the code runs off the end of f", single (bytes [8])),
       ("underflow", "the stack underflows at 0 in f", single (bytes [11, 21])),
       ("join", "the stack or the handlers differ on the paths into 11", single (bytes [4] ^ one ^ bytes [23]
                    ^ BytecodeFixture.u32 11 ^ bytes [3, 3, 21])),
       ("handler-ret", "a handler of the function is still installed at 6 in f", single (bytes [25]
                    ^ BytecodeFixture.u32 7 ^ bytes [3, 21, 21])),
       ("pophandler", "POPHANDLER without a handler of the function at 0 in f", single (bytes [26, 3, 21])),
       ("immediate", "an operand at 0 is out of range", single (bytes [2] ^ BytecodeFixture.le 4 1073741824 ^ bytes [21])),
       ("leave", "a jump leaves its function at 0 in f", header ^ zero ^ zero ^ two ^ zero ^ one ^ BytecodeFixture.text "f"
                   ^ BytecodeFixture.u32 5 ^ one ^ BytecodeFixture.text "g" ^ BytecodeFixture.u32 7
                   ^ bytes [22] ^ BytecodeFixture.u32 5 ^ bytes [3, 21] ^ nodebug),
       ("empty-function", "function f has no code", header ^ zero ^ zero ^ two ^ zero ^ one ^ BytecodeFixture.text "f"
                   ^ zero ^ one ^ BytecodeFixture.text "g" ^ two ^ bytes [3, 21] ^ nodebug)]
    end
  fun refuse name =
    case List.find (fn (label, _, _) => name = label) (refusals ()) of
      NONE => raise Check ("unknown refusal " ^ name)
    | SOME (_, message, data) =>
        let val dir = directory ("refuse-" ^ name)
            val file = dir ^ "/input.rbc"
            val () = write (file, data)
            val status = call dir "check" [opt, "--check", file]
        in require (status = 1 andalso String.isSubstring message (firstLine (dir ^ "/check.err")),
                    "refuse " ^ name ^ ": status " ^ Int.toString status ^ ", " ^ firstLine (dir ^ "/check.err")) end
  fun disasm rbc =
    let
      val dir = directory ("disasm-" ^ rbc)
      val () = require (call dir "check" [opt, "--check", rbc] = 0, "check " ^ rbc ^ ": " ^ firstLine (dir ^ "/check.err"))
      val () = require (call dir "opt" [opt, "--disasm", rbc] = 0, "disasm " ^ rbc ^ ": runeopt failed")
      val () = require (call dir "vm" [vm, "--disasm", rbc] = 0, "disasm " ^ rbc ^ ": VM failed")
      val () = write (dir ^ "/normalized", String.concatWith "\n"
        (List.map BytecodeFixture.normalizeReal (String.fields (fn c => c = #"\n") (read (dir ^ "/opt.out")))))
      (* The legacy VM disassembly combined stdout and stderr. Refuse an
         unexpected extra diagnostic rather than silently dropping it. *)
      val () = require (read (dir ^ "/vm.err") = "", "VM disassembly printed a diagnostic")
    in sameFiles ("disasm " ^ rbc, dir ^ "/normalized", dir ^ "/vm.out") end
  fun counts rbc =
    let
      val dir = directory ("counts-" ^ rbc)
      val name = OS.Path.base (OS.Path.file rbc)
      val args = words ("tests/lang/" ^ name ^ ".args")
      val input = if exists ("tests/lang/" ^ name ^ ".stdin") then fromRoot ("tests/lang/" ^ name ^ ".stdin") else ""
      val () = scratch dir
      val cwd = if String.isPrefix "tests/out/matrix/" rbc then OS.Path.dir (fromRoot rbc) else dir
      (* The VM-shaped native entrypoint is a shell adapter. Normalize both
         environments through the same adapter, including PWD and export
         order: environ() allocates its strings and the program may stop
         walking them as soon as it finds PATH. *)
      fun runOne (name, program) = Children.exec limits
        (setEnv ("PWD", cwd) o unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"])
        {cmd = ["/bin/sh", "-c", "exec \"$@\"", "native-counts", program, "--count", fromRoot rbc] @ args, dir = SOME cwd, stdin = input,
         stdout = dir ^ "/" ^ name ^ ".out", stderr = dir ^ "/" ^ name ^ ".err", timeout = 900}
      val vcode = runOne ("vm", fromRoot vm)
      val ncode = runOne ("native", fromRoot "bin/runevm-native")
      val () = require (vcode = ncode, "counts " ^ rbc ^ ": exit statuses differ")
      val () = sameFiles ("counts " ^ rbc ^ " stdout", dir ^ "/vm.out", dir ^ "/native.out")
    in sameFiles ("counts " ^ rbc ^ " stderr", dir ^ "/vm.err", dir ^ "/native.err") end
  fun parity dir rbc =
    let
      val exe = dir ^ "/program"
      val () = require (call dir "translate" [opt, rbc, "-o", exe] = 0, "translation failed: " ^ firstLine (dir ^ "/translate.err"))
      val vcode = call dir "vm" [vm, "--count", rbc]
      val ncode = execute (setEnv ("RUNEVM_OPTIONS", "--count")) dir "native" [exe] ""
      val () = require (vcode = ncode, "native execution status differs from the stack VM")
      val () = sameFiles ("native stdout", dir ^ "/vm.out", dir ^ "/native.out")
    in sameFiles ("native stderr/counts", dir ^ "/vm.err", dir ^ "/native.err") end
  fun example src =
    let val dir = directory ("run-" ^ src)
        val rbc = dir ^ "/program.rbc"
        val () = require (call dir "compile" [rune, src, "-o", rbc] = 0, "cannot compile " ^ src)
    in parity dir rbc end
  fun opcodes () =
    let val dir = directory "every-opcode"
        val listing = "tests/opt/every-opcode.rasm"
        val used = List.mapPartial (fn line => case String.tokens Char.isSpace (BytecodeFixture.withoutComment line) of
                                                op' :: _ => SOME op' | [] => NONE) (lines (read listing))
        val missing = List.filter (fn op' => not (List.exists (fn name => name = op') used))
                        (List.map hd (BytecodeFixture.definitions "runtime/stack/opcodes.def"))
        val () = require (null missing, "every-opcode does not name " ^ String.concatWith " " missing)
        val rbc = dir ^ "/every-opcode.rbc"
        val () = write (rbc, BytecodeFixture.assemble {opdefs = "runtime/stack/opcodes.def", primdefs = "runtime/prims.def", listing = listing})
    in parity dir rbc end
  fun primitives () =
    let val dir = directory "primitives"
        val rbc = dir ^ "/prims.rbc"
        val () = require (call dir "compile" [rune, "tests/opt/prims.sml", "-o", rbc] = 0, "cannot compile primitives")
        val () = require (call dir "disasm" [opt, "--disasm", rbc] = 0, "cannot disassemble primitives")
        val () = require (call dir "inlined" [opt, "--inlined"] = 0, "cannot list inlined primitives")
        val used = List.mapPartial (fn line => case String.tokens Char.isSpace line of
                              _ :: "PRIM" :: index :: _ => SOME index | _ => NONE) (lines (read (dir ^ "/disasm.out")))
        val defs = ListPair.zip (List.map hd (BytecodeFixture.definitions "runtime/prims.def"),
                                List.tabulate (length (BytecodeFixture.definitions "runtime/prims.def"), Int.toString))
        val missing = List.filter (fn name => case List.find (fn (n, _) => n = name) defs of
                              SOME (_, i) => not (List.exists (fn n => n = i) used) | NONE => true)
                        (String.tokens Char.isSpace (read (dir ^ "/inlined.out")))
        val () = require (null missing, "prims.sml does not exercise " ^ String.concatWith " " missing)
    in parity dir rbc end
  fun bootstrap () =
    let val dir = directory "bootstrap"
        val exe = dir ^ "/rune"
        val () = require (call dir "translate" [nativeOpt (), "bin/rune.stack.rbc", "-o", exe, "--options",
                            "--heap-size " ^ env ("RUNE_HEAP", "67108864")] = 0, "native compiler translation failed")
        val () = require (call dir "sources" ["sh", "scripts/build-files.sh", "rune.build"] = 0, "cannot read compiler sources")
        val args = [exe, "--target=stack", "--lib", "bin/../lib", "-o", dir ^ "/stage2.rbc", "build/config.sml"]
                   @ words (dir ^ "/sources.out") @ ["src/main/rune-main.sml"]
        val () = require (call dir "stage2" args = 0, "compiler as native code failed")
    in sameFiles ("native compiler bootstrap", "bin/rune.stack.rbc", dir ^ "/stage2.rbc") end
  fun images () =
    let
      val dir = directory "images"
      val () = scratch dir
      val image = dir ^ "/tests/out/rt.save_first.img"
      val first = dir ^ "/first.rbc"
      val exe = dir ^ "/first"
      fun remove () = OS.FileSys.remove image handle OS.SysErr _ => ()
      fun inside envf label command = Children.exec limits envf
        {cmd = command, dir = SOME dir, stdin = "", stdout = dir ^ "/" ^ label ^ ".out",
         stderr = dir ^ "/" ^ label ^ ".err", timeout = 600}
      val () = require (call dir "compile-first" [rune, "tests/lang/rt.save_first.sml", "-o", first] = 0, "cannot compile image producer")
      val () = require (call dir "translate-first" [opt, first, "-o", exe] = 0, "cannot translate image producer")
      val () = remove ()
      val () = require (inside (fn e => e) "save-vm" [fromRoot vm, first] = 0 andalso exists image, "VM produced no image")
      val () = require (call dir "translate-image" [opt, "--from-image", image, "-o", dir ^ "/from-image"] = 0, "cannot translate restored image")
      val () = require (inside (setEnv ("RUNEVM_OPTIONS", "--restore " ^ image)) "vm-to-native" [dir ^ "/from-image"] = 0,
                        "native image restoration failed")
      val () = sameFiles ("VM to native image", "tests/lang/rt.save_first.restore", dir ^ "/vm-to-native.out")
      val () = require (read (dir ^ "/vm-to-native.err") = "", "native restore printed stderr")
      val () = remove ()
      val () = require (inside (fn e => e) "save-native" [exe] = 0 andalso exists image, "native producer wrote no image")
      val () = require (inside (fn e => e) "native-to-vm" [fromRoot vm, "--restore", image] = 0, "VM image restoration failed")
      val () = sameFiles ("native to VM image", "tests/lang/rt.save_first.restore", dir ^ "/native-to-vm.out")
      val () = require (read (dir ^ "/native-to-vm.err") = "", "VM restore printed stderr")
      val foreign = dir ^ "/foreign.rbc"
      val () = require (call dir "compile-foreign" [rune, "tests/opt/foreign.sml", "-o", foreign] = 0, "cannot compile foreign image consumer")
      val () = require (call dir "translate-foreign" [opt, foreign, "-o", dir ^ "/foreign"] = 0, "cannot translate foreign image consumer")
      val () = require (inside (fn e => e) "foreign" [dir ^ "/foreign"] = 0, "foreign image consumer failed")
    in require (read (dir ^ "/foreign.out") = "refused: noexec\n" andalso read (dir ^ "/foreign.err") = "",
                "an image of another program was not refused") end
  fun collapse xs =
    let fun go ([], acc) = List.rev acc
          | go (x :: rest, acc) = case acc of y :: _ => if x = y then go (rest, acc) else go (rest, x :: acc)
                                          | [] => go (rest, [x])
    in go (xs, []) end
  fun tool name =
    List.find (fn path => OS.FileSys.access (path, [OS.FileSys.A_EXEC]) handle OS.SysErr _ => false)
      (List.map (fn dir => OS.Path.concat (if dir = "" then "." else dir, name)) (String.fields (fn c => c = #":") (env ("PATH", ""))))
  fun dwarfTool () =
    case tool "llvm-dwarfdump" of SOME path => SOME path
    | NONE =>
        let val versions = List.mapPartial (fn name => if String.isPrefix "llvm-dwarfdump-" name
                              then Option.map (fn n => (n, "/usr/bin/" ^ name)) (Int.fromString (String.extract (name, 15, NONE))) else NONE)
                                           (entries "/usr/bin")
        in case versions of [] => NONE | first :: rest => SOME (#2 (List.foldl (fn (x, best) => if #1 x > #1 best then x else best) first rest)) end
  fun after marker s = Substring.string (Substring.triml (size marker) (#2 (Substring.position marker (Substring.full s))))
  fun quoted s =
    let val rest = after "\"" s
    in Substring.string (#1 (Substring.position "\"" (Substring.full rest))) end
  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))
  fun dwarfLines text =
    let val directories = ref [] : (string * string) list ref
        val files = ref [] : (string * string) list ref
        val index = ref ""
        fun lookup key values = case List.find (fn (k, _) => k = key) values of SOME (_, v) => v | NONE => ""
        fun subscript s = trim (Substring.string (#1 (Substring.position "]" (Substring.full (after "[" s)))))
        fun line s =
          if String.isPrefix "include_directories[" s then (directories := (subscript s, quoted s) :: !directories; NONE)
          else if String.isPrefix "file_names[" s then (index := subscript s; NONE)
          else if String.isPrefix "name: \"" (trim s) then (files := (!index, quoted s) :: !files; NONE)
          else if String.isPrefix "dir_index: " (trim s) then
            let val n = trim (after "dir_index: " s)
                val () = if n = "0" then () else files := (!index, lookup n (!directories) ^ "/" ^ lookup (!index) (!files)) :: !files
            in NONE end
          else if String.isPrefix "0x" s andalso not (String.isSubstring "end_sequence" s) then
            (case String.tokens Char.isSpace s of _ :: line :: col :: file :: _ => SOME (lookup file (!files) ^ ":" ^ line ^ ":" ^ col)
                                               | _ => NONE)
          else NONE
    in collapse (List.mapPartial line (lines text)) end
  fun cached dir rbc =
    let val cache = fromRoot (env ("RUNEOPT_CACHE", "tests/out/opt-cache"))
        val () = mkdirs cache
        val exe = cache ^ "/" ^ NativeVM.checksum rbc
        val exists = NativeVM.executable exe
        val tmp = if exists then "" else NativeVM.temporary (exe ^ ".debug")
        val () = if exists then () else
          (require (call dir "translate" [nativeOpt (), rbc, "-o", tmp] = 0 andalso NativeVM.executable tmp,
                    "native debug translation produced no executable");
           OS.FileSys.rename {old = tmp, new = exe})
    in exe end
  fun debug dwarfOnly rbc =
    let val dir = directory ((if dwarfOnly then "dwarf-" else "debug-") ^ rbc)
        val exe = cached dir rbc
        val () = require (call dir "disasm" [nativeOpt (), "--disasm", rbc] = 0, "debug disassembly failed")
        val disassembly = lines (read (dir ^ "/disasm.out"))
        val expected = collapse (List.mapPartial (fn line =>
          if String.isSubstring "\t; " line then
            (case String.tokens Char.isSpace line of _ :: "POP" :: _ => NONE | _ => SOME (after "\t; " line))
          else NONE) disassembly)
        fun save (name, ls) = write (dir ^ "/" ^ name, String.concat (List.map (fn l => l ^ "\n") ls))
        val () = save ("rbc-lines", expected)
        val () = if not dwarfOnly then () else case dwarfTool () of NONE => raise Check "llvm-dwarfdump is unavailable" | SOME dwarf =>
          (require (call dir "dwarf" [dwarf, "--debug-line", exe] = 0, "llvm-dwarfdump failed");
           save ("dwarf-lines", dwarfLines (read (dir ^ "/dwarf.out")));
           sameFiles ("DWARF line table", dir ^ "/rbc-lines", dir ^ "/dwarf-lines"))
    in if dwarfOnly then () else let
        fun noColumn s = String.concatWith ":" (List.take (String.fields (fn c => c = #":") s,
                                                         length (String.fields (fn c => c = #":") s) - 1))
        fun lineno s = List.last (String.fields (fn c => c = #":") (noColumn s))
        val () = save ("rbc-lineno", collapse (List.map lineno expected))
        val () = require (call dir "readelf" ["readelf", "--debug-dump=decodedline", exe] = 0, "readelf failed")
        val decoded = List.mapPartial (fn line => case String.tokens Char.isSpace line of
                   _ :: n :: address :: _ => if CharVector.all Char.isDigit n andalso String.isPrefix "0x" address then SOME n else NONE
                 | _ => NONE) (lines (read (dir ^ "/readelf.out")))
        val () = save ("readelf-lineno", collapse decoded)
        val () = sameFiles ("readelf line table", dir ^ "/rbc-lineno", dir ^ "/readelf-lineno")
        fun firsts ([], _, _, acc) = List.rev acc
          | firsts (line :: rest, function, want, acc) =
              if String.isPrefix "function " line then firsts (rest, List.nth (String.tokens Char.isSpace line, 1), true, acc)
              else firsts (rest, function, false,
                     if want andalso String.isSubstring "\t; " line then (function, noColumn (after "\t; " line)) :: acc else acc)
        val first = firsts (disassembly, "", false, [])
        val () = require (call dir "nm" ["nm", exe] = 0, "nm failed")
        val syms = List.mapPartial (fn line => case String.tokens Char.isSpace line of
               address :: _ :: name :: _ => (case List.rev (String.fields (fn c => c = #"#") name) of
                 n :: _ => if CharVector.all Char.isDigit n then SOME (n, address) else NONE | [] => NONE)
             | _ => NONE) (lines (read (dir ^ "/nm.out")))
        val joined = List.mapPartial (fn (n, position) => Option.map (fn (_, address) => (position, address))
                                      (List.find (fn (i, _) => i = n) syms)) first
        val () = save ("addresses", List.map (fn (_, address) => "0x" ^ address) joined)
        val () = require (execute (fn e => e) dir "addr2line" ["addr2line", "-e", exe] (dir ^ "/addresses") = 0, "addr2line failed")
        val actual = List.map (fn line => if String.isSubstring " (discriminator " line
                       then Substring.string (#1 (Substring.position " (discriminator " (Substring.full line))) else line)
                       (lines (read (dir ^ "/addr2line.out")))
        val () = require (length actual = length joined, "addr2line returned the wrong number of locations")
    in List.app (fn ((position, _), got) => require (got = position orelse got = root ^ "/" ^ position,
                                   "addr2line: expected " ^ position ^ ", got " ^ got)) (ListPair.zip (joined, actual)) end end
  fun debuggers debugger rbc =
    let
      val dir = directory ("debugger-" ^ debugger ^ "-" ^ rbc)
      val exe = cached dir rbc
      val () = require (call dir "lines" [nativeOpt (), "--lines", rbc] = 0, "cannot read line table for debugger")
      val source = OS.Path.base (OS.Path.file rbc) ^ ".sml"
      fun position line = case String.tokens Char.isSpace line of
        _ :: location :: _ =>
          let val fields = String.fields (fn c => c = #":") location
          in case fields of file :: lineno :: _ => if OS.Path.file file = source then SOME (file, lineno) else NONE | _ => NONE end
      | _ => NONE
      val candidates = List.mapPartial position (lines (read (dir ^ "/lines.out")))
      val (file, line) = case List.rev candidates of p :: _ => p | [] => raise Check "no own-source debugger position"
      val basename = OS.Path.file file
    in if debugger = "gdb" then case tool "gdb" of NONE => raise Check "gdb is unavailable"
        | SOME gdb =>
            (require (call dir "gdb" [gdb, "-batch", "-ex", "break " ^ basename ^ ":" ^ line, "-ex", "run",
                                      "-ex", "info line *$pc", exe] = 0, "gdb failed");
             require (String.isSubstring ("Line " ^ line ^ " of \"") (read (dir ^ "/gdb.out"))
                      andalso String.isSubstring basename (read (dir ^ "/gdb.out")), "gdb did not stop at the source line"))
       else case tool "lldb" of NONE => raise Check "lldb is unavailable"
       | SOME lldb =>
           (require (call dir "lldb" [lldb, "-b", "-o", "breakpoint set -f " ^ basename ^ " -l " ^ line, "-o", "run", exe] = 0,
                     "lldb failed");
            require (String.isSubstring "stop reason = breakpoint" (read (dir ^ "/lldb.out"))
                     andalso String.isSubstring (basename ^ ":" ^ line) (read (dir ^ "/lldb.out")), "lldb did not stop at the source line")) end
  fun debuggerExample debugger () =
    let val dir = directory ("debugger-fixture-" ^ debugger)
        val rbc = dir ^ "/nqueens.rbc"
        val () = require (call dir "compile" [rune, "examples/nqueens.sml", "-o", rbc] = 0, "cannot compile debugger fixture")
    in debuggers debugger rbc end
  fun debugExample dwarf () =
    let val dir = directory (if dwarf then "dwarf-nqueens" else "debug-nqueens")
        val rbc = dir ^ "/nqueens.rbc"
        val () = require (call dir "compile" [rune, "examples/nqueens.sml", "-o", rbc] = 0, "cannot compile debug fixture")
    in debug dwarf rbc end
  fun templates () =
    let val dir = directory "templates"
        val () = require (call dir "generate" ["bin/runeopt-templates"] = 0, "cannot generate native layout templates")
    in sameFiles ("native layout templates", "src/opt/x64_layout.sml", dir ^ "/generate.out") end
  fun protect name f () = f () handle Check message => say ("FAIL native " ^ name ^ ": " ^ message ^ "\n")
                                    | BytecodeFixture.Bad message => say ("FAIL native " ^ name ^ ": " ^ message ^ "\n")
  fun command ["native-refuse", name] = SOME (protect name (fn () => refuse name))
    | command ["native-checksum", file] = SOME (fn () => say (NativeVM.checksum file ^ "\n"))
    | command ["native-disasm", rbc] = SOME (protect rbc (fn () => disasm rbc))
    | command ["native-counts", rbc] = SOME (protect rbc (fn () => counts rbc))
    | command ["native-debug", rbc] = SOME (protect rbc (fn () => debug false rbc))
    | command ["native-dwarf", rbc] = SOME (protect rbc (fn () => debug true rbc))
    | command ["native-debug-example"] = SOME (protect "debug-nqueens" (debugExample false))
    | command ["native-dwarf-example"] = SOME (protect "dwarf-nqueens" (debugExample true))
    | command ["native-example", src] = SOME (protect src (fn () => example src))
    | command ["native-opcodes"] = SOME (protect "opcodes" opcodes)
    | command ["native-primitives"] = SOME (protect "primitives" primitives)
    | command ["native-bootstrap"] = SOME (protect "bootstrap" bootstrap)
    | command ["native-images"] = SOME (protect "images" images)
    | command ["native-debugger", debugger, rbc] = SOME (protect rbc (fn () => debuggers debugger rbc))
    | command ["native-debugger", debugger] = SOME (protect debugger (debuggerExample debugger))
    | command ["native-templates"] = SOME (protect "templates" templates)
    | command ["native-assemble", opdefs, primdefs, listing, out] =
        SOME (fn () => write (out, BytecodeFixture.assemble {opdefs = opdefs, primdefs = primdefs, listing = listing}))
    | command _ = NONE
end

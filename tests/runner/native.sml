(* The native tests are ordinary runner cases, rather than a make step that
   hides another scheduler. Producer edges name the bytecode each case reads. *)
structure Native =
struct
  open Sh
  fun tagged tags tree = List.foldl (fn (tag, tree) => Test.tag tag tree) tree tags
  fun job (name, args, after) =
    Test.requires ["native-host"] (Test.it name {program = "/bin/sh",
      args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-native-check " ^ String.concatWith " " (List.map quote args)],
      env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800,
      cap = 0, cpus = 1, memory = 300, pools = [], exclusive = false, after = after,
      judge = failLines}) : Run.command Test.tree
  val known = ["bin/rune.stack.rbc", "bin/runedoc.stack.rbc"]
      @ List.map (fn name => "tests/out/" ^ name ^ ".rbc") Lang.langPrograms
      @ List.map (fn name => "tests/out/matrix/rune/" ^ name ^ ".dir/prog.rbc") Basis.tests
  fun extras () =
    let
      val files = glob ("tests/out", ".rbc") @ List.concat (List.map
        (fn dir => glob (dir, ".rbc")) (List.filter isDir (glob ("tests/out/matrix/rune", ".dir"))))
      val extras = List.filter (fn path => not (List.exists (fn known => known = path) known)) files
      val dir = NativeChecks.directory "extra-programs"
      val () = write (dir ^ "/programs.txt", String.concat (List.map (fn path => path ^ "\n") extras))
    in List.app (fn path => NativeChecks.protect path (fn () => NativeChecks.disasm path) ()) extras end
  fun prepareAsan native =
    let
      (* Private shadow roots can provide the source/build tools by symlink.
         Build at the actual source root, never regenerate through that alias. *)
      val source = OS.Path.dir (OS.FileSys.realPath (fromRoot "rune.build"))
      val dir = NativeChecks.directory (if native then "prepare-native-asan" else "prepare-asan")
      val targets = if native then ["build/asan/librune.a"] else ["vm-asan"]
      val status = NativeChecks.execute (unsetEnv ["MAKEFLAGS", "MFLAGS", "MAKELEVEL"]) dir "make"
                     (["make", "--no-print-directory", "-C", source, "JOBS=1"] @ targets) ""
      val () = NativeChecks.require (status = 0, "cannot build sanitizer prerequisites")
    in
      if not native then () else
        let val file = source ^ "/build/asan/cc"
            val () = write (file, "#!/bin/sh\nexec " ^ quote (env ("CC", "cc")) ^ " -fsanitize=address,undefined \"$@\"\n")
        in Posix.FileSys.chmod (file, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr,
                                                          Posix.FileSys.S.ixusr, Posix.FileSys.S.irgrp,
                                                          Posix.FileSys.S.ixgrp, Posix.FileSys.S.iroth, Posix.FileSys.S.ixoth]) end
    end
  (* Stress only the tested VM; compilation uses the ordinary compiler. *)
  fun stressBasis native =
    let
      val dir = NativeChecks.directory (if native then "basis-native-stress" else "basis-stress")
      val wrapper = dir ^ "/vm"
      val stress = env ("GC_STRESS_BASIS", "1009")
      val vm = if native then "bin/runevm-native" else "bin/runevm-stack"
      val options = if native then " --gc-stress " else " --nursery 0 --gc-stress "
      val () = write (wrapper, "#!/bin/sh\nexec " ^ quote (fromRoot vm) ^ options ^ stress ^ " \"$@\"\n")
      val () = Posix.FileSys.chmod (wrapper, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr])
      val envf = unsetEnv ["MAKEFLAGS", "MFLAGS", "MAKELEVEL"]
          o setEnv ("RUNE", fromRoot "bin/rune-stack") o setEnv ("RUNE_MATRIX_TIMEOUT", "900")
          o setEnv ("RUNE_MATRIX_RUN", dir ^ "/work")
          o setEnv (if native then "RUNEVM_OPT" else "RUNEVM", wrapper)
      val status = Children.exec {addressSpace = NONE, cpuTime = NONE, fileSize = SOME (128 * 1024 * 1024), core = SOME 0} envf
        {cmd = [fromRoot "bin/rune-matrix", "-j", env ("RUNE_TEST_CPUS", "1"), "--configs", if native then "rune:opt" else "rune"],
         dir = SOME root, stdin = "", stdout = dir ^ "/matrix.out", stderr = dir ^ "/matrix.err", timeout = 0}
    in NativeChecks.require (status = 0, "Basis stress selection failed; see " ^ dir) end
  fun basisJob native =
    let val name = if native then "native" else "stack"
    in Test.resources {cpus = Runtime.processors (), memory = 4000}
      (Test.it name {program = "/bin/sh", args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test native-basis-stress " ^ name],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 3600,
       cap = 0, cpus = 1, memory = 4000, pools = ["lang", "matrix"], exclusive = false, after = [], judge = failLines}) end
  fun command ["native-extra-disassembly"] = SOME extras
    | command ["native-launcher-faults"] = SOME NativeFaults.one
    | command ["native-prepare-asan"] = SOME (NativeChecks.protect "prepare-asan" (fn () => prepareAsan false))
    | command ["native-prepare-native-asan"] = SOME (NativeChecks.protect "prepare-native-asan" (fn () => prepareAsan true))
    | command ["native-basis-stress", "stack"] = SOME (NativeChecks.protect "basis-stress" (fn () => stressBasis false))
    | command ["native-basis-stress", "native"] = SOME (NativeChecks.protect "basis-native-stress" (fn () => stressBasis true))
    | command args = NativeChecks.command args
  val covers = ["covers:tests/opt/*", "covers:tests/runner/native*.sml", "covers:tests/runner/bytecode.sml",
                "covers:tests/runner/children.sml"]
  val producers = ["compile/stack-done", "basis-compile/stack-done"]
  val disassembly =
    [job ("compiler", ["native-disasm", "bin/rune.stack.rbc"], []),
     job ("runedoc", ["native-disasm", "bin/runedoc.stack.rbc"], [])]
    @ [Test.describe "lang" (List.map (fn name =>
          job (name, ["native-disasm", "tests/out/" ^ name ^ ".rbc"], ["compile/stack/" ^ name])) Lang.langPrograms),
       Test.describe "basis" (List.map (fn name =>
          job (name, ["native-disasm", "tests/out/matrix/rune/" ^ name ^ ".dir/prog.rbc"], ["basis-compile/stack/" ^ name])) Basis.tests),
       Test.requires ["native-host"] (LibHosts.job ("extra-programs", ["native-extra-disassembly"], producers, 300))]
  val nativePrograms = List.filter (fn name => not (isSome (Expectations.skipped
                        (Lang.optSkip, {way = "native", path = name})))) Lang.langPrograms
  val counts = List.map (fn name => job (name, ["native-counts", "tests/out/" ^ name ^ ".rbc"],
                                                      ["compile/stack/" ^ name])) nativePrograms
  fun debug dwarf =
    let val command = if dwarf then "native-dwarf" else "native-debug"
        fun needed tree = Test.requires (if dwarf then ["llvm-dwarfdump"] else ["readelf", "nm", "addr2line"]) tree
    in List.map needed ([job ("compiler", [command, "bin/rune.stack.rbc"], []),
                        job ("example-nqueens", [command ^ "-example"], [])]
      @ List.map (fn name => job (name, [command, "tests/out/" ^ name ^ ".rbc"],
                                      ["compile/stack/" ^ name])) Lang.langPrograms) end
  val capabilities =
    [{name = "native-host", probe = "test \"$(uname -s) $(uname -m)\" = 'Linux x86_64'",
      hint = "runeopt makes programs for Linux on x86-64"},
     {name = "llvm-dwarfdump", probe = "command -v llvm-dwarfdump || { for d in /usr/bin/llvm-dwarfdump-*; do test ! -x \"$d\" || exit 0; done; exit 1; }",
      hint = "install LLVM tools for DWARF file, line and column checks"}]
    @ List.map (fn name => {name = name, probe = "command -v " ^ name,
                           hint = "install " ^ name ^ " for native debug checks"}) ["readelf", "nm", "addr2line", "gdb", "lldb"]
  val tree = Test.describe "native"
    [tagged ("check" :: "test-opt" :: covers)
      (Test.describe "opt"
        [Test.describe "refuse" (List.map (fn (name, _, _) => job (name, ["native-refuse", name], [])) (NativeChecks.refusals ())),
         Test.describe "disasm" disassembly,
         job ("every-opcode", ["native-opcodes"], []), job ("primitives", ["native-primitives"], []),
         job ("images", ["native-images"], []),
         Test.describe "examples" (List.map (fn src => job (NativeChecks.safe src,
                        ["native-example", src], []))
                        ["examples/hello.sml", "examples/fib.sml", "examples/nqueens.sml", "tests/perf/fib.sml", "tests/perf/tak.sml"])]),
     tagged ("check" :: "test-native" :: covers)
       (Test.describe "code"
         [Test.describe "counts" counts, Test.describe "debug" (debug false), Test.describe "dwarf" (debug true),
          job ("bootstrap", ["native-bootstrap"], []),
          Test.describe "debuggers" (List.map (fn name => Test.requires [name]
            (job (name, ["native-debugger", name], []))) ["gdb", "lldb"]),
          job ("templates", ["native-templates"], [])]),
     tagged ("check" :: "quick" :: covers)
       (Test.describe "launcher" [Test.requires ["native-host", "readelf", "nm"]
         (LibHosts.job ("faults", ["native-launcher-faults"], ["compile/stack/dec.val_simple"], 200))]),
     tagged ["nightly", "vm", "test-register-asan"]
       (Test.describe "prepare" [LibHosts.jobIn ["build"] ("asan", ["native-prepare-asan"], [], 1000)]),
     tagged ["nightly", "test-native-asan"]
       (Test.describe "prepare" [LibHosts.jobIn ["build"] ("native-asan", ["native-prepare-native-asan"], [], 1000)]),
     tagged ["nightly", "vm", "test-stress"] (Test.describe "basis-stress" [basisJob false]),
     tagged ["nightly", "test-native-stress"] (Test.describe "basis-stress" [basisJob true])]
end

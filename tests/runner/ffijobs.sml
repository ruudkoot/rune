structure FfiJobs =
struct
  fun jobWith program name args tags =
    List.foldl (fn (tag, tree) => Test.tag tag tree)
      (Test.it name {program = "/bin/sh", args = ["sh", "-c", "exec bin/" ^ program ^ " " ^ args],
        env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800, cap = 0,
        cpus = 1, memory = 1000, pools = [], exclusive = false, after = if args = "runtime asan" then ["native/prepare/asan"] else [], judge = Sh.failLines} : Run.command Test.tree)
      (tags @ ["covers:ffi/*", "covers:tests/ffi/*", "covers:tests/runner/ffijobs.sml"])
  fun job name args tags = jobWith "rune-ffi-check" name args tags
  fun frontendJob name args tags = jobWith "rune-c-check" name args
    (tags @ ["covers:lib/language/c/*", "covers:tools/cfrontend/*", "covers:tests/lib/language/c/*"])
  val tree = Test.describe "ffi"
    [job "sources" "sources" ["check", "test-ffi-contracts"],
     job "contracts" "contracts" ["check", "test-ffi-contracts"],
     Test.requires ["cc"] (job "native" "native" ["check", "test-ffi-contracts"]),
     Test.requires ["cc"] (job "runtime" "runtime native" ["check", "test-ffi-runtime"]),
     Test.requires ["cc"] (job "runtime-asan" "runtime asan" ["test-ffi-runtime-asan", "vm", "nightly"]),
     Test.requires ["libffi"] (job "libffi" "libffi" ["test-ffi-libffi"]),
     Test.requires ["windows"] (Test.describe "windows"
       (List.map (fn bits => job bits ("windows " ^ bits) ["test-ffi-windows", "test-windows", "nightly"]) ["32", "64"] @
       List.map(fn bits=>job ("runtime" ^ bits) ("runtime windows" ^ bits) ["test-ffi-runtime-windows"]) ["32","64"])),
     Test.describe "frontend"
       [Test.requires ["cc"] (frontendJob "fixture" "fixture" ["check", "test-c-frontend"]),
        Test.requires ["clang"] (frontendJob "sdl-linux" "headers sdl linux-x86_64" ["test-c-frontend"]),
        Test.requires ["clang", "windows-sdk"] (Test.describe "windows"
          (List.concat (List.map (fn library => List.map (fn target =>
            frontendJob (library ^ "/" ^ target) ("headers " ^ library ^ " " ^ target) ["test-c-frontend-windows"])
            ["windows-x86", "windows-x86_64"]) ["sdl", "win32"])))] ]
end

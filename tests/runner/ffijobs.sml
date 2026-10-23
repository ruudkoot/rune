structure FfiJobs =
struct
  fun jobWith program name args tags =
    List.foldl (fn (tag, tree) => Test.tag tag tree)
      (Test.it name {program = "/bin/sh", args = ["sh", "-c", "exec bin/" ^ program ^ " " ^ args],
        env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800, cap = 0,
        cpus = 1, memory = 1000, pools = if program="rune-ffi-shim-check" andalso args="host mlkit" then ["matrix"] else [], exclusive = false, after = if args = "runtime asan" orelse (program="rune-ffi-shim-check" andalso args="asan") then ["native/prepare/asan"] else [], judge = Sh.failLines} : Run.command Test.tree)
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
     Test.describe "shims"
       (List.map(fn target=>jobWith "rune-ffi-shim-check" target target (if target="native" then ["check","test-ffi-shims"] else ["test-ffi-shims"]))
         ["native","linux32","windows32","windows64","aarch64","ppc64"] @
        [jobWith "rune-ffi-shim-check" "asan" "asan" ["test-ffi-shims-asan","vm","nightly"]] @
        [Test.describe "hosts"(List.map(fn host=>Test.requires["host:" ^ host]
          (jobWith "rune-ffi-shim-check" host ("host " ^ host)["test-ffi-shims-hosts","library","nightly"]))Hosts.names)]),
     Test.describe "layout"
       (List.map(fn target=>jobWith "rune-c-layout-check" target target ["test-c-layout"])
         ["native","linux32","windows32","windows64","aarch64","ppc64"]),
     Test.describe "headers"
       [jobWith "rune-header-layout-check" "sdl-linux" "headers sdl linux-x86_64" ["check","test-ffi-header-layout"],
        Test.requires["windows-sdk","windows"](Test.describe "windows"
          (List.concat(List.map(fn library=>List.map(fn target=>jobWith "rune-header-layout-check"
            (library ^ "/" ^ target)("headers " ^ library ^ " " ^ target)["test-ffi-header-layout"])
            ["windows-x86","windows-x86_64"])["sdl","win32"])))],
     Test.describe "real32"
       (List.map(fn target=>jobWith "rune-header-layout-check" target ("real32 " ^ target)
         (if target="native" then ["check","test-ffi-real32"] else ["test-ffi-real32"]))
         ["native","linux32","windows32","windows64","aarch64","ppc64"]),
     Test.describe "frontend"
       [Test.requires ["cc"] (frontendJob "fixture" "fixture" ["check", "test-c-frontend"]),
        Test.requires ["clang"] (frontendJob "sdl-linux" "headers sdl linux-x86_64" ["test-c-frontend"]),
        Test.requires ["clang", "windows-sdk"] (Test.describe "windows"
          (List.concat (List.map (fn library => List.map (fn target =>
            frontendJob (library ^ "/" ^ target) ("headers " ^ library ^ " " ^ target) ["test-c-frontend-windows"])
            ["windows-x86", "windows-x86_64"]) ["sdl", "win32"])))] ]
end

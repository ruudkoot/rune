structure FfiJobs =
struct
  fun jobWith program name args tags =
    let
      val nativeCalls = ((program = "rune-sdl-check" orelse program = "rune-win32-check") andalso args<>"host-projects") orelse
        (program = "rune-ffi-shim-check" andalso
         List.exists (fn mode => mode = args) ["native", "asan", "windows32", "windows64"])
      val tags = if nativeCalls andalso not (RuneForeign.available ())
                 then List.filter (fn tag => tag <> "check") tags else tags
      val execution =
        (Test.it name {program = "/bin/sh", args = ["sh", "-c", "exec bin/" ^ program ^ " " ^ args],
        env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800, cap = 0,
        cpus = 1, memory = 1000, pools = if program="rune-ffi-shim-check" andalso args="host mlkit" then ["matrix"] else [], exclusive = false, after = if args = "runtime asan" orelse (program="rune-ffi-shim-check" andalso args="asan") then ["native/prepare/asan"] else [], judge = Sh.failLines} : Run.command Test.tree)
      val execution = if nativeCalls then Test.requires ["ffi-runtime"] execution else execution
    in List.foldl (fn (tag, tree) => Test.tag tag tree) execution
      (tags @ ["covers:ffi/*", "covers:tests/ffi/*", "covers:tests/runner/ffijobs.sml"])
    end
  fun job name args tags = jobWith "rune-ffi-check" name args tags
  fun frontendJob name args tags = jobWith "rune-c-check" name args
    (tags @ ["covers:lib/language/c/*", "covers:tools/cfrontend/*", "covers:tests/lib/language/c/*"])
  val tree = Test.describe "ffi"
    [jobWith "rune-ffi-deps-check" "dependency-model" "" ["check", "test-ffi-deps"],
     job "sources" "sources" ["check", "test-ffi-contracts"],
     job "contracts" "contracts" ["check", "test-ffi-contracts"],
     Test.requires ["cc"] (job "native" "native" ["check", "test-ffi-contracts"]),
     Test.requires ["cc"] (job "runtime" "runtime native" ["check", "test-ffi-runtime"]),
     Test.requires ["cc"] (job "runtime-asan" "runtime asan" ["test-ffi-runtime-asan", "vm", "nightly"]),
     Test.requires ["libffi"] (job "libffi" "libffi" ["test-ffi-libffi"]),
     Test.requires ["windows"] (Test.describe "windows"
       (List.map (fn bits => job bits ("windows " ^ bits) ["test-ffi-windows", "test-windows", "nightly"]) ["32", "64"] @
       List.map(fn bits=>job ("runtime" ^ bits) ("runtime windows" ^ bits) ["test-ffi-runtime-windows"]) ["32","64"])),
     Test.describe "portability"
       (List.map(fn target=>Test.requires(["cc", "ffi-" ^ target] @ (if target="linux32" then [] else ["clang"]))
         (jobWith "rune-ffi-cross-check" target target ["test-ffi-portability", "nightly"]))["linux32","aarch64","ppc64"]),
     Test.describe "shims"
       (List.map(fn target=>jobWith "rune-ffi-shim-check" target target (if target="native" then ["check","test-ffi-shims"] else ["test-ffi-shims"]))
         ["native","linux32","windows32","windows64","aarch64","ppc64"] @
        [jobWith "rune-ffi-shim-check" "asan" "asan" ["test-ffi-shims-asan","vm","nightly"]] @
        [Test.describe "hosts"(List.map(fn host=>Test.requires["host:" ^ host]
          (jobWith "rune-ffi-shim-check" host ("host " ^ host)["test-ffi-shims-hosts","library","nightly"]))Hosts.names)]),
     Test.describe "sdl"
       [Test.requires ExampleProjects.requiredHosts (jobWith "rune-sdl-check" "host-projects" "host-projects" ["test-sdl-hosts"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "win32-contract" "win32-contract" ["test-win32-sdl-contract"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "win32-contract-gui" "win32-contract-gui" ["test-win32-sdl-contract-gui"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "win32-app" "win32-app" ["test-win32-app-sdl"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "win32-app-gui" "win32-app-gui" ["test-win32-app-sdl-gui"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "win32-driver-failed-init" "win32-driver-failed-init" ["test-win32-sdl-driver"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "win32-driver" "win32-driver" ["test-win32-sdl-driver"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "win32-driver-gui" "win32-driver-gui" ["test-win32-sdl-driver-gui"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "native" "native" ["test-sdl"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "gui-linux" "gui-linux" ["test-sdl-gui"]),
        Test.requires["cc","libffi","sdl3"](jobWith "rune-sdl-check" "asan" "asan" ["test-sdl-asan"]),
        Test.requires["windows","windows-sdk","sdl3-windows32"](jobWith "rune-sdl-check" "windows32" "windows32" ["test-sdl-windows"]),
        Test.requires["windows","windows-sdk","sdl3-windows64"](jobWith "rune-sdl-check" "windows64" "windows64" ["test-sdl-windows"])],
     Test.requires ("windows-sdk" :: ExampleProjects.requiredHosts) (Test.describe "win32-hosts"
       [jobWith "rune-win32-check" "host-projects" "host-projects" ["test-win32-hosts"]]),
     Test.requires ["windows", "windows-sdk", "clang"] (Test.describe "win32-native"
       (List.concat(List.map(fn bits=>
         [jobWith "rune-win32-check" ("contract" ^ bits) ("contract " ^ bits) ["test-win32-native","test-windows","nightly"],
          jobWith "rune-win32-check" ("app" ^ bits) ("app " ^ bits) ["test-win32-app-native","test-windows","nightly"]])["32","64"]))),
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

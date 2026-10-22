structure FfiJobs =
struct
  fun job name args tags =
    List.foldl (fn (tag, tree) => Test.tag tag tree)
      (Test.it name {program = "/bin/sh", args = ["sh", "-c", "exec bin/rune-ffi-check " ^ args],
        env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800, cap = 0,
        cpus = 1, memory = 1000, pools = [], exclusive = false, after = [], judge = Sh.failLines} : Run.command Test.tree)
      (tags @ ["covers:ffi/*", "covers:tests/ffi/*", "covers:tests/runner/ffijobs.sml"])
  val tree = Test.describe "ffi"
    [job "sources" "sources" ["check", "test-ffi-contracts"],
     job "contracts" "contracts" ["check", "test-ffi-contracts"],
     Test.requires ["cc"] (job "native" "native" ["check", "test-ffi-contracts"]),
     Test.requires ["libffi"] (job "libffi" "libffi" ["test-ffi-libffi"]),
     Test.requires ["windows"] (Test.describe "windows"
       (List.map (fn bits => job bits ("windows " ^ bits) ["test-ffi-windows", "test-windows", "nightly"]) ["32", "64"]))]
end

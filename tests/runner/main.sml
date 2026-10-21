(* The inventory of bin/rune-test (docs/plans/unit-testing.md, M3 and M4):
   every test the runner knows, as one tree. `make check` is `make
   check-tools` and then `bin/rune-test run --tier check`.

   The programs of tests/lang and tests/errors are the runner's own tests,
   in every way make check ran them (tests/runner/lang.sml), and so are the
   Basis Library suite's in make check's four configurations of Rune
   (tests/runner/basis.sml), and the laws of its documentation
   (tests/runner/laws.sml). The rest of
   what the old recipe of `make check` ran is a step each, an opaque `make`
   of its target. make check-tools builds what any of them needs before the
   runner starts, so that no two steps build one file at once; then the
   edges and pools below keep apart the steps that share files (the audit
   of M3):

   - the pool `lang`: the steps that run the programs of tests/lang from the
     root of the tree, and so write the files those programs write at fixed
     paths (tests/out/rt.*.img, basis.*.tmp). They run one at a time, each
     on most of the machine;
   - the pool `heap_test`: the steps that build and run build/heap_test;
   Native checks are individual SML jobs with producer edges for the
   bytecode of tests/lang and the Basis suite (tests/runner/native.sml).

   Matrix configurations are ordinary jobs; MLKit shares the matrix pool
   because its compiler caches beside source files.

   Every other step writes only a directory of its own under tests/out, and
   runs beside the rest. A step is told its CPUs as JOBS, from
   RUNE_TEST_CPUS. *)
structure Inventory =
struct
  val processors = Runtime.processors ()
  (* the CPUs of a step of the pool lang, of another step that keeps many
     busy, and of a step with -j of its own that keeps a few *)
  val wide = Int.max (1, processors * 3 div 4)
  val half = Int.max (1, processors div 2)
  val few = Int.max (1, Int.min (4, processors div 4))

  (* the lines of a file that say what failed, the last 15 of them, or the
     file's last lines *)
  fun lines file =
    let val s = TextIO.openIn file
    in String.fields (fn c => c = #"\n") (TextIO.inputAll s) before TextIO.closeIn s end
    handle IO.Io _ => []
  fun last (n, xs) = List.drop (xs, Int.max (0, length xs - n))
  fun failing xs =
    List.filter (fn l => String.isPrefix "FAIL" l orelse String.isSubstring " FAIL" l orelse String.isSubstring "Error" l
                         orelse String.isSubstring "error:" l orelse String.isPrefix "*** " l) xs

  (* a step passes when its make exits with 0; otherwise the reason is what
     its output says failed *)
  fun judge (r : Supervisor.result, files as {stdout, stderr}) =
    case Run.exitZero (r, files) of
      NONE => NONE
    | SOME (verdict, reason) =>
        let
          val said = last (15, failing (lines stdout @ lines stderr))
          val head = case String.fields (fn c => c = #"\n") reason of l :: _ => l | [] => reason
        in
          if null said then SOME (verdict, reason)
          else SOME (verdict, head ^ "\n" ^ String.concatWith "\n" said)
        end

  (* a make of a target: a test of the tier check with `tags` besides, that
     covers the paths `covers` names (for --affected; a step that covers
     none is selected by every change) *)
  fun target (name, seconds, {cpus, memory, pools, after, tags, covers}) =
    List.foldl (fn (t, tree) => Test.tag t tree)
      (Test.it name
         {program = "/bin/sh",
          args = ["sh", "-c", "exec \"${MAKE:-make}\" --no-print-directory " ^ name ^ " JOBS=\"$RUNE_TEST_CPUS\""],
          env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds seconds, cap = 0, cpus = cpus,
          memory = memory, pools = pools, exclusive = false, after = after,
          judge = judge} : Run.command Test.tree)
      (tags @ List.map (fn g => "covers:" ^ g) covers)

  fun step (name, {cpus, memory, pools, after}, tags, covers) =
    target (name, 3600, {cpus = cpus, memory = memory, pools = pools, after = after, tags = "check" :: tags, covers = covers})
  fun lang (name, more, after, covers) =
    step (name, {cpus = wide, memory = 2000, pools = "lang" :: more, after = after}, [], covers)
  fun alone (name, tags, covers) = step (name, {cpus = 1, memory = 500, pools = [], after = []}, tags, covers)
  fun some (name, tags, covers) = step (name, {cpus = few, memory = 500, pools = [], after = []}, tags, covers)

  (* what reads the programs of tests/lang, and what reads tests/perf's *)
  val langFiles = ["tests/lang/*", "tests/errors/*", "tests/opt-skip.txt"]
  val perfFiles = ["tests/perf/*"]

  val make =
    Test.describe "make"
      [alone ("check-units-steps", ["check-units"], ["tests/units/*"]),
       step ("test-register-jit-steps", {cpus = 1, memory = 1000, pools = [], after = []}, [],
             ["tests/register/*", "tests/lang/rt.deeprec_stack.*"]),
       step ("test-steps", {cpus = 1, memory = 500, pools = ["heap_test"], after = []}, [],
             ["tests/compiler/*", "tests/runtime/*"]),
       step ("test-heap-steps", {cpus = 1, memory = 500, pools = ["heap_test"], after = []}, ["layout"], ["tests/runtime/*"]),
       some ("check-docs-generated", ["docs"], ["*.md", "docs/*", "tests/basis/*", "lib/random/*", "lib/test/property/*"]),
       Test.requires ["tmux", "python3"] (alone ("test-terminal", [], ["tests/terminal/*"])),
       alone ("bench-coverage", [], ["examples/benchmarks/*", "tests/benchmarks/*"]),
       alone ("check-isa", [], [])]

  (* Matrix configurations are inventory ways. The remaining Windows make
     adapter is retired with its platform controller in P2.7. *)
  val extras=Test.describe "make" []

  (* what tests require of the machine (D18; docs/testing.md, Requirements),
     with scripts/doctor.sh's hints *)
  val capabilities =
    [{name = "tmux", probe = "command -v tmux", hint = "install tmux (apt, dnf, pacman, brew: tmux)"},
     {name = "python3", probe = "command -v python3", hint = "install python3 (apt, dnf: python3; pacman, brew: python)"},
     {name = "cc", probe = "command -v ${CC:-cc}", hint = "install a C compiler (apt: build-essential; dnf: gcc; pacman: base-devel; brew: gcc)"},
     (* registered with the kernel too: a fork by a VM under qemu is an exec
        of its own binary, which hangs where the kernel cannot start it *)
     {name = "qemu", probe = "{ command -v qemu-ppc64 || command -v qemu-ppc64-static; } && [ -e /proc/sys/fs/binfmt_misc/qemu-ppc64 ] && [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]",
      hint = "install qemu-user (apt, dnf: qemu-user) and register it: sudo sh -c 'cat /usr/lib/binfmt.d/qemu-ppc64.conf > /proc/sys/fs/binfmt_misc/register' (and qemu-aarch64.conf)"},
     {name = "windows", probe = "bin/rune-windows directory && command -v x86_64-w64-mingw32-gcc",
      hint = "Windows under WSL with interop (RUNE_WINDOWS_DIR names a directory there) and mingw-w64 (apt: gcc-mingw-w64-x86-64 gcc-mingw-w64-i686)"}]
    @ List.map (fn h => {name = h, probe = "test -x bin/rune-" ^ h, hint = "run: make hosts, then make " ^ h}) Lang.hosts
    @ [{name="jupyter-client",probe="python3 -c 'import jupyter_client'",hint="install Python jupyter_client for its independent notebook peer"}]
    @ Hosts.capabilities @ Native.capabilities @ Heap.capabilities @ ScenarioJobs.capabilities @ GMPJobs.capabilities
    @ [{name = "grep-pcre", probe = "printf LIST | grep -P '^LIST$'", hint = "GNU grep with PCRE for LAWS_PROGRAMS"}]

  (* each file of expectations read by the one engine (docs/testing.md,
     Expectations): it parses, and its skips name programs that are there.
     The command does nothing; the judge reads the file *)
  fun expectations (name, file, paths) =
    Test.tag "check"
      (Test.tag ("covers:" ^ file)
        (Test.it name
           {program = "/bin/sh", args = ["sh", "-c", "true"], env = NONE, dir = SOME ".", stdin = NONE,
            timeout = Time.fromSeconds 60, cap = 0, cpus = 1, memory = 10, pools = [], exclusive = false, after = [],
            judge = fn _ =>
              let
                val ls = Expectations.read file
                val stale = case paths of
                              NONE => []
                            | SOME ps => Expectations.stale (ls, {ways = [], paths = ps, used = [], today = "0000-00-00"})
              in
                case stale of
                  [] => NONE
                | _ => SOME ("FAIL", "stale: " ^ String.concatWith "\n  " (List.map Expectations.describe stale))
              end
              handle Expectations.Parse m => SOME ("FAIL", m)} : Run.command Test.tree))

  val expected =
    Test.describe "expectations"
      [expectations ("opt-skip", "tests/opt-skip.txt", SOME Lang.langPrograms),
       expectations ("basis-deviations", "tests/basis/deviations.txt", NONE),
       expectations ("windows-skip", "tests/windows-skip.txt", SOME Lang.langPrograms),
       expectations ("portability-skip", "tests/portability-skip.txt", SOME Lang.langPrograms),
       expectations ("mlton-skip", "tests/external/mlton-skip.txt", NONE),
       expectations ("lib-deviations", "tests/lib/deviations.txt", NONE),
       expectations ("quarantine", "tests/runner/quarantine.txt", NONE)]

  val matrixFaults = Test.tag "check" (Test.tag "quick" (Test.tag "covers:tests/runner/matrix*.sml"
    (Test.tag "covers:tests/runner/hostlaws.sml" (Test.tag "covers:tests/runner/smlscan.sml"
      (Test.requires ["grep-pcre"] (Test.describe "runner" [LibHosts.job ("matrix-controller-faults", ["matrix-controller-faults"], [], 300)]))))))
  val tests = Test.describe "" [make, extras, expected, Lang.tests, Basis.tree, Laws.tree, LibHosts.tree, HostChecks.tree, Migration.tree, Native.tree, Heap.tree, HostLaws.tree (), matrixFaults, DocChecks.tree, Mutants.tree (), Matrix.tree (), Matrix.faults, Benchmarks.tree (), ScenarioJobs.tree (), IntInfJobs.tree, GMPJobs.tree, WindowsJobs.tree (), WindowsJobs.faults, Oracles.tree, Tools.tree, Protocols.tree, Portability.tree, Canary.tests]
end

(* laws-one RBC STRUCTURE is the command of a job of the laws
   (tests/runner/laws.sml); every other command is the runner's *)
val () =
  case CommandLine.arguments () of
    ["laws-one", rbc, st] => Laws.one (rbc, st)
  | ["matrix-controller-faults"] => MatrixFaults.one ()
  | args =>
      case WindowsJobs.command args of SOME action => action () | NONE =>
      case Benchmarks.command args of SOME action => action () | NONE =>
      case ScenarioJobs.command args of SOME action => action () | NONE =>
      case HostLaws.command args of
        SOME f => f ()
      | NONE =>
      case Native.command args of
        SOME f => f ()
      | NONE =>
      case Heap.command args of
        SOME f => f ()
      | NONE =>
      case Migration.command args of
        SOME f => f ()
      | NONE =>
      case HostChecks.command args of
        SOME f => f ()
      | NONE =>
      case LibHosts.command args of
        SOME f => f ()
      | NONE =>
      case Oracles.command args of
        SOME f => f ()
      | NONE =>
          case Tools.command args of
            SOME f => f ()
          | NONE => case Protocols.command args of
                      SOME f => f ()
                    | NONE =>
                  case Portability.command args of
                    SOME f => f ()
                  | NONE => Cli.mainWith {tests = Inventory.tests, capabilities = Inventory.capabilities,
                                            quarantine = "tests/runner/quarantine.txt"}

(* Repository test inventory over lib/test/runner. Standard ML owns cases,
   dependencies, limits and verdicts, including independent C fixture runs.
   make check-tools builds every shared subject before scheduling begins.

   The remaining Make adapters generate/check documentation, audit benchmark
   coverage and verify ISA tables through their SML tools. Matrix MLKit jobs
   retain their shared cache pool; each other worker owns its output tree. *)
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
      [some ("check-docs-generated", ["docs"], ["*.md", "docs/*", "tests/basis/*", "lib/random/*", "lib/test/property/*"]),
       alone ("bench-coverage", [], ["examples/benchmarks/*", "tests/benchmarks/*"]),
       alone ("check-isa", [], [])]

  (* what tests require of the machine (D18; docs/testing.md, Requirements),
     with scripts/doctor.sh's hints *)
  val capabilities =
    [{name = "python3", probe = "command -v python3", hint = "install python3 (apt, dnf: python3; pacman, brew: python)"},
     {name = "cc", probe = "command -v ${CC:-cc}", hint = "install a C compiler (apt: build-essential; dnf: gcc; pacman: base-devel; brew: gcc)"},
     (* registered with the kernel too: a fork by a VM under qemu is an exec
        of its own binary, which hangs where the kernel cannot start it *)
     {name = "qemu", probe = "{ command -v qemu-ppc64 || command -v qemu-ppc64-static; } && [ -e /proc/sys/fs/binfmt_misc/qemu-ppc64 ] && [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]",
      hint = "install qemu-user (apt, dnf: qemu-user) and register it: sudo sh -c 'cat /usr/lib/binfmt.d/qemu-ppc64.conf > /proc/sys/fs/binfmt_misc/register' (and qemu-aarch64.conf)"},
     {name = "windows", probe = "bin/rune-windows directory && command -v x86_64-w64-mingw32-gcc",
      hint = "Windows under WSL with interop (RUNE_WINDOWS_DIR names a directory there) and mingw-w64 (apt: gcc-mingw-w64-x86-64 gcc-mingw-w64-i686)"}]
    @ List.map (fn h => {name = h, probe = "test -x bin/rune-" ^ h, hint = "run: make hosts, then make " ^ h}) Lang.hosts
    @ [{name="jupyter-client",probe="python3 -c 'import jupyter_client, zmq'",
        hint="install jupyter_client and pyzmq for python3 (Ubuntu: python3-jupyter-client python3-zmq)"}]
    @ Hosts.capabilities @ Native.capabilities @ Heap.capabilities @ ScenarioJobs.capabilities @ GMPJobs.capabilities @ TerminalJobs.capabilities
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
  val checkRequirements = List.foldl (fn (tag, tree) => Test.tag tag tree)
    (Test.describe "runner" [LibHosts.job ("check-requirements", ["check-requirements"], [], 300)])
    ["check", "quick", "covers:tests/runner/scenariojobs.sml", "covers:scripts/doctor.sh"]
  (* These inputs can change every produced program or the machinery that
     judges it. Give every leaf their coverage, even when a narrower group
     also names the same file (for example Basis docs or JIT dump checks). *)
  val broadInputs = ["src/*", "runtime/*", "lib/basis/*", "lib/test/runner/*",
                     "Makefile", "tools/builder/*", "tools/generate/*", "scripts/*"]
  val tests = List.foldl (fn (path, tree) => Test.tag ("covers:" ^ path) tree)
    (Test.describe "" [make, expected, Lang.tests, Basis.tree, Laws.tree, LibHosts.tree, HostChecks.tree, BuildChecks.tree, Migration.tree, Native.tree, Heap.tree, HostLaws.tree (), matrixFaults, checkRequirements, DocChecks.tree, Mutants.tree (), Matrix.tree (), Matrix.faults, Benchmarks.tree (), ScenarioJobs.tree (), IntInfJobs.tree, MeasurementJobs.tree, GMPJobs.tree, WindowsJobs.tree (), WindowsJobs.faults, Oracles.tree, Tools.tree, TerminalJobs.tree, Protocols.tree, Portability.tree, Canary.tests]) broadInputs

  fun requirements () =
    let val rows = Test.leaves tests
        fun need (ok, why) = if ok then () else raise Fail ("check requirements: " ^ why)
        fun meta name = case List.find (fn {path, ...} => path = name) rows of
            SOME {meta, ...} => meta | NONE => raise Fail ("missing inventory case: " ^ name)
        fun has tag (m : Test.meta) = List.exists (fn t => t = tag) (#tags m)
        val check = TestFilter.parse "tag:check"
        val checked = List.filter (fn {path, meta, ...} => TestFilter.matches check {path = path, tags = #tags meta}) rows
        val nativeWindows = List.filter (fn {meta, ...} =>
              List.exists (fn name => name = "windows" orelse name = "windows-installer") (#requires meta)) checked
        val () = need (null nativeWindows, "portable tier selects native Windows: " ^ String.concatWith "," (List.map #path nativeWindows))
        val windows = meta "scenarios/dist/windows"
        val () = List.app (fn tag => need (has tag windows, "Windows installer lost its " ^ tag ^ " selection"))
                   ["test-dist", "test-windows", "nightly", "windows", "vm"]
        val () = need (List.exists (fn name => name = "windows-installer") (#requires windows), "Windows installer lost its capability")
        val () = List.app (fn name => need (has "check" (meta ("scenarios/dist/" ^ name)), "portable distribution case left check: " ^ name))
                   ["prepare", "archives", "metadata", "installer", "binaries", "faults"]
        val () = List.app (fn name => let val m = meta ("kernel/" ^ name)
                   in need (has "check" m andalso List.exists (fn name => name = "jupyter-client") (#requires m), "notebook peer lost its check requirement") end)
                   ["notebook-pipe", "notebook-connection"]
        val dir = Sh.run ^ "/check-requirements"
        val () = Sh.mkdirs (dir ^ "/bin")
        val python = dir ^ "/bin/python3"
        val () = Sh.write (python, "#!/bin/sh\nexit 1\n")
        val () = Posix.FileSys.chmod (python, Posix.FileSys.S.irwxu)
        val status = Children.exec Subprocess.unlimited (Sh.setEnv ("PATH", dir ^ "/bin:" ^ Sh.env ("PATH", "")))
             {cmd = ["sh", Sh.fromRoot "scripts/doctor.sh", "--quiet", "--scope", "check"], dir = SOME Sh.root,
              stdin = "", stdout = dir ^ "/doctor.out", stderr = dir ^ "/doctor.err", timeout = 30}
        val diagnostic = Sh.read (dir ^ "/doctor.out")
        val () = need (status = 1 andalso String.isSubstring "jupyter-client" diagnostic andalso String.isSubstring "cannot import" diagnostic,
                       "doctor accepted a Python without the independent notebook peer")
    in Sh.say "PASS portable check inventory and missing notebook peer preflight\n" end
end

(* laws-one RBC STRUCTURE is the command of a job of the laws
   (tests/runner/laws.sml); every other command is the runner's *)
val () =
  case CommandLine.arguments () of
    ["laws-one", rbc, st] => Laws.one (rbc, st)
  | ["matrix-controller-faults"] => MatrixFaults.one ()
  | ["check-requirements"] => Inventory.requirements ()
  | args =>
      case BuildChecks.command args of SOME action => action () | NONE =>
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

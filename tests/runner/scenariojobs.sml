(* Build/install scenarios use the same inventory and supervisor as every
   other suite. Producer dependencies make fixture/cache ordering explicit. *)
structure ScenarioJobs =
struct
  open Sh
  fun context suite = Scenarios.create suite (env ("SCENARIO_RUNE", "bin/rune"))
  fun fail message = (say ("FAIL scenario: " ^ message ^ "\n"); Posix.Process.exit 0w1)
  fun protect f () = f () handle Scenarios.Failed message => fail message
    | InstallChecks.Failed message => fail message | DistChecks.Failed message => fail message
    | ArchiveCheck.Invalid message => fail message | BinaryFixtures.Invalid message => fail message
    | e => fail (General.exnMessage e)
  fun command ["scenario-prepare", "deps"] = SOME (protect (Scenarios.depsPrepare (context "deps")))
    | command ["scenario-prepare", "buildfile"] = SOME (protect (Scenarios.buildPrepare (context "buildfile")))
    | command ["scenario-prepare", "units"] = SOME (protect (Scenarios.unitsPrepare (context "units")))
    | command ["scenario-deps", name] = SOME (protect (Scenarios.deps (context "deps") name))
    | command ["scenario-buildfile", name] = SOME (protect (Scenarios.build (context "buildfile") name))
    | command ["scenario-dynamic", name] = SOME (protect (Scenarios.dynamic (context ("dynamic/" ^ name)) name))
    | command ["scenario-unit-build", name, build, target] = SOME (protect (Scenarios.unitBuild (context "units") name build target))
    | command ["scenario-unit-load", name, target] = SOME (protect (Scenarios.unitLoad (context "units") name target))
    | command ["scenario-unit-warm", name, target] = SOME (protect (Scenarios.unitWarm (context "units") name target))
    | command ["scenario-unit-loader", target, name] = SOME (protect (Scenarios.loader (context "units") target name))
    | command ["scenario-install", name] = SOME (protect (InstallChecks.installed name))
    | command ["scenario-dist-prepare"] = SOME (protect DistChecks.setup)
    | command ["scenario-dist-archives"] = SOME (protect DistChecks.archives)
    | command ["scenario-dist-metadata"] = SOME (protect DistChecks.rejectedMetadata)
    | command ["scenario-dist-installer"] = SOME (protect DistChecks.installer)
    | command ["scenario-dist-binaries"] = SOME (protect DistChecks.binaryHeaders)
    | command ["scenario-dist-windows"] = SOME (protect DistChecks.windows)
    | command ["scenario-archive-faults"] = SOME (protect ArchiveCheck.faults)
    | command _ = NONE
  fun tagged tags tree = List.foldl (fn (tag, tree) => Test.tag tag tree) tree tags
  fun job name args after pools = Test.it name {program = "/bin/sh",
    args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-scenarios " ^ String.concatWith " " (List.map quote args)],
    env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 3600, cap = 0, cpus = 1,
    memory = 1000, pools = pools, exclusive = false, after = after, judge = failLines} : Run.command Test.tree
  fun group name tag covers nodes = tagged ["check", tag, "scenarios-" ^ name, "covers:" ^ covers]
                                           (Test.describe name nodes)
  fun tree () =
    let val deps = group "deps" "test-deps" "tests/deps/*"
          (job "prepare" ["scenario-prepare", "deps"] [] [] :: List.map
            (fn name => job name ["scenario-deps", name] ["scenarios/deps/prepare"] []) Scenarios.depsCases)
        val builds = group "buildfile" "test-build" "tests/buildfile/*"
          (job "prepare" ["scenario-prepare", "buildfile"] [] [] :: List.map
            (fn name => job name ["scenario-buildfile", name] (["scenarios/buildfile/prepare"]
                    @ (if name = "missing-variable" then ["scenarios/buildfile/path-variable"] else [])) []) Scenarios.buildCases)
        val dynamic = group "dynamic" "test-dynamic" "tests/dynamic/*"
          (List.map (fn name => job name ["scenario-dynamic", name] [] []) Scenarios.dynamicCases)
        fun cold name build target = name ^ "/" ^ build ^ "/" ^ target
        fun warm name target = name ^ "/warm/" ^ target
        fun unit name build target =
          let val path = cold name build target
              val expected = fromRoot ("tests/units/" ^ name ^ "/" ^
                 (if build = "whole" andalso exists (fromRoot ("tests/units/" ^ name ^ "/whole.expected")) then "whole.expected" else "expected"))
              val valid = String.isSubstring "compile: 0\n" (read expected)
          in job path ["scenario-unit-build", name, build, target] ["scenarios/units/prepare"] ["unit-scenario-cache"]
             :: (if build <> "units" orelse not valid then [] else
                  [job (name ^ "/loaded/" ^ target) ["scenario-unit-load", name, target] ["scenarios/units/" ^ path] [],
                   job (warm name target) ["scenario-unit-warm", name, target] ["scenarios/units/" ^ path] ["unit-scenario-cache"]]) end
        fun loader target name =
          let val other = if target = "stack" then "registers" else "stack"
              val after = ["scenarios/units/" ^ cold "twice" "units" target]
                 @ (if name = "other-compile" then ["scenarios/units/" ^ cold "across" "units" target] else [])
                 @ (if name = "other-set" then ["scenarios/units/" ^ cold "twice" "units" other] else [])
                 @ (if name = "restored" then ["scenarios/units/loader/" ^ target ^ "/saved"] else [])
          in job ("loader/" ^ target ^ "/" ^ name) ["scenario-unit-loader", target, name] after [] end
        val units = group "units" "check-units" "tests/units/*"
          (job "prepare" ["scenario-prepare", "units"] [] []
            :: List.concat (List.map (fn name => List.concat (List.map (fn build =>
                   List.concat (List.map (unit name build) Scenarios.targets)) ["whole", "units"])) (Scenarios.unitNames ()))
            @ List.concat (List.map (fn target => List.map (loader target) Scenarios.loaderCases) Scenarios.targets))
        val installHosts = String.tokens (fn c => c = #",") (env ("SCENARIO_INSTALL_HOSTS", "rbc,mlton,smlnj-legacy"))
        val install = group "install" "test-install" "tests/install/*"
          (List.map (fn name => Test.requires (["native-host"] @ (if name = "rbc" then [] else [name]))
                 (job name ["scenario-install", name] [] [])) installHosts)
        val dist = Test.requires ["python3", "gzip", "unzip", "tar"] (group "dist" "test-dist" "tests/dist/*"
          [job "prepare" ["scenario-dist-prepare"] [] [],
           job "archives" ["scenario-dist-archives"] ["scenarios/dist/prepare"] [],
           job "metadata" ["scenario-dist-metadata"] ["scenarios/dist/prepare"] [],
           job "installer" ["scenario-dist-installer"] ["scenarios/dist/archives"] [],
           job "binaries" ["scenario-dist-binaries"] ["scenarios/dist/prepare"] [],
           job "faults" ["scenario-archive-faults"] [] [],
           Test.requires ["windows-installer"] (job "windows" ["scenario-dist-windows"] ["scenarios/dist/archives"] [])])
    in Test.describe "scenarios" [deps, builds, dynamic, units, install, dist] end
  val capabilities =
    [{name = "gzip", probe = "command -v gzip", hint = "install gzip for distribution decoding"},
     {name = "unzip", probe = "command -v unzip", hint = "install unzip for distribution decoding"},
     {name = "tar", probe = "command -v tar", hint = "install tar for distribution extraction"},
     {name = "windows-installer", probe = "command -v cmd.exe && bin/rune-windows directory",
      hint = "Windows interop and a staging directory from RUNE_WINDOWS_DIR"}]
end

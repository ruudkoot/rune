structure ForeignModelJobs =
struct
  fun job name args tags after =
    List.foldl(fn(tag,tree)=>Test.tag tag tree)
      (Test.it name {program="/bin/sh",args=["sh","-c","exec bin/rune-ffi-model-check " ^ args],
        env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 1800,cap=0,cpus=1,memory=2500,
        pools=if String.isSuffix "mlkit" args orelse String.isSuffix "-nori" args then ["matrix"] else [],exclusive=false,after=after,judge=Sh.failLines}:Run.command Test.tree)
      (tags @ ["covers:lib/ffi/model/*","covers:tests/ffi/*","covers:ffi/*"])
  val tree=Test.describe "ffi/model"
    [Test.requires["cc"](job "native" "native" ["check","test-ffi-model"] []),
     Test.requires["windows-sdk"](Test.describe "windows" (List.map(fn bits=>job bits ("windows " ^ bits)
       ["test-ffi-model-windows"] []) ["32","64"])),
     Test.requires["host:mlkit"](job "mlkit-no-ri" "model-nori" ["test-ffi-model-hosts","library","nightly"] []),
     Test.requires["host:mlkit"](job "target-mlkit-no-ri" "target-nori" ["test-ffi-model-hosts","library","nightly"] []),
     job "prepare-goldens" "goldens-prepare" ["test-ffi-model-hosts"] [],
     Test.describe "hosts" (List.map(fn name=>Test.requires["host:" ^ name]
       (job name ("goldens " ^ name) ["test-ffi-model-hosts","library","nightly"] ["ffi/model/prepare-goldens"])) Hosts.names)]
  fun generatorJob name arguments tags=
    List.foldl(fn(tag,tree)=>Test.tag tag tree)
      (Test.it name {program="/bin/sh",args=["sh","-c","exec bin/rune-ffi-generator-check " ^ arguments],
        env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 1800,cap=0,cpus=1,memory=3000,
        pools=["matrix"],exclusive=false,after=[],judge=Sh.failLines}:Run.command Test.tree)
      (tags @ ["covers:src/ffi/*","covers:lib/ffi/model/*","covers:lib/ffi/runtime/*","covers:tests/ffi/generator/*"])
  val executionCheck=if RuneForeign.available() then ["check"] else []
  val tree=Test.describe ""
    [tree,Test.describe "ffi/generator"
      [Test.requires["cc","ffi-runtime"](generatorJob "native" "native" (executionCheck @ ["test-ffi-generator"])),
       generatorJob "publication" "publication" ["check","test-ffi-generator"],
       Test.requires["windows"](Test.describe "windows" (List.map(fn bits=>generatorJob bits ("windows " ^ bits)
         ["test-ffi-generator-windows","windows","nightly"]) ["32","64"])),
       Test.requires["host:mlkit"](generatorJob "mlkit-no-ri" "host mlkit-no-ri" ["test-ffi-generator-hosts","library","nightly"]),
       Test.requires["cc","ffi-runtime"](generatorJob "safe" "safe" (executionCheck @ ["test-ffi-generator"])),
       Test.requires["cc","ffi-runtime"](generatorJob "safe-asan" "safe-asan" ["test-ffi-generator-asan","vm","nightly"]),
       Test.describe "hosts" (List.map(fn name=>Test.requires["host:" ^ name]
         (generatorJob name ("host " ^ name)["test-ffi-generator-hosts","library","nightly"]))Hosts.names)]]
end

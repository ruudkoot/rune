structure ForeignModelJobs =
struct
  fun job name args tags after =
    List.foldl(fn(tag,tree)=>Test.tag tag tree)
      (Test.it name {program="/bin/sh",args=["sh","-c","exec bin/rune-ffi-model-check " ^ args],
        env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 1800,cap=0,cpus=1,memory=2500,
        pools=if String.isSuffix "mlkit" args orelse args="model-nori" then ["matrix"] else [],exclusive=false,after=after,judge=Sh.failLines}:Run.command Test.tree)
      (tags @ ["covers:lib/ffi/model/*","covers:tests/ffi/*","covers:ffi/*"])
  val tree=Test.describe "ffi/model"
    [Test.requires["cc"](job "native" "native" ["check","test-ffi-model"] []),
     Test.requires["windows-sdk"](Test.describe "windows" (List.map(fn bits=>job bits ("windows " ^ bits)
       ["test-ffi-model-windows"] []) ["32","64"])),
     Test.requires["host:mlkit"](job "mlkit-no-ri" "model-nori" ["test-ffi-model-hosts","library","nightly"] []),
     job "prepare-goldens" "goldens-prepare" ["test-ffi-model-hosts"] [],
     Test.describe "hosts" (List.map(fn name=>Test.requires["host:" ^ name]
       (job name ("goldens " ^ name) ["test-ffi-model-hosts","library","nightly"] ["ffi/model/prepare-goldens"])) Hosts.names)]
end

(* IntInf verdicts are inventory cases. Optional wall-clock measurements are
   selected explicitly and run exclusively, outside the deterministic tier. *)
structure IntInfJobs =
struct
  open Sh
  fun tagged tags tree=List.foldl (fn (tag,tree) => Test.tag tag tree) tree tags
  fun job name args exclusive = Test.it name {program="/bin/sh",
       args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-intinf " ^ String.concatWith " " (List.map quote args)
                ^ " --out \"$RUNE_TEST_RUN/intinf/" ^ name ^ "\""],env=NONE,dir=SOME ".",stdin=NONE,
       timeout=Time.fromSeconds (if exclusive then 7200 else 1800),cap=0,cpus=1,memory=1500,pools=[],exclusive=exclusive,after=[],judge=failLines} : Run.command Test.tree
  fun one name tags args=tagged ("check" :: "covers:tests/intinf/*" :: "covers:tests/runner/intinf*.sml" :: tags) (job name args false)
  val native=env ("NATIVE_HOST","no")="yes"
  val tree=Test.describe "intinf"
      [one "semantics/registers" ["test-intinf"] ["run"],
       one "storage/stack" ["test-intinf"] ["storage"],
       one "backends/default" ["test-intinf-backends"] ["backends"],
       one "options/runtime" ["test-intinf-backends"] ["options"],
       one "options/gmp-free" ["test-intinf-backends"] ["options","--vm","bin/runevm-sml"],
       one "hardening/runtime" ["test-intinf-hardening"] (["hardening"] @ (if native then ["--native"] else [])),
       one "hardening/gmp-free" ["test-intinf-hardening"] ["hardening","--vm","bin/runevm-sml"],
       one "faults" ["test-intinf"] ["faults"],
       Test.requires ["python3"] (one "build-config" ["test-intinf-backends"] ["build-config"]),
       tagged ["intinf-measurements"] (job "measurements" ["measure","--paired-sml"] true)]
end

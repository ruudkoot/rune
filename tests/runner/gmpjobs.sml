(* Dependency checks are ordinary cases; binary-mutating preparation and
   installation experiments remain explicitly selected, exclusive actions. *)
structure GMPJobs =
struct
  open Sh
  fun tags names tree=List.foldl (fn (name,tree) => Test.tag name tree) tree names
  fun judge (result,files)=case failLines (result,files) of SOME failure => SOME failure | NONE =>
       if String.isPrefix "SKIP " (read (#stdout files)) then SOME ("SKIP",firstNonEmpty (#stdout files)) else NONE
  fun job name args exclusive =
    Test.it name {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-intinf " ^ String.concatWith " " (List.map quote args)
                ^ " --out \"$RUNE_TEST_RUN/gmp/" ^ name ^ "\""],env=NONE,dir=SOME ".",stdin=NONE,
       timeout=Time.fromSeconds (if exclusive then 7200 else 1800),cap=0,cpus=1,memory=1500,pools=[],exclusive=exclusive,after=[],judge=judge} : Run.command Test.tree
  fun tagged name tier args exclusive=tags [tier,"covers:tests/intinf/*","covers:tests/runner/gmp*.sml",
       "covers:scripts/*gmp*","covers:build/deps/gmp/*"] (job name args exclusive)
  val tree=Test.describe "gmp"
      [Test.requires [] (tags ["check"] (tagged "downloads" "test-intinf-dependency" ["downloads"] false)),
       Test.requires ["cc"] (tags ["check"] (tagged "dependency" "test-intinf-dependency" ["dependency"] false)),
       Test.requires ["qemu-x86_64"] (tagged "cpu-family" "gmp-cpu-family" ["cpu-family"] false),
       Test.requires ["cc"] (tagged "build-modes" "gmp-build-modes" ["build-modes"] true),
       tagged "prepare-cross" "gmp-prepare-cross" ["prepare-cross"] true]
  val capabilities=[{name="qemu-x86_64",probe="command -v qemu-x86_64",hint="install QEMU user-mode tools"}]
end

(* Timing runs are explicit, exclusive selections and never tagged check. *)
structure MeasurementJobs =
struct
  open Sh
  fun command name args exclusive =Test.it name {program=fromRoot "bin/rune-measure",args=fromRoot "bin/rune-measure"::args,
       env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 3600,cap=0,cpus=1,memory=1500,pools=[],exclusive=exclusive,after=[],judge=failLines} : Run.command Test.tree
  val tree=Test.describe "measurement"
    [Test.tag "measurement-runs" (command "benchmark-fresh" ["benchmarks","time","--profile","smoke","--filter","=tak","--configs","rune","--samples","2"] true),
     Test.tag "measurement-runs" (command "benchmark-repeated" ["benchmarks","time","--profile","smoke","--filter","=tak","--configs","rune","--samples","2","--mode","repeated","--repetitions","3"] true),
     Test.tag "check" (Test.tag "quick" (Test.tag "covers:tools/measure/*" (command "mmu-oracles" ["mmu","--self-test"] false)))]
end

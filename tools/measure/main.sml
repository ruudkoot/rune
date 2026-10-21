structure MeasureMain =
struct
  fun rooted action args=(OS.FileSys.chDir Sh.root;action args)
  fun main ["--help"]=(Sh.say "rune-measure MODE [ARGS]\nSee tools/measure/README.md for modes, inputs and instrumentation contracts.\n";0)
    | main ("intinf-compilers"::args)=rooted MeasureIntInfCompare.compilers args
    | main ("intinf-kernels"::args)=rooted MeasureIntInfCompare.kernels args
    | main ("intinf-paths"::args)=rooted MeasureIntInfCompare.paths args
    | main ("intinf-design"::args)=rooted MeasureIntInfDesign.main args
    | main ("intinf-dispatch"::args)=rooted MeasureIntInfDispatch.main args
    | main ("intinf-conversion"::args)=rooted MeasureIntInfConversion.main args
    | main ("perf-cycles"::args)=rooted MeasurePerfCycles.main args
    | main ("perf-units"::args)=rooted MeasurePerfUnits.main args
    | main ("gc-probe32"::args)=rooted MeasureGCProbe.main args
    | main ("gcbench-roadmap"::args)=MeasureGCRoadmap.main args
    | main ("layout-measure"::args)=MeasureLayoutMeasure.main args
    | main ("layout-micro"::args)=MeasureLayoutMeasure.micro args
    | main ("benchmarks"::args)=rooted MeasureBenchmarks.main args
    | main ("gcbench-measure"::args)=MeasureGCMeasure.main args
    | main ("gcbench-report"::args)=MeasureGCReport.main args
    | main ("sim-report"::args)=MeasureSimReport1.main args
    | main ("sim-report2"::args)=MeasureSimReport2.main args
    | main ("sim-report3"::args)=MeasureSimReport3.main args
    | main ("layout-tables"::args)=MeasureLayoutTables.main args
    | main ("validate2"::args)=MeasureSimValidate.main false args
    | main ("validate-proto"::args)=MeasureSimValidate.main true args
    | main ("pretenure"::args)=MeasureSimValidate.pretenure args
    | main ("sweep"::args)=rooted (MeasureSimSweeps.main true) args
    | main ("sweep2"::args)=MeasureSimSweeps.main false args
    | main ("pauses"::args)=MeasurePauses.main args
    | main ("timeline"::args)=MeasureTimeline.main args
    | main ("checkold"::args)=MeasureCheckOld.main args
    | main ("gcbench-tables"::args)=MeasureGCTables.main args
    | main ("lex-corpus"::args)=MeasureLexCorpus.main args
    | main ("perf-repl"::args)=rooted MeasurePerfRepl.main args
    | main ("hol-kernel"::args)=MeasureHOL.kernel args
    | main ("hol-theory"::args)=MeasureHOL.theory args
    | main ("jit-dump"::args)=MeasureJitDump.main args
    | main ("gc-eval"::args)=rooted MeasureGCEval.main args
    | main ("census"::args)=rooted MeasureCensus.main args
    | main ("gc-eval-score"::args)=MeasureGCScore.main args
    | main ("mmu"::args)=MeasureMMUCli.main args
    | main ("elab-stats"::args)=MeasureProfile.elab args
    | main ("perf-groups"::args)=MeasureProfile.perf args
    | main ("opt"::args)=MeasureBasics.opt args
    | main ("bisect-fuel"::args)=rooted MeasureBasics.bisect args
    | main ["provenance",role,tool,bundle]=MeasureBasics.provenance role tool bundle
    | main ["classify",status,directory,failure]=
         (Sh.say (MeasureCommon.category {status=MeasureCommon.integer status,output=Sh.read (directory ^ "/stdout"),errors=Sh.read (directory ^ "/stderr"),failure=failure} ^ "\n");0)
    | main ["validate",status,directory,rounds]=
         (Sh.say (MeasureCommon.validate {status=MeasureCommon.integer status,output=Sh.read (directory ^ "/stdout"),errors=Sh.read (directory ^ "/stderr"),rounds=MeasureCommon.integer rounds} ^ "\n");0)
    | main _=raise MeasureCommon.Usage "rune-measure MODE [ARGS]"
end
val ()=let val status=MeasureMain.main (CommandLine.arguments ())
       in if status=0 then () else Posix.Process.exit (Word8.fromInt status) end
       handle e => (Sh.say ("measurement: " ^ (case e of MeasureCommon.Failed text => text | MeasureCommon.Usage text => text | Fail text => text | _ => General.exnMessage e) ^ "\n");
                    Posix.Process.exit (case e of MeasureCommon.Usage _ => 0w2 | _ => 0w1))

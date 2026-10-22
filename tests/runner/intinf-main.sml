structure IntInfMain =
struct
  open Sh
  exception Usage of string
  fun main ["workload","--spec",spec]=IntInfFixtures.workload (Json.decode spec)
    | main (suite :: args)=
    let val base=IntInfChecks.create suite
        val compiler=ref (#compiler base)
        val vm=ref (if suite="storage" then fromRoot "bin/runevm-stack" else #vm base)
        val smlVM=ref (#smlVM base)
        val target=ref (#target base)
        val directory=ref ""
        val vmOptions=ref (#vmOptions base)
        val stress=ref (#stress base)
        val bench=ref (suite="measure")
        val pairedOracle=ref false
        val pairedSML=ref false
        val compilerWorkloads=ref false
        val samples=ref 5
        val prefix=ref "build/deps/gmp/native"
        val jobs=ref 4
        val platforms=ref []
        val cpus=ref []
        val requireAll=ref false
        val freeVMs=ref ""
        val installMode=ref ""
        val forkOnly=ref false
        val native=ref false
        val allocation=ref (fromRoot "build/intinf-alloc-test")
        fun parse []=()
          | parse ("--prefix" :: value :: rest)=(prefix:=value;parse rest)
          | parse ("--jobs" :: value :: rest)=(jobs:=(case Int.fromString value of SOME n => n | NONE => raise Usage "invalid job count");parse rest)
          | parse ("--platform" :: value :: rest)=(platforms:= !platforms @ [value];parse rest)
          | parse ("--cpu" :: value :: rest)=(cpus:= !cpus @ [value];parse rest)
          | parse ("--require-all" :: rest)=(requireAll:=true;parse rest)
          | parse ("--sml-vms" :: value :: rest)=(freeVMs:=value;parse rest)
          | parse ("--mode" :: value :: rest)=(installMode:=value;parse rest)
          | parse ("--rune" :: value :: rest)=(compiler:=fromRoot value;parse rest)
          | parse ("--vm" :: value :: rest)=(vm:=fromRoot value;parse rest)
          | parse ("--sml-vm" :: value :: rest)=(smlVM:=fromRoot value;parse rest)
          | parse ("--target" :: value :: rest)=(target:=value;parse rest)
          | parse ("--vm-options" :: value :: rest)=(vmOptions:=CommandWords.split value;parse rest)
          | parse ("--out" :: value :: rest)=(directory:=fromRoot value;parse rest)
          | parse ("--alloc-test" :: value :: rest)=(allocation:=fromRoot value;parse rest)
          | parse ("--samples" :: value :: rest)=(samples:=(case Int.fromString value of SOME n => n | NONE => raise Usage "invalid sample count");parse rest)
          | parse ("--stress" :: rest)=(stress:=true;parse rest)
          | parse ("--bench" :: rest)=(bench:=true;parse rest)
          | parse ("--paired-oracle" :: rest)=(pairedOracle:=true;parse rest)
          | parse ("--paired-sml" :: rest)=(pairedSML:=true;parse rest)
          | parse ("--compiler-workloads" :: rest)=(compilerWorkloads:=true;parse rest)
          | parse ("--fork-only" :: rest)=(forkOnly:=true;parse rest)
          | parse ("--native" :: rest)=(native:=true;parse rest)
          | parse (arg :: rest)=if String.isPrefix "--vm-options=" arg then (vmOptions:=CommandWords.split (String.extract (arg,13,NONE));parse rest)
                else raise Usage ("unknown or incomplete option " ^ arg)
        val ()=parse args
        val ()=if !samples>=2 andalso not (!pairedOracle andalso !pairedSML) then () else raise Usage "at least two samples and at most one paired reference are required"
        val ()=if !target="registers" orelse !target="stack" then () else raise Usage "target must be registers or stack"
        val output=if !directory<>"" then !directory else fromRoot ("tests/out/intinf/" ^
                     (if suite="run" orelse suite="measure" then "current" else if suite="prepare-cross" then "cross-builds" else if suite="storage" then "storage-" ^ OS.Path.file (!vm) else suite))
        val ()=if suite="install" andalso (!directory="" orelse !installMode="") then raise Usage "install requires --mode and --out" else ()
        val c={directory=output,compiler= !compiler,vm= !vm,smlVM= !smlVM,target= !target,vmOptions= !vmOptions,stress= !stress,sequence=ref 0} : IntInfChecks.context
    in case suite of
        "run" => if !bench then IntInfMeasurements.one c {samples= !samples,pairedOracle= !pairedOracle,pairedSML= !pairedSML,compilerWorkloads= !compilerWorkloads} ()
                 else (ignore (IntInfChecks.semantic c (#vm c) []);say "PASS IntInf independent arithmetic corpus\n")
      | "measure" => IntInfMeasurements.one c {samples= !samples,pairedOracle= !pairedOracle,pairedSML= !pairedSML,compilerWorkloads= !compilerWorkloads} ()
      | "storage" => IntInfStorage.one c ()
      | "backends" => IntInfBackends.one c ()
      | "hardening" => IntInfHardening.one c (!forkOnly) (!native) (!allocation) ()
      | "options" => IntInfChecks.options c ()
      | "build-config" => GMPChecks.config c ()
      | "downloads" => GMPDownloadChecks.one c ()
      | "dependency" => GMPChecks.dependency c (!platforms) (!requireAll) ()
      | "cpu-family" => GMPChecks.cpuFamily c (!cpus) ()
      | "build-modes" => GMPChecks.buildModes c (!prefix) ()
      | "install" => GMPInstallChecks.one c (!installMode) ()
      | "prepare-cross" => GMPPlatformChecks.prepare c (!prefix) (!jobs) ()
      | "cross" => if !freeVMs="" then raise Usage "cross requires --sml-vms"
                   else GMPPlatformChecks.cross c (!freeVMs) (!platforms) ()
      | "faults" => IntInfFaults.one c ()
      | _ => raise Usage "run [--bench] | storage | backends | hardening | options"
    end
    | main []=raise Usage "run [--bench] | storage | backends | hardening | options"
  fun message (Usage text)=text | message (IntInfChecks.Failed text)=text
    | message (Measured.Failed text)=text | message (BytecodeFixture.Bad text)=text
    | message (CommandWords.Invalid text)=text | message (Incremental.Failed text)=text
    | message e=General.exnMessage e
end
val ()=(IntInfMain.main (CommandLine.arguments ()) handle e =>
        (Sh.say ("FAIL IntInf controller: " ^ IntInfMain.message e ^ "\n");Posix.Process.exit 0w1))

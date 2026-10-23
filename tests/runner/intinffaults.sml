(* Planted false-success answers and policies exercise the complete SML
   controllers. Fixtures remain private; production goldens are never edited. *)
structure IntInfFaults =
struct
  open IntInfChecks
  fun executable file body=(write (file,"#!/bin/sh\n" ^ body ^ "\n");Posix.FileSys.chmod (file,
      Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr]))
  fun context c suffix vm : IntInfChecks.context =
    {directory=path c suffix,compiler= #compiler c,vm=vm,smlVM= #smlVM c,target="registers",vmOptions=[],stress=false,sequence=ref 0}
  fun expected label action =
    need (((action ();false) handle IntInfChecks.Failed _ => true | Measured.Failed _ => true),"IntInf controller accepted planted " ^ label)
  fun one (c : context) () =
    let val ()=mkdirs (#directory c)
        val magic="runevm image 15 isa 0123abcd\000"
        val prefix=BytecodeFixture.u32 1 ^ BytecodeFixture.le 8 1 ^ String.implode(List.tabulate(64,fn _=> #"\000"))
        val image=magic ^ prefix
        val layout=IntInfHardening.savedPolicyLayout image
        val ()=need(#start layout=size magic andalso #mode layout=36 andalso #stats layout=40 andalso
          #bits layout=60 andalso #memory layout=68 andalso #finish layout=76,"image-15 saved policy field positions differ")
        fun invalidImage label bytes=expected label(fn()=>ignore(IntInfHardening.savedPolicyLayout bytes))
        val ()=List.app(fn version=>invalidImage "unsupported image version"
          ("runevm image " ^ version ^ " isa 0123abcd\000" ^ prefix))["14","16"]
        val ()=invalidImage "truncated image prefix"(String.substring(image,0,size image-1))
        val ()=invalidImage "missing image terminator" "runevm image 15 isa 0123abcd"
        val ()=invalidImage "invalid image fingerprint"("runevm image 15 isa not-hex!\000" ^ prefix)
        val ()=invalidImage "fork image used as saved policy"(magic ^ BytecodeFixture.u32 0 ^ String.extract(prefix,4,NONE))
        val ()=invalidImage "zero foreign identity floor"(magic ^ BytecodeFixture.u32 1 ^ BytecodeFixture.le 8 0 ^ String.extract(prefix,12,NONE))
        (* A skipped optional dependency still writes its report. Use a
           private empty root so the case is independent of installed pins
           and no compilation happens to create the output directory. *)
        val missing=path c "missing-dependency-output"
        val emptyRoot=path c "empty-root"
        val ()=(rmTree missing;mkdirs emptyRoot)
        fun dependency label options=GMPChecks.process c label root 30 [("RUNE_TEST_ROOT",emptyRoot)]
              ([fromRoot "bin/rune-intinf","dependency","--out",missing] @ options)
        val optional=dependency "optional-dependency" []
        val ()=success optional
        val report=Json.decode (read (missing ^ "/report.json"))
        val ()=need (field "result" (field "native" report)=Json.String "not installed",
                     "missing optional dependency did not write its report")
        val required=dependency "required-dependency" ["--require-all"]
        val ()=need (#status required<>0 andalso String.isSubstring "missing pinned GMP dependency: native" (#output required),
                     "missing required dependency was not rejected explicitly")
        val poisoned=path c "poisoned-vectors.sml"
        val ()=write (poisoned,Incremental.replace (read (fromRoot "tests/intinf/fixtures/vectors.sml")) "\"~16\"" "\"~15\"")
        val ()=expected "wrong arithmetic answer on GMP-free VM" (fn () =>
              ignore (semanticWithVectors (context c "poison-sml" (#smlVM c)) (#smlVM c) ["--intinf=sml"] poisoned))
        val ()=if not (hasGMP c) then () else expected "wrong arithmetic answer on GMP" (fn () =>
              ignore (semanticWithVectors (context c "poison-gmp" (#vm c)) (#vm c) ["--intinf=gmp"] poisoned))
        val fake=path c "false-success"
        val ()=executable fake "exit 0"
        val ()=expected "finite option policy" (IntInfChecks.options (context c "bad-options" fake))
        val ()=expected "storage boundary" (IntInfStorage.one (context c "bad-storage" fake))
        val fork=path c "bad-fork"
        val ()=executable fork "case $1 in --version) printf 'RuneVM fixture\\n' ;; *) printf 'child policy changed\\nparent pass\\n' ;; esac"
        val ()=expected "fork policy" (IntInfHardening.one (context c "bad-fork-policy" fork) true false fake)
        val ()=expected "allocation false success" (IntInfHardening.one (context c "bad-allocation" (#vm c)) false false fake)
        val measurement=path c "bad-measurement"
        val ()=executable measurement "case $1 in --version) printf 'RuneVM fixture\\n' ;; *)\nlast=''; for arg do last=$arg; done\ncase $last in *checks.rbc) printf 'current: 1154 checks\\noracle: 1154 checks\\n' ;; *) printf 'TIMING 0.01\\nWRONG\\n' ;; esac ;; esac"
        val ()=expected "measurement answer" (IntInfMeasurements.one (context c "bad-measurement-answer" measurement)
                      {samples=2,pairedOracle=false,pairedSML=false,compilerWorkloads=false})
        val ()=need (Real.== (Measured.median [1.0,3.0,2.0,4.0],2.5),"measurement median differs")
        val ()=need (CommandWords.split "--name 'two words' --path=a\\ b \"\""=["--name","two words","--path=a b",""],"quoted VM options changed")
    in say "PASS IntInf independent-answer, storage, fork, limit, allocation and measurement faults\n" end
end

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

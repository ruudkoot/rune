structure BuildMain =
struct
  open BuildCommon
  fun main ("configure-gmp"::args)=BuildGMPConfig.main args
    | main ("build-ffi"::args)=BuildFFIDeps.main args
    | main ("build-gmp"::args)=BuildGMP.main args
    | main ("build-gmp-vm"::args)=BuildCrossVM.main args
    | main ("check-windows-imports"::args)=BuildCrossVM.imports args
    | main ("record-vm-build"::args)=BuildRuntimeRecord.main args
    | main ("package-runtime"::args)=BuildPackageRuntime.main args
    | main ("make-dist"::args)=BuildDist.main args
    | main ("setup-mlton"::args)=BuildSetupMLton.main args
    | main ("relink"::args)=BuildRelink.main args
    | main ["--help"]=(say "rune-build MODE [ARGS]\nModes: configure-gmp, build-gmp [download], build-ffi libffi|sdl, build-gmp-vm, record-vm-build,\npackage-runtime, make-dist, setup-mlton, relink, check-windows-imports. See tools/builder/README.md.\n";0)
    | main _=raise Usage "rune-build MODE [ARGS]"
  fun run () =
    let val ()=BuildIO.initialize ()
        val status=(main (CommandLine.arguments ()) handle e =>
             (warn ("rune-build: " ^ (case e of Failed text => text | Usage text => text | BuildGMP.CommandFailed text => text | BuildIO.Interrupted => "interrupted" | BuildIO.TimedOut _ => "command timed out" | _ => General.exnMessage e) ^ "\n");
              case e of Usage _ => 2 | _ => 1))
    in if status=0 then () else Posix.Process.exit (Word8.fromInt status) end
end
val ()=BuildMain.run ()

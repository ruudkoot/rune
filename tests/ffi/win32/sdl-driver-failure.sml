(* Run with an intentionally unavailable SDL_VIDEODRIVER. Failed startup must
   close every prepared call, symbol, library and partially initialized SDL. *)
structure Driver=Win32SdlDriverFn(structure Sdl=SDL)
structure Win32SDLFailureChecks =
struct
  fun paths []=[] | paths("--runeffi-constants"::_)=[] | paths(path::rest)=path::paths rest
  fun main arguments=
    let val baseline=RuneForeign.live()
        val failed=(Driver.load(paths arguments);false) handle Win32Common.Types.Unsupported _=>true
        val ()=if failed then () else raise Fail "unavailable video driver was accepted"
        val ()=if RuneForeign.live()=baseline then () else raise Fail "failed video startup leaked native resources"
    in print "PASS SDL Win32 failed initialization: all native identities released\n" end
end
val ()=Win32SDLFailureChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL SDL Win32 failed initialization: " ^ General.exnMessage e ^ "\n");OS.Process.exit OS.Process.failure)

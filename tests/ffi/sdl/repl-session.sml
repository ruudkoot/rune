(* Loaded as an ordinary source file in the existing REPL. Later -e entries
   compile new declarations and collect while these native objects remain. *)
structure SDLReplAcceptance =
struct
  val baseline=RuneForeign.live()
  val ()=if baseline=0w0 then () else raise Fail "REPL started with native resources"
  val retained=ref(NONE:(SDL.window * SDL.renderer * Word32.word) option)
  val collections=ref 0
  val sessions=ref 0
  fun need message ok=if ok then () else raise Fail message
  fun required name=case OS.Process.getEnv name of SOME value=>value | NONE=>raise Fail("missing " ^ name)
  fun beginSession()=
    let val ()=need "previous REPL session remains"(not(isSome(!retained)))
        val ()=SDL.load[required "RUNE_SDL_LIBRARY",required "RUNE_SDL_ADAPTER_LIBRARY"]
        val ()=SDL.init(Word32.fromLargeInt(SDL.constant "SDL_INIT_VIDEO"))
        val window=SDL.createWindow{title="Runeffi retained REPL window",width=160,height=120,flags=0w0}
        val renderer=SDL.createRenderer(window,SOME "software")
    in retained:=SOME(window,renderer,SDL.getWindowID window);
       collections:= #collections(Runtime.stats());sessions:= !sessions+1 end
  fun finishSession()=
    let val (window,renderer,id)=valOf(!retained)
        val ()=need "late declaration did not collect"(#collections(Runtime.stats())> !collections)
        val ()=need "retained REPL window changed identity"(SDL.getWindowID window=id andalso id<>0w0)
        val size=SDL.getWindowSize window
        val ()=need "retained REPL window geometry"(#width size=160 andalso #height size=120)
        val ()=SDL.setRenderDrawColor(renderer,{red=20,green=60,blue=100,alpha=255})
        val ()=SDL.renderClear renderer
        val ()=SDL.renderDebugText(renderer,4.0,4.0,"REPL after GC")
        val ()=SDL.renderPresent renderer
        val ()=SDL.destroyRenderer renderer
        val ()=SDL.destroyWindow window
        val ()=SDL.quit()
        val ()=SDL.unload()
        val ()=retained:=NONE
        val ()=need "REPL foreign resources leaked"(RuneForeign.live()=baseline)
    in print("PASS SDL REPL retained session " ^ Int.toString(!sessions) ^ ": native resources restored\n") end
end

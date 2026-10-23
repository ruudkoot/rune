(* Compile with ffi/sdl/native.build after running the documented generator.
   Arguments: SDL shared library path, generated adapter library path. *)
structure SDLHello =
struct
  fun main paths =
    let val ()=SDL.load paths
        val ()=SDL.init(Word32.fromLargeInt(SDL.constant "SDL_INIT_VIDEO"))
        val window=SDL.createWindow{title="Runeffi — SDL3",width=640,height=360,
          flags=Word64.fromLargeInt(SDL.constant "SDL_WINDOW_RESIZABLE")}
        val renderer=SDL.createRenderer(window,SOME "software")
        fun draw ()=
          (SDL.setRenderDrawColor(renderer,{red=24,green=28,blue=36,alpha=255});SDL.renderClear renderer;
           SDL.setRenderDrawColor(renderer,{red=90,green=180,blue=230,alpha=255});
           SDL.renderFillRect(renderer,SOME{x=32.0,y=56.0,width=160.0,height=64.0});
           SDL.setRenderDrawColor(renderer,{red=240,green=240,blue=245,alpha=255});
           SDL.renderDebugText(renderer,32.0,24.0,"Runeffi: Standard ML + SDL3");SDL.renderPresent renderer)
        fun loop ()=case SDL.waitEvent() of SDL.Quit=>() | _=>(draw();loop())
        fun close ()=(SDL.destroyRenderer renderer;SDL.destroyWindow window;SDL.quit();SDL.unload())
    in (draw();loop();close()) handle e=>(close();raise e) end
end
val ()=SDLHello.main(CommandLine.arguments())

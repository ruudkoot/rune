(* Bounded regeneration, native compilation and cross-engine SDL contracts. *)
structure SDLCoreChecks =
struct
  open Sh
  exception Failed of string
  fun need(ok,message)=if ok then () else raise Failed message
  val directory=run ^ "/ffi-sdl/" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
  fun command environment name args =
    let val ()=mkdirs directory val output=directory ^ "/" ^ name ^ ".out" val errors=output ^ ".err"
        val status=Children.exec Subprocess.unlimited environment
          {cmd=args,dir=SOME root,stdin="",stdout=output,stderr=errors,timeout=600}
    in need(status=0,name ^ " exited " ^ Int.toString status ^ ": " ^ read errors ^ read output);read output end
  fun run name args=command(fn e=>e)name args
  fun includes windows = if windows then
      let val sdk=env("RUNEFFI_WINDOWS_SDK","/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0")
      in List.map(fn s=>sdk ^ "/" ^ s)["um","shared","ucrt"] @
         [env("RUNEFFI_MSVC_INCLUDE","/mnt/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.40.33807/include")] end
    else [String.concat(String.tokens Char.isSpace(run "include-root" (String.tokens Char.isSpace(env("CC","cc")) @ ["-print-file-name=include"]))),
      "/usr/include/x86_64-linux-gnu","/usr/include"]
  val constants=["SDL_INIT_VIDEO","SDL_INIT_EVENTS","SDL_WINDOW_RESIZABLE","SDL_WINDOW_HIDDEN","SDL_WINDOW_FULLSCREEN",
    "SDL_EVENT_QUIT","SDL_EVENT_WINDOW_RESIZED","SDL_EVENT_WINDOW_FIRST","SDL_EVENT_WINDOW_LAST","SDL_EVENT_KEY_DOWN",
    "SDL_EVENT_KEY_UP","SDL_EVENT_TEXT_INPUT","SDL_EVENT_MOUSE_MOTION","SDL_EVENT_MOUSE_BUTTON_DOWN","SDL_EVENT_MOUSE_BUTTON_UP",
    "SDL_PIXELFORMAT_RGBA8888","SDL_PIXELFORMAT_ARGB8888"]
  fun supportConstants ()=case Json.member("constants",Json.decode(read "ffi/sdl/support.json")) of
      SOME(Json.Array values)=>List.map(fn Json.String s=>s | _=>raise Failed "SDL support constants must be strings")values
    | _=>raise Failed "missing SDL support constant inventory"
  fun generate target windows driver =
    let val output=directory ^ "/generated"
        val options=["generate","--config","ffi/sdl/core.ffi","--target","ffi/targets/" ^ target ^ ".json","--out",output] @
          List.concat(List.map(fn path=>["--include",path])("ffi/sdl/upstream"::includes windows)) @
          List.concat(List.map(fn name=>["--layout",name])["SDL_Event","SDL_Surface","SDL_Rect","SDL_FRect","SDL_TextInputEvent"]) @
          ["--field-get","SDL_Surface:pixels","--field-set","SDL_TextInputEvent:text"] @
          List.concat(List.map(fn name=>["--constant",name])(constants @ (if driver then supportConstants() else [])))
        val ()=ignore(run "generate" ("bin/runeffi"::options))
        val sets=entries(output ^ "/sets")
        val ()=need(length sets=1,"generation must publish exactly one immutable set")
    in (output,output ^ "/sets/" ^ hd sets ^ "/shims.c") end
  fun main [mode] =
    let val windows=String.isPrefix "windows" mode
        val narrow=mode="windows32"
        val gui=mode="gui-linux" orelse mode="win32-driver-gui"
        val failure=mode="win32-driver-failed-init"
        val driver=mode="win32-driver" orelse mode="win32-driver-gui" orelse failure
        val ()=need(List.exists(fn n=>n=mode)["native","asan","gui-linux","windows32","windows64","win32-driver","win32-driver-gui","win32-driver-failed-init"],"unknown SDL acceptance mode")
        val target=if narrow then "windows-x86" else if windows then "windows-x86_64" else "linux-x86_64"
        val (generated,shim)=generate target windows driver
        val cFacts=if not driver orelse failure then [] else
          let val source=directory ^ "/constants.c" val executable=directory ^ "/constants"
              val names=constants @ supportConstants()
              fun valid name=size name>0 andalso not(Char.isDigit(String.sub(name,0))) andalso
                CharVector.all(fn c=>Char.isAlphaNum c orelse c= #"_")name
              val ()=need(List.all valid names,"C constant names must be identifiers")
              val ()=write(source,"#include <stdio.h>\n#include <SDL3/SDL.h>\n#include <SDL3/SDL_main.h>\nint main(void) {\n" ^
                String.concat(List.map(fn name=>"  printf(\"" ^ name ^ "=%llu\\n\", (unsigned long long)(" ^ name ^ "));\n")names) ^ "  return 0;\n}\n")
              val ()=ignore(run "compile-constant-oracle" (String.tokens Char.isSpace(env("CC","cc")) @
                ["-std=c11","-Wall","-Wextra","-Werror","-DSDL_MAIN_HANDLED=1","-Iffi/sdl/upstream",source,"-o",executable]))
          in ["--runeffi-constants"] @ lines(run "constant-oracle"[executable]) end
        val library=env(if narrow then "RUNE_SDL_WINDOWS32_LIBRARY" else if windows then "RUNE_SDL_WINDOWS64_LIBRARY" else "RUNE_SDL_NATIVE_LIBRARY",
          "build/deps/sdl/" ^ (if narrow then "windows32" else if windows then "windows64" else "native") ^ "/install/" ^
          (if windows then "bin/SDL3.dll" else "lib/libSDL3.so.0"))
        val ()=need(exists library,"provision the pinned SDL3 target library or set RUNE_SDL_*_LIBRARY")
        val adapters=directory ^ (if windows then "/shims.dll" else "/shims.so")
        val compiler=env(if narrow then "WINCC32" else if windows then "WINCC" else "CC",
          if narrow then "i686-w64-mingw32-gcc" else if windows then "x86_64-w64-mingw32-gcc" else "cc")
        val ()=ignore(run "compile-adapters" (String.tokens Char.isSpace compiler @
          ["-shared","-Wall","-Wextra","-Werror","-DSDL_MAIN_HANDLED=1","-Iffi/sdl/upstream"] @
          (if windows then [] else ["-fPIC"]) @ [shim,"-o",adapters]))
        val environment=if windows orelse gui then fn e=>e else setEnv("SDL_VIDEODRIVER",if failure then "runeffi-unavailable-driver" else "dummy")
        fun path file=if not windows then fromRoot file else
          String.concat(String.tokens(fn c=>c= #"\r" orelse c= #"\n")(run "windows-path"["wslpath","-w",fromRoot file]))
        fun execute name vm options code =
          need(String.isSubstring (if failure then "PASS SDL Win32 failed initialization:" else if driver then "PASS SDL Win32 driver:" else "PASS SDL core:")(command environment name
            (vm::options @ [path code,path library,path adapters] @ cFacts)),"SDL semantic suite did not finish")
        fun one bytecode vm =
          let val code=directory ^ "/" ^ bytecode ^ ".rbc"
              val ()=ignore(run ("compile-" ^ bytecode)[env("RUNE","bin/rune"),"--library",if driver then "ffi/win32/sdldriver" else "sdl","--target=" ^ bytecode,
                "--build",if failure then "tests/ffi/win32/sdl-driver-failure.build" else if driver then "tests/ffi/win32/sdl-driver.build" else "tests/ffi/sdl/smoke.build","--path","SDL_GENERATED=" ^ fromRoot generated,"-o",code])
              val ()=execute (bytecode ^ "-stress") vm ["--gc-stress","7","--gc-verify"] code
          in if windows orelse mode="asan" orelse bytecode="stack" then () else
            (execute "baseline" vm ["--jit=baseline"] code;execute "opt" vm ["--jit=opt"] code) end
        val stack=if narrow then "bin/runevm-stack32.exe" else if windows then "bin/runevm-stack.exe" else if mode="asan" then "bin/runevm-stack-asan" else "bin/runevm-stack"
        val register=if narrow then "bin/runevm32.exe" else if windows then "bin/runevm.exe" else if mode="asan" then "bin/runevm-asan" else "bin/runevm"
        val ()=one "stack" stack val ()=one "registers" register
    in say("PASS SDL generated core acceptance: " ^ mode ^ "\n") end
    | main _=raise Failed "expected native, asan, gui-linux, windows32 or windows64"
end
val ()=SDLCoreChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL SDL acceptance: " ^ (case e of SDLCoreChecks.Failed s=>s | _=>General.exnMessage e) ^ "\n");OS.Process.exit OS.Process.failure)

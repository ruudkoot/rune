(* Existing REPL file arguments and repeated -e declarations only. Generation
   and native shim compilation are explicit prerequisites. *)
structure SDLReplChecks =
struct
  open Sh
  fun need(ok,message)=if ok then () else raise Fail message
  val (selected,adapter)=case CommandLine.arguments() of [set,shim]=>(OS.FileSys.fullPath set,OS.FileSys.fullPath shim)
    | _=>raise Fail "usage: rune-sdl-repl-check IMMUTABLE-GENERATED-SET ADAPTER-LIBRARY"
  val lib=OS.FileSys.fullPath(env("RUNE_LIB","lib"))
  val vm=OS.FileSys.fullPath(env("RUNEVM","bin/runevm"))
  val image=OS.FileSys.fullPath(env("RUNE_REPL_IMAGE","bin/rune-repl.img"))
  val library=OS.FileSys.fullPath(env("RUNE_SDL_NATIVE_LIBRARY","build/deps/sdl/native/install/lib/libSDL3.so.0"))
  val directory=let val reservation=OS.FileSys.tmpName()
      val path=run ^ "/sdl-repl/" ^ OS.Path.file reservation
      val ()=mkdirs path val ()=OS.FileSys.remove reservation
    in path end
  val librarySources=["unicode/utf8_sig.sml","unicode/utf8.sml"] @
    List.concat(List.map(fn(group,stems)=>List.concat(List.map(fn stem=>
      [group ^ "/" ^ stem ^ "_sig.sml",group ^ "/" ^ stem ^ ".sml"])stems))
      [("ffi/marshal",["scope","bytes","text"]),("ffi/runtime",["owner","memory","generated"])]) @
    ["sdl/raw_sig.sml","sdl/layout_sig.sml","sdl/sdl_sig.sml","sdl/sdl.sml"]
  val sourcePaths=List.map(fn path=>lib ^ "/" ^ path)librarySources @
    List.map(fn path=>selected ^ "/" ^ path)["raw_sig.sml","raw.sml","layout_sig.sml","layout.sml"] @
    [OS.Path.dir lib ^ "/ffi/sdl/instantiate.sml",fromRoot "tests/ffi/sdl/repl-session.sml"]
  fun hash path=Hex.fromBytes(Sha256.digest(read path))
  val hashes=List.map(fn path=>(path,hash path))(vm::image::library::adapter::sourcePaths)
  fun frozen(index,path)=let val target=directory ^ "/source-" ^ Int.toString index ^ ".sml"
    in write(target,read path);target end
  val inputs=List.map frozen(ListPair.zip(List.tabulate(length sourcePaths,fn n=>n),sourcePaths))
  val declarations=["SDLReplAcceptance.beginSession()",
    "val lateReplAllocation=List.tabulate(5000,fn n=>(n,Int.toString n)); fun lateReplIdentity x=x; val ()=Runtime.collect()",
    "SDLReplAcceptance.finishSession()","SDLReplAcceptance.beginSession()",
    "datatype lateReplType=LateRepl of int list; val laterReplAllocation=LateRepl(List.tabulate(7000,fn n=>n+1)); val ()=Runtime.collect()",
    "SDLReplAcceptance.finishSession(); val ()=if !SDLReplAcceptance.sessions=2 then print \"PASS SDL REPL two complete sessions\\n\" else raise Fail \"REPL session count\""]
  val arguments=[vm,"--jit=off","--gc-verify","--restore",image,"--","-q","--no-init"] @ inputs @
    List.concat(List.map(fn declaration=>["-e",declaration])declarations)
  val ()=write(directory ^ "/argv.json",Json.encodeIndented 2(Json.Array(List.map Json.String arguments)) ^ "\n")
  val started=Runtime.clock()
  val status=Children.exec Subprocess.unlimited
    (fn environment=>setEnv("RUNE_SDL_LIBRARY",library)(setEnv("RUNE_SDL_ADAPTER_LIBRARY",adapter)
      (unsetEnv["SDL_VIDEODRIVER"]environment)))
    {cmd=arguments,dir=SOME root,stdin="",stdout=directory ^ "/stdout",stderr=directory ^ "/stderr",timeout=600}
  val elapsed=Time.toReal(Time.-(Runtime.clock(),started))
  val output=read(directory ^ "/stdout")
  val errors=read(directory ^ "/stderr")
  val ()=write(directory ^ "/result.json",Json.encodeIndented 2(Json.Object[
    ("schema",Json.int 1),("status",Json.int status),("wallSeconds",Json.Number(Real.toString elapsed)),
    ("videoDriverOverride",Json.Null),("generatedSet",Json.String selected),
    ("sourceAndBinaryHashes",Json.Array(List.map(fn(path,digest)=>Json.Object[
      ("path",Json.String path),("sha256",Json.String digest)])hashes))]) ^ "\n")
  val ()=List.app(fn(path,digest)=>need(hash path=digest,"REPL input changed during execution: " ^ path))hashes
  val ()=need(status=0 andalso errors="" andalso
    List.all(fn marker=>String.isSubstring marker output)
      ["PASS SDL REPL retained session 1:","PASS SDL REPL retained session 2:","PASS SDL REPL two complete sessions"],
    "SDL GUI REPL acceptance failed: " ^ directory ^ "/stdout " ^ errors)
  val ()=say("PASS SDL GUI REPL retained resources, late declarations, full collection and two sessions: " ^ directory ^ "/result.json\n")
end

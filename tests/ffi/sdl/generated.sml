(* Reproducible checked-in SDL source artifacts. Native compilation and DLL
   provisioning remain separate explicit operations. *)
structure SDLGeneratedSources =
struct
  open Sh
  fun need(ok,message)=if ok then () else raise Fail message
  fun field name value=case Json.member(name,value) of SOME entry=>entry | NONE=>raise Fail("missing SDL generation field " ^ name)
  fun array(Json.Array values)=values | array _=raise Fail "expected SDL generation array"
  fun string(Json.String value)=value | string _=raise Fail "expected SDL generation string"
  fun load path=Json.decode(read(fromRoot path))
  val inventory=load "ffi/sdl/inventory.json"
  val support=load "ffi/sdl/support.json"
  val policy=load "ffi/sdl/core.ffi"
  val original=List.map(string o field "foreign")(array(field "entries" inventory))
  val additional=List.map string(array(field "functions" support))
  val selected=List.map(string o field "foreign")(array(field "functions" policy))
  val ()=need(length original=53 andalso length additional=3 andalso length selected=56 andalso
    List.all(fn name=>List.exists(fn actual=>actual=name)selected)(original @ additional),"SDL selection must cover all 53 core and 3 support functions")
  val constants=List.map(string o field "foreign")(array(field "constants" inventory)) @
    ["SDL_EVENT_WINDOW_FIRST","SDL_EVENT_WINDOW_LAST"] @ List.map string(array(field "constants" support))
  val directory=let val reservation=OS.FileSys.tmpName()
      val path=run ^ "/sdl-generated/" ^ OS.Path.file reservation
      val ()=mkdirs path val ()=OS.FileSys.remove reservation
    in path end
  val sequence=ref 0
  fun command arguments=
    let val index= !sequence val ()=sequence:=index+1
        val prefix=directory ^ "/command-" ^ Int.toString index
        val ()=write(prefix ^ ".argv.json",Json.encodeIndented 2(Json.Array(List.map Json.String arguments)) ^ "\n")
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=arguments,dir=SOME root,stdin="",
          stdout=prefix ^ ".out",stderr=prefix ^ ".err",timeout=600}
        val ()=write(prefix ^ ".status",Int.toString status ^ "\n")
        val output=read(prefix ^ ".out")
        val ()=need(status=0,"SDL generation command failed: " ^ prefix ^ " " ^ read(prefix ^ ".err") ^ output)
    in output end
  fun options flag values=List.concat(List.map(fn value=>[flag,value])values)
  fun nativeIncludes()=
    let val compiler=String.tokens Char.isSpace(env("CC","cc"))
        val _=command(compiler @ ["--version"])
        val private=String.concat(String.tokens Char.isSpace(command(compiler @ ["-print-file-name=include"])))
    in [private,"/usr/include/x86_64-linux-gnu","/usr/include"] end
  fun windowsIncludes()=
    let val sdk=env("RUNEFFI_WINDOWS_SDK","/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0")
        val msvc=env("RUNEFFI_MSVC_INCLUDE","/mnt/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.40.33807/include")
        val ()=need(exists(sdk ^ "/um/Windows.h") andalso exists(msvc ^ "/vcruntime.h"),"provision the pinned original Windows SDK/MSVC headers")
    in List.map(fn name=>sdk ^ "/" ^ name)["um","shared","ucrt"] @ [msvc] end
  val targets=[("native","linux-x86_64"),("windows32","windows-x86"),("windows64","windows-x86_64")]
  fun one operation(name,target)=
    let val includes="ffi/sdl/upstream" :: (if name="native" then nativeIncludes() else windowsIncludes())
        val arguments=[env("RUNEFFI","bin/runeffi"),operation,"--config","ffi/sdl/core.ffi",
          "--target","ffi/targets/" ^ target ^ ".json","--out","lib/ffi/sdl/generated/" ^ name] @
          options "--include" includes @ options "--layout"["SDL_Event","SDL_Surface","SDL_Rect","SDL_FRect","SDL_TextInputEvent"] @
          ["--field-get","SDL_Surface:pixels","--field-set","SDL_TextInputEvent:text"] @ options "--constant" constants
    in say(command arguments) end
  fun main arguments=
    let val (operation,chosen)=case arguments of [operation]=>(operation,targets)
          | [operation,name]=>(operation,List.filter(fn(other,_)=>other=name)targets)
          | _=>raise Fail "expected generate|check [native|windows32|windows64]"
        val ()=need((operation="generate" orelse operation="check") andalso not(null chosen),"expected generate|check [native|windows32|windows64]")
        val source=load "ffi/sdl/source.json"
        val ()=List.app(fn entry=>let val path=string(field "path" entry) val expected=string(field "sha256" entry)
          in need(Hex.fromBytes(Sha256.digest(read(fromRoot("ffi/sdl/upstream/" ^ path))))=expected,
            "original SDL source changed: " ^ path) end)(array(field "files" source))
        val ()=List.app(one operation)chosen
    in say("PASS SDL source artifact " ^ operation ^ ": " ^ directory ^ "\n") end
end
val ()=SDLGeneratedSources.main(CommandLine.arguments())handle error=>
  (TextIO.output(TextIO.stdErr,"FAIL SDL source artifacts: " ^ General.exnMessage error ^ "\n");OS.Process.exit OS.Process.failure)

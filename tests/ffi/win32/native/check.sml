(* Original-header generation and real Windows GUI acceptance stay in SML.
   .build entrypoints describe sources and implementation selection only. *)
structure NativeWin32Checks =
struct
  open Sh
  exception Failed of string
  fun need(ok,message)=if ok then () else raise Failed message
  val directory=let val reservation=OS.FileSys.tmpName()
      val path=run ^ "/ffi-win32-native/" ^ OS.Path.file reservation
      val ()=mkdirs path val ()=OS.FileSys.remove reservation
    in path end
  fun command environment name args =
    let val ()=mkdirs directory val output=directory ^ "/" ^ name ^ ".out" val errors=output ^ ".err"
        val ()=write(output ^ ".command.json",Json.encode(Json.Array(List.map Json.String args)) ^ "\n")
        val status=Children.exec Subprocess.unlimited environment
          {cmd=args,dir=SOME root,stdin="",stdout=output,stderr=errors,timeout=600}
    in need(status=0,name ^ " exited " ^ Int.toString status ^ ": " ^ read errors ^ read output);
       say("PASS Win32/" ^ name ^ "\n");read output end
  fun run name args=command(fn e=>e)name args
  fun compiler name fallback=String.tokens Char.isSpace(env(name,fallback))
  val sdk=env("RUNEFFI_WINDOWS_SDK","/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0")
  val msvc=env("RUNEFFI_MSVC_INCLUDE","/mnt/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.40.33807/include")
  val includes=List.map(fn path=>sdk ^ "/" ^ path)["um","shared","ucrt"] @ [msvc]
  val fieldsSet=List.map(fn name=>"WNDCLASSEXW:" ^ name)["cbSize","style","lpfnWndProc","hInstance","lpszClassName"]
  val fieldsGet=["MSG:hwnd","MSG:message","MSG:wParam","MSG:lParam",
    "PAINTSTRUCT:rcPaint.left","PAINTSTRUCT:rcPaint.top","PAINTSTRUCT:rcPaint.right","PAINTSTRUCT:rcPaint.bottom"]
  fun constants ()=case Json.member("constants",Json.decode(read(fromRoot "ffi/win32/inventory.json"))) of
      SOME(Json.Array entries)=>List.map(fn entry=>case Json.member("foreign",entry) of
        SOME(Json.String name)=>name | _=>raise Failed "missing constant name")entries
    | _=>raise Failed "missing Win32 constant inventory"
  fun options flag values=List.concat(List.map(fn value=>[flag,value])values)
  fun generate bits output =
    let val ()=need(exists(sdk ^ "/um/Windows.h") andalso exists(sdk ^ "/shared/windowsx.h") andalso exists(msvc ^ "/vcruntime.h"),
          "provision the pinned original Windows SDK and MSVC include roots")
        val profile=if bits="32" then "windows-x86" else "windows-x86_64"
        val ()=ignore(run("generate-" ^ bits)(["bin/runeffi","generate","--config","ffi/win32/core.ffi",
          "--target","ffi/targets/" ^ profile ^ ".json","--out",output] @ options "--include" includes @
          options "--layout" ["WNDCLASSEXW","MSG","PAINTSTRUCT","RECT","POINT"] @
          options "--constant" (constants()) @ options "--field-set" fieldsSet @ options "--field-get" fieldsGet))
        val sets=entries(output ^ "/sets")
        val ()=need(length sets=1,"expected one immutable generated Win32 set")
    in (hd sets,output ^ "/sets/" ^ hd sets ^ "/shims.c") end
  fun windowsPath file=String.concat(String.tokens(fn c=>c= #"\r" orelse c= #"\n")
    (run "windows-path"["wslpath","-w",fromRoot file]))
  fun nativeCompiler bits source object =
    ignore(run("original-sdk-compile-" ^ OS.Path.file object)(compiler "CLANG" "clang" @
      ["-target",if bits="32" then "i686-windows-msvc" else "x86_64-windows-msvc",
       "-fms-compatibility","-fms-extensions","-fms-compatibility-version=19.40.33807","-O2","-c",source,"-o",object] @
      options "-I" includes))
  fun mingw bits=compiler(if bits="32" then "WINCC32" else "WINCC")
    (if bits="32" then "i686-w64-mingw32-gcc" else "x86_64-w64-mingw32-gcc")
  fun repl bits =
    let val generated=directory ^ "/generated"
        val (set,shim)=generate bits generated
        val object=directory ^ "/shims.obj"
        val adapters=directory ^ "/runeffi-win32.dll"
        val ()=nativeCompiler bits shim object
        val ()=ignore(run "link-repl-adapters" (mingw bits @ ["-shared","-Wl,--kill-at",object,"-o",adapters]))
        val dependencies=run "repl-library-dependencies"
          [env("RUNE","bin/rune"),"--library","ffi/win32/native","--basis-deps",
           "--build","tests/ffi/win32/native/repl.build","--path","WIN32_GENERATED=" ^ fromRoot generated]
        (* --basis-deps prints bare filenames for the built-in Basis already
           present in the REPL image, and paths for additional libraries. *)
        val libraries=List.filter(fn file=>String.isSubstring "/" file)(lines dependencies)
        val raw=List.map(fn file=>generated ^ "/sets/" ^ set ^ "/" ^ file)
          ["raw_sig.sml","raw.sml","layout_sig.sml","layout.sml"]
        val sources=libraries @ raw @ ["ffi/win32/native-config.sml","tests/ffi/win32/native/repl-setup.sml"]
        val ()=write(directory ^ "/repl-sources",String.concat(List.map(fn file=>fromRoot file ^ "\n")sources))
        val image=env("RUNE_WIN32_REPL_IMAGE","bin/rune-repl.img")
        val ()=need(exists image,"build bin/rune-repl.img or set RUNE_WIN32_REPL_IMAGE")
        val files=List.map windowsPath sources
        val adapterPath=windowsPath adapters
        val inherited=env("WSLENV","")
        val shared=(if inherited="" then "" else inherited ^ ":") ^ "RUNE_WIN32_ADAPTER_LIBRARY/w"
        val environment=fn values=>setEnv("WSLENV",shared)(setEnv("RUNE_WIN32_ADAPTER_LIBRARY",adapterPath)values)
        val entries=[
          "val firstReplWindow=Win32ReplTest.create \"first retained REPL window\";",
          "fun lateReplHandler (_:Win32ReplTest.T.window) = let val nested=Win32ReplTest.create \"nested late REPL window\" val ()=Runtime.collect() val result=Win32Native.User.sendMessage(nested,Win32ReplTest.T.Application{code=0wx8002,w=0w0,l=0}) val ()=Win32Native.User.destroyWindow nested in result end;",
          "val ()=Win32ReplTest.hook:=lateReplHandler; datatype lateReplDatatype=LateRepl of int; val lateReplPayload=List.tabulate(2000,fn n=>LateRepl n);",
          "val ()=Runtime.collect();",
          "val ()=Win32ReplTest.check(\"late nested callback\",Win32Native.User.sendMessage(firstReplWindow,Win32ReplTest.T.Application{code=0wx8001,w=0w0,l=0})=Int64.fromInt 43); val ()=Win32ReplTest.check(\"nested callback entered\", !(Win32ReplTest.innerCalls)=1);",
          "val ()=Win32Native.User.destroyWindow firstReplWindow; val ()=List.app(fn n=>let val window=Win32ReplTest.create(Int.toString n) val ()=Runtime.collect() in Win32Native.User.destroyWindow window end)[1,2,3];",
          "exception LateReplCallbackFailure; val ()=Win32ReplTest.hook:=(fn _=>raise LateReplCallbackFailure); val failedReplWindow=Win32ReplTest.create \"late callback exception\";",
          "val ()=Runtime.collect(); val ()=Win32ReplTest.check(\"late callback exception\",(ignore(Win32Native.User.sendMessage(failedReplWindow,Win32ReplTest.T.Application{code=0wx8001,w=0w0,l=0}));false)handle LateReplCallbackFailure=>true); val ()=Win32Native.User.destroyWindow failedReplWindow;",
          "val ()=Win32ReplTest.check(\"all six creation/destruction callbacks\", !(Win32ReplTest.created)=6 andalso !(Win32ReplTest.destroyed)=6); val ()=Win32Native.User.unregisterClass(Win32ReplTest.class,Win32ReplTest.instance); val ()=Win32Native.close(); val ()=Runtime.collect(); val ()=Win32ReplTest.check(\"native resources closed\",RuneForeign.live()=0w0); val ()=print \"PASS native Win32 retained REPL callbacks: six windows, zero resources\\n\";"
          ]
        val arguments=files @ options "-e" entries
        fun execute(name,vm,flags)=
          need(String.isSubstring "PASS native Win32 retained REPL callbacks: six windows, zero resources"
            (command environment name([vm] @ flags @ ["--heap-size","67108864","--gc-stress","101","--gc-verify",
             "--restore",windowsPath image,"--","--no-init","--basic","--color=never"] @ arguments)),
            "native Win32 REPL session did not finish")
        val vm=env(if bits="32" then "RUNE_WIN32_REPL_VM32" else "RUNE_WIN32_REPL_VM64",
          if bits="32" then "bin/runevm32.exe" else "bin/runevm.exe")
        val ()=execute("repl-interpreter",vm,["--jit=off"])
    in if bits="32" then say "UNAVAILABLE native Win32 x86 REPL JIT backend; register interpretation is covered\n"
       else (execute("repl-baseline",vm,["--jit=baseline","--jit-calls=1"]);
             execute("repl-opt",vm,["--jit=opt","--jit-calls=1"])) end
  fun acceptance bits application =
    let val ()=ignore(run "clang-version" (compiler "CLANG" "clang" @ ["--version"]))
        val ()=ignore(run "mingw-version" (mingw bits @ ["--version"]))
        val ()=ignore(run "rune-version" [env("RUNE","bin/rune"),"--version"])
        val generated=directory ^ "/generated"
        val (set,shim)=generate bits generated
        val (again,_)=generate bits (directory ^ "/regenerated")
        val ()=need(set=again,"Win32 generation is not deterministic")
        val object=directory ^ "/shims.obj"
        val adapters=directory ^ "/runeffi-win32.dll"
        val ()=nativeCompiler bits shim object
        val ()=ignore(run "link-adapters" (mingw bits @ ["-shared","-Wl,--kill-at",object,"-o",adapters]))
        val helperObject=directory ^ "/helpers.obj"
        val helperExe=directory ^ "/helpers.exe"
        val ()=nativeCompiler bits "tests/ffi/win32/helpers.c" helperObject
        val ()=ignore(run "link-helper-oracle" (mingw bits @ [helperObject,"-o",helperExe]))
        val ()=ignore(run "original-sdk-helper-oracle" [helperExe])
        val paintObject=directory ^ "/paint-empty.obj"
        val paintExe=directory ^ "/paint-empty.exe"
        val ()=nativeCompiler bits "tests/ffi/win32/native/paint-empty.c" paintObject
        val ()=ignore(run "link-empty-paint-oracle" (mingw bits @ [paintObject,"-o",paintExe,"-luser32"]))
        val ()=ignore(run "original-sdk-empty-paint-oracle" [paintExe])
        val adapterPath=windowsPath adapters
        val inherited=env("WSLENV","")
        val shared=(if inherited="" then "" else inherited ^ ":") ^ "RUNE_WIN32_ADAPTER_LIBRARY/w"
        val environment=fn values=>setEnv("WSLENV",shared)(setEnv("RUNE_WIN32_ADAPTER_LIBRARY",adapterPath)values)
        fun compile target source code=ignore(run("compile-" ^ target ^ "-" ^ OS.Path.file code)
          ([env("RUNE","bin/rune"),"--library","ffi/win32/native"] @
           (if source="tests/ffi/win32/native/contract.build" then ["--library","test/unit"] else []) @
           ["--target=" ^ target,"--build",source,"--path","WIN32_GENERATED=" ^ fromRoot generated,"-o",code]))
        fun execute name vm options code marker=
          need(String.isSubstring marker(command environment name(vm::options @ [windowsPath code] @
            (if application then ["--smoke"] else [adapterPath]))),"native Win32 suite did not finish")
        fun one(target,vm)=
          let val code=directory ^ "/" ^ target ^ ".rbc"
              val source=if application then "examples/win32/native.build" else "tests/ffi/win32/native/contract.build"
              val marker=if application then "PASS shared Win32 application: 0" else "PASS native contract resources closed"
              val ()=compile target source code
              val ()=execute(target ^ "-stress")vm["--gc-stress","101","--gc-verify"]code marker
              val ()=if target="stack" then () else if bits="32" then
                say "UNAVAILABLE native Win32 x86 JIT backend; register interpretation is covered\n" else
                (execute "baseline" vm["--jit=baseline","--jit-calls=1","--gc-stress","101","--gc-verify"]code marker;
                 execute "opt" vm["--jit=opt","--jit-calls=1","--gc-stress","101","--gc-verify"]code marker)
          in if application then () else
            let val fixture=directory ^ "/" ^ target ^ "-native.rbc"
                val ()=compile target "tests/ffi/win32/native/suite.build" fixture
            in execute(target ^ "-focused")vm["--gc-stress","7","--gc-verify"]fixture "PASS native Win32 GUI:" end end
        val ()=one("stack",if bits="32" then "bin/runevm-stack32.exe" else "bin/runevm-stack.exe")
        val ()=one("registers",if bits="32" then "bin/runevm32.exe" else "bin/runevm.exe")
    in say("PASS generated native Win32 acceptance: " ^ bits ^ "\n") end
  fun hostProjects()=
    let fun width bits=
          let val generated=directory ^ "/generated-" ^ bits
              val _=generate bits generated
          in List.app(fn project=>ExampleProjects.agreement run (directory ^ "/hosts-" ^ bits) project
            ["--path","WIN32_GENERATED=" ^ fromRoot generated])
            (List.filter(fn p:ExampleProjects.project=> #gate p=ExampleProjects.NativeWin32)ExampleProjects.projects) end
    in List.app width["32","64"];say "PASS generated native Win32 example on both ABIs and all seven Rune compiler builds\n" end
  fun main ["host-projects"]=hostProjects()
    | main ["generate",bits,output]=if bits="32" orelse bits="64" then ignore(generate bits output)
    else raise Failed "expected Windows width 32 or 64"
    | main ["repl",bits]=if bits="32" orelse bits="64" then repl bits else raise Failed "expected repl 32 or 64"
    | main [mode,bits]=if (bits="32" orelse bits="64") andalso (mode="contract" orelse mode="app")
        then acceptance bits (mode="app") else raise Failed "expected contract/app 32 or 64"
    | main _=raise Failed "expected generate 32|64 OUTPUT, contract 32|64, app 32|64, or repl 32|64"
end
val ()=NativeWin32Checks.main(CommandLine.arguments())handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL native Win32 acceptance: " ^
    (case e of NativeWin32Checks.Failed message=>message | _=>General.exnMessage e) ^ "\n");OS.Process.exit OS.Process.failure)

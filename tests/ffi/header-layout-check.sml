structure HeaderLayoutChecks =
struct
  open Sh
  exception Failed of string
  fun need(ok,text)=if ok then () else raise Failed text
  val directory=run ^ "/header-layout/" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
  fun command name args=
    let val ()=mkdirs directory val output=directory ^ "/" ^ name ^ ".out" val errors=output ^ ".err"
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=args,dir=SOME root,stdin="",stdout=output,stderr=errors,timeout=600}
    in need(status=0,name ^ " exited " ^ Int.toString status ^ ": " ^ read errors ^ read output); read output end
  fun windows target=String.isPrefix "windows" target
  val sdk=env("RUNEFFI_WINDOWS_SDK","/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0")
  val msvc=env("RUNEFFI_MSVC_INCLUDE","/mnt/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.40.33807/include")
  fun roots target=if windows target then [sdk ^ "/um",sdk ^ "/shared",sdk ^ "/ucrt",msvc]
    else [Hosts.trim(command "include-root"(String.tokens Char.isSpace(env("CC","cc")) @ ["-print-file-name=include"])),
      "/usr/include/x86_64-linux-gnu","/usr/include"]
  fun stripCR text=String.translate(fn #"\r"=>"" | c=>str c)text
  fun header library target=
    let val base=directory ^ "/" ^ library ^ "-" ^ target
        val profile="ffi/targets/" ^ target ^ ".json"
        val includes=(if library="sdl" then [fromRoot "ffi/sdl/upstream"] else []) @ roots target
        val ()=say(command "analyze"(["bin/runevm","bin/rune-header-layout-probe.rbc",profile,"ffi/" ^ library ^ "/inventory.json",base] @ includes))
        val executable=base ^ (if windows target then ".exe" else "")
        val ()=if windows target then
          let val facts=ForeignTarget.decode{file=profile,text=read profile}
              val definitions=base ^ ".defines.h"
              val ()=write(definitions,String.concat(List.map(fn(n,v)=>"#define " ^ n ^ " " ^ v ^ "\n")(#predefined facts)))
              val flags=["-std=c11","-target",#triple facts,"-undef","-nostdinc","-fms-extensions","-fms-compatibility",
                "-fms-compatibility-version=19.40","-Wno-builtin-macro-redefined","-Wno-nonportable-include-path",
                "-Wno-ignored-attributes","-Wno-pragma-pack","-include",definitions] @
                List.concat(List.map(fn p=>["-isystem",p])includes)
              val ()=ignore(command "compile"(String.tokens Char.isSpace(env("CLANG","clang")) @ flags @ ["-c",base ^ ".c","-o",base ^ ".o"]))
              val cc=if target="windows-x86" then env("WINCC32","i686-w64-mingw32-gcc") else env("WINCC","x86_64-w64-mingw32-gcc")
          in ignore(command "link"(String.tokens Char.isSpace cc @ [base ^ ".o","-lucrt","-o",executable])) end
        else ignore(command "compile"(String.tokens Char.isSpace(env("CC","cc")) @ ["-std=c11","-Wall","-Wextra","-Werror"] @
          List.concat(List.map(fn p=>["-I",p])includes) @ [base ^ ".c","-o",executable]))
        val actual=stripCR(command "native"[executable]) val expected=read(base ^ ".expected")
    in need(actual=expected,"selected original-header C layout/constants differ; compare " ^ base ^ ".expected and native.out");
       say("PASS native original-header facts: " ^ library ^ " " ^ target ^ ": " ^ Int.toString(length(lines actual)) ^ " comparisons\n") end
  fun compiler target=
    let val clang=String.tokens Char.isSpace(env("CLANG","clang"))
        fun cross triple root=clang @ ["--target=" ^ triple,"-B" ^ root ^ "/bin","-L" ^ root ^ "/lib","-I" ^ root ^ "/include","-Wl,-rpath," ^ root ^ "/lib"]
    in case target of "native"=>String.tokens Char.isSpace(env("CC","cc"))
      | "linux32"=>String.tokens Char.isSpace(env("CC","cc")) @ ["-m32"]
      | "windows32"=>String.tokens Char.isSpace(env("WINCC32","i686-w64-mingw32-gcc"))
      | "windows64"=>String.tokens Char.isSpace(env("WINCC","x86_64-w64-mingw32-gcc"))
      | "aarch64"=>cross "aarch64-linux-gnu" "/usr/aarch64-linux-gnu"
      | "ppc64"=>cross "powerpc64-linux-gnu" "/usr/powerpc64-linux-gnu"
      | _=>raise Failed "unknown native binary32 target" end
  fun runner "aarch64"=["qemu-aarch64","-L","/usr/aarch64-linux-gnu"]
    | runner "ppc64"=["qemu-ppc64","-L","/usr/powerpc64-linux-gnu"] | runner _=[]
  fun real32 target=
    let val executable=directory ^ "/real32" ^ (if windows target then ".exe" else "")
        val ()=ignore(command "compile"(compiler target @ ["-std=c11","-Wall","-Wextra","-Werror","tests/ffi/real32_oracle.c","-o",executable]))
        val facts=stripCR(command "native"(runner target @ [executable]))
        val data=directory ^ "/real32.data" val ()=write(data,facts)
    in say(command "compare"["bin/runevm","bin/rune-real32-probe.rbc",data]) end
  fun main["headers",library,target]=header library target
    | main["real32",target]=real32 target
    | main _=raise Failed "expected headers LIBRARY TARGET or real32 TARGET"
end
val ()=HeaderLayoutChecks.main(CommandLine.arguments())handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL header layout: " ^ (case e of HeaderLayoutChecks.Failed s=>s | _=>General.exnMessage e) ^ "\n");OS.Process.exit OS.Process.failure)

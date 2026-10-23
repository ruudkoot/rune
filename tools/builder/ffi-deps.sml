(* Pinned optional FFI dependencies. SML owns identity, archive admission,
   build commands, validation and transactional prefix publication. *)
structure BuildFFIDeps =
struct
  open BuildCommon
  structure O=BuildOptions
  fun safeName name=not(OS.Path.isAbsolute name) andalso
    not(List.exists(fn part=>part=".." orelse part="")(fields #"/" name)) andalso
    not(String.isSubstring "\\" name)
  val environmentKeys=["CFLAGS","CXXFLAGS","CPPFLAGS","LDFLAGS","LIBS","AR","ARFLAGS","RANLIB","AS","ASFLAGS","LD","NM","STRIP",
    "CONFIG_SITE","PKG_CONFIG","PKG_CONFIG_PATH","PKG_CONFIG_LIBDIR","PKG_CONFIG_SYSROOT_DIR","CMAKE_GENERATOR","CMAKE_PREFIX_PATH","CMAKE_TOOLCHAIN_FILE"]
  fun environmentIdentity entries=Json.Object(List.map(fn name=>(name,
    case List.find(String.isPrefix(name ^ "="))entries of NONE=>Json.Null | SOME entry=>str(String.extract(entry,size name+1,NONE))))environmentKeys)
  fun prefixEntries directory=List.concat(List.map(fn name=>
    let val path=OS.Path.concat(directory,name)
    in path::(if not(isLink path) andalso isDir path then prefixEntries path else [])end)(entries directory))
  fun validatePrefix{directory,prefix,project,target}=
    if not(exists directory) then () else
    let val ()=need(not(isLink directory) andalso isDir directory,"dependency prefix must be a real directory: " ^ directory)
    in if null(entries directory) then () else
      let val metadata=directory ^ "/rune-ffi-dependency.json"
          fun unowned ()=raise Failed("nonempty dependency prefix is not owned by " ^ project ^ "/" ^ target ^ ": " ^ directory)
          val record=if exists metadata andalso not(isLink metadata) andalso not(isDir metadata)
            then (readJson metadata handle _=>unowned()) else unowned()
          val configuration=(field "config" record handle _=>unowned())
          val ()=need((field "schema" configuration=number 1 andalso field "project" configuration=str project andalso
            field "target" configuration=str target andalso field "prefix" configuration=str prefix)handle _=>false,
            "dependency prefix ownership does not match project, target and recorded prefix: " ^ directory)
          val outputs=(object(field "outputs" record)handle _=>unowned())
          val links=(object(field "links" record)handle _=>unowned())
          val directories=(case member "directories" record of Json.Null=>[] | value=>List.map text(array value))handle _=>unowned()
          val files=List.map #1 outputs @ List.map #1 links @ ["rune-ffi-dependency.json"]
          fun digest(_,Json.String value)=size value=64 andalso CharVector.all(fn c=>Char.isHexDigit c)value | digest _=false
          fun link(_,Json.String _)=true | link _=false
          val ()=need(not(null outputs) andalso List.all safeName(files @ directories) andalso
            List.all digest outputs andalso List.all link links andalso length(unique files)=length files,
            "invalid dependency ownership inventory: " ^ directory)
          fun parents name=let val parts=fields #"/" name
            in List.tabulate(Int.max(0,length parts-1),fn n=>String.concatWith "/" (List.take(parts,n+1)))end
          val allowedDirectories=unique(directories @ List.concat(List.map parents files))
          fun inspect path=
            let val relative=String.extract(path,size directory+1,NONE)
                val allowed=if not(isLink path) andalso isDir path then allowedDirectories else files
            in need(List.exists(fn name=>name=relative)allowed,"unrecorded dependency prefix entry is preserved: " ^ path)end
      in List.app inspect(prefixEntries directory) end end
  fun admitted top (member:BuildArchive.member)=
    let val name= #name member
        val name=if String.isSuffix "/" name then String.substring(name,0,size name-1) else name
        val kind= #kind member
        val ()=need(safeName name andalso (name=top orelse String.isPrefix(top ^ "/")name),"unsafe dependency archive member " ^ name)
        val ()=need(List.exists(fn c=>c=kind)[#"0",#"\000",#"5",#"2",#"1"],"unsupported dependency archive member " ^ name)
        val ()=if kind= #"2" orelse kind= #"1" then
          let val link= #link member
              val ()=need(link<>"" andalso not(OS.Path.isAbsolute link) andalso not(String.isSubstring "\\" link),"unsafe dependency archive link " ^ name)
              val target=OS.Path.mkCanonical(if kind= #"1" then link else OS.Path.concat(OS.Path.dir name,link))
          in need(not(OS.Path.isAbsolute link) andalso safeName target andalso
               (target=top orelse String.isPrefix(top ^ "/")target),"unsafe dependency archive link " ^ name) end else ()
    in () end
  fun recipe ()=Hex.fromBytes(Sha256.digest(String.concat(List.map(fn name=>name ^ "\000" ^ hash(fromRoot name) ^ "\000")
    ["tools/builder/ffi-deps.sml","tools/builder/ffi-probe.c","tools/builder/common.sml","tools/builder/archive.sml","tools/builder/io.sig","tools/builder/native-io.sml","tools/builder/rune-io.sml"])))
  fun download archive checksum urls offline run =
    if exists archive then (need(hash archive=checksum,"cached dependency archive checksum mismatch: " ^ archive);NONE) else
    let val ()=need(not offline,"offline dependency archive is missing: " ^ archive)
        val temporary=privateDirectory(OS.Path.dir archive)".download"
        val part=temporary ^ "/payload" val failures=ref([]:string list)
        fun loop []=raise Failed("dependency download failed: " ^ String.concatWith "; " (rev(!failures)))
          | loop(url::rest)=
            let val result=(run "download" ["curl","--fail","--location","--silent","--show-error","--connect-timeout","15","--max-time","60","--retry","2","--retry-max-time","180",url,"-o",part];NONE)
                  handle Failed why=>SOME why | BuildIO.TimedOut _=>SOME "download timed out"
            in case result of SOME why=>(failures:=(url ^ ": " ^ why):: !failures;loop rest)
              | NONE=>(need(exists part andalso hash part=checksum,"downloaded dependency archive checksum mismatch: " ^ url);
                  OS.FileSys.rename{old=part,new=archive};SOME url) end
        val result=loop urls handle e=>(remove temporary;raise e)
    in remove temporary;result end
  fun source archive directory top run =
    let val raw=run "decompress" ["gzip","--decompress","--stdout",archive]
        val members=BuildArchive.readTar raw
        val ()=need(not(null members),"empty dependency archive")
        val ()=List.app(admitted top)members
        val names=List.map #name members
        val ()=need(length(unique names)=length names,"duplicate dependency archive member")
        val out=directory ^ "/source" val ()=mkdirs out
        val _=run "extract" ["tar","--extract","--gzip","--file",archive,"--directory",out,"--no-same-owner"]
        fun verify(member:BuildArchive.member)=
          let val file=out ^ "/" ^ #name member
          in if #kind member= #"0" orelse #kind member= #"\000" then
               need(exists file andalso not(isDir file) andalso not(isLink file) andalso
                 hash file=Hex.fromBytes(Sha256.digest(#data member)),"extracted dependency source differs: " ^ #name member)
             else if #kind member= #"2" then
               need(isLink file andalso OS.FileSys.readLink file= #link member,"extracted dependency link differs: " ^ #name member)
             else () end
        val ()=List.app verify members
    in out ^ "/" ^ top end
  fun publish{staged,prefix,project,target} =
    let fun validate directory=validatePrefix{directory=directory,prefix=prefix,project=project,target=target}
        val ()=validate prefix val ()=validate staged
        val backup=privateDirectory(OS.Path.dir prefix)".previous"
        val saved=backup ^ "/prefix" val present=exists prefix
        val ()=if present then OS.FileSys.rename{old=prefix,new=saved} else ()
        fun rollback e=(if present then OS.FileSys.rename{old=saved,new=prefix} else ();remove backup;raise e)
        val ()=(if present then validate saved else ())handle e=>rollback e
        val ()=OS.FileSys.rename{old=staged,new=prefix} handle e=>rollback e
    in remove backup end
  fun outputFiles prefix=List.filter(fn path=>not(isLink path) andalso not(isDir path) andalso
    OS.Path.file path<>"rune-ffi-dependency.json")(tree prefix)
  type targetProfile={host:string option,cc:string,cxx:string,cflags:string,ldflags:string,ar:string,ranlib:string,runner:string,pointerBytes:int,byteOrder:string}
  fun profile target : targetProfile =
    let fun cross(triple,sysroot,loader,byteOrder)=
          {host=SOME triple,cc="clang --target=" ^ triple ^ " -B" ^ sysroot ^ "/bin",
           cxx="clang --target=" ^ triple ^ " -B" ^ sysroot ^ "/bin",cflags="-I" ^ sysroot ^ "/include",
           ldflags="-L" ^ sysroot ^ "/lib -Wl,-rpath," ^ sysroot ^ "/lib -Wl,-dynamic-linker," ^ sysroot ^ "/lib/" ^ loader,
           ar=triple ^ "-ar",ranlib=triple ^ "-ranlib",runner="qemu-" ^ (if target="ppc64" then "ppc64" else "aarch64") ^ " -L " ^ sysroot,
           pointerBytes=8,byteOrder=byteOrder}
        fun windows triple pointerBytes={host=SOME triple,cc=triple ^ "-gcc",cxx=triple ^ "-g++",cflags="",ldflags="",
          ar=triple ^ "-ar",ranlib=triple ^ "-ranlib",runner="",pointerBytes=pointerBytes,byteOrder="little"}
    in case target of
        "native"=>{host=NONE,cc=env("CC","cc"),cxx=env("CXX","c++"),cflags="",ldflags="",ar=env("AR","ar"),ranlib=env("RANLIB","ranlib"),
          runner="",pointerBytes=0,byteOrder="native"}
      | "windows32"=>windows "i686-w64-mingw32" 4
      | "windows64"=>windows "x86_64-w64-mingw32" 8
      | "linux32"=>{host=SOME "i686-pc-linux-gnu",cc=env("CC","cc"),cxx=env("CXX","c++"),cflags="-m32 -msse2 -mfpmath=sse",ldflags="-m32",
          ar="ar",ranlib="ranlib",runner="",pointerBytes=4,byteOrder="little"}
      | "aarch64"=>cross("aarch64-linux-gnu","/usr/aarch64-linux-gnu","ld-linux-aarch64.so.1","little")
      | "ppc64"=>cross("powerpc64-linux-gnu","/usr/powerpc64-linux-gnu","ld64.so.1","big")
      | _=>raise Failed("unsupported dependency target " ^ target)
    end
  fun main (project::args)=
    let val ()=need(project="libffi" orelse project="sdl","dependency must be libffi or sdl")
        val options=O.parse[("--target",O.Value),("--prefix",O.Value),("--archive",O.Value),("--jobs",O.Value),("--timeout",O.Value),
          ("--cc",O.Value),("--cxx",O.Value),("--rc",O.Value),("--cflags",O.Value),("--ldflags",O.Value),
          ("--ar",O.Value),("--ranlib",O.Value),("--runner",O.Value),("--headless",O.Flag),("--offline",O.Flag),("--download-only",O.Flag),("--verify-only",O.Flag)][]args
        val target=O.get options "--target" "native"
        val selected=profile target
        val ()=need(project="libffi" orelse List.exists(fn s=>s=target)["native","windows32","windows64"],"cross SDL provisioning is outside this profile")
        val headless=O.flag options "--headless"
        val ()=need(not headless orelse (project="sdl" andalso target="native"),"headless provisioning requires native SDL")
        val windows=String.isPrefix "windows" target val narrow=target="windows32"
        val host=getOpt(#host selected,"")
        val cc=O.get options "--cc" (#cc selected)
        val cxx=O.get options "--cxx" (#cxx selected)
        val rc=O.get options "--rc" (host ^ "-windres")
        fun combined original extra=String.concatWith " "(List.filter(fn text=>text<>"")[original,extra])
        (* Autoconf normally supplies these only when flags are unset. Profile
           flags must preserve that default; an explicitly empty env stays empty. *)
        val cflags=O.get options "--cflags" (combined(env("CFLAGS","-g -O2"))(#cflags selected))
        val cxxflags=combined(env("CXXFLAGS","-g -O2"))(#cflags selected)
        val ldflags=O.get options "--ldflags" (combined(env("LDFLAGS",""))(#ldflags selected))
        val ar=O.get options "--ar" (#ar selected) val ranlib=O.get options "--ranlib" (#ranlib selected)
        val runner=O.get options "--runner" (#runner selected)
        val jobs=integer(O.get options "--jobs" "2") val timeout=real(O.get options "--timeout" "1800")
        val ()=need(jobs>0 andalso timeout>0.0,"jobs and timeout must be positive")
        val manifestFile=fromRoot("ffi/" ^ project ^ "/source.json") val manifest=readJson manifestFile
        val version=text(field "version" manifest) val checksum=text(field "sha256" manifest) val url=text(field "url" manifest)
        val top=(if project="sdl" then "SDL3-" else "libffi-") ^ version
        val archive=resolved(O.get options "--archive" (fromRoot("build/deps/downloads/" ^ top ^ ".tar.gz")))
        val defaultPrefix=if project="libffi" andalso windows then "build/deps/libffi-win" ^ (if narrow then "32" else "64") ^ "/install"
          else "build/deps/" ^ project ^ "/" ^ (if headless then "headless" else target) ^ "/install"
        val prefix=resolved(O.get options "--prefix" (fromRoot defaultPrefix))
        val ()=need(prefix<>root andalso prefix<>"/","dependency prefix must be a dedicated directory")
        val ()=if O.flag options "--download-only" then () else
          validatePrefix{directory=prefix,prefix=prefix,project=project,target=target}
        val directory=privateDirectory(fromRoot("build/deps/" ^ project ^ "-build"))target
        val serial=ref 0 val commands=ref([]:Json.value list)
        fun executeIn cwd environment label argv=
          let val ()=serial:= !serial+1 val log=directory ^ "/" ^ Int.toString(!serial) ^ "-" ^ label
              val ()=say(project ^ " " ^ label ^ ": " ^ command argv ^ "\n")
              val result=execute cwd log timeout argv environment
              val ()=commands:= !commands @ [Json.Object[("label",str label),("argv",strings argv),("cwd",str cwd),("status",number(#status result)),("seconds",Json.Number(minus(Real.toString(#seconds result))))]]
              val ()=json(directory ^ "/commands.json")(Json.Array(!commands))
          in need(#status result=0,label ^ " failed; see " ^ log ^ ".stderr: " ^ #errors result);#output result end
        val environment=setEnv("AR",ar)(setEnv("RANLIB",ranlib)(setEnv("CFLAGS",cflags)(setEnv("CXXFLAGS",cxxflags)(setEnv("LDFLAGS",ldflags)
          (unset "MAKEFLAGS" (unset "MFLAGS" (Posix.ProcEnv.environ())))))))
        fun run label argv=executeIn directory environment label argv
        val _=download archive checksum [url] (O.flag options "--offline") run
        val compiler=if O.flag options "--download-only" then "" else trim(run "compiler-version" (words cc @ ["--version"]))
        val tools=if project<>"sdl" orelse O.flag options "--download-only" then [] else
          [("cxx",str(trim(run "cxx-version" (words cxx @ ["--version"])))),
           ("cmake",str(trim(run "cmake-version" ["cmake","--version"])))] @
          (if windows then [("rc",str(trim(run "rc-version" (words rc @ ["--version"]))))] else [])
        val config=Json.Object[("schema",number 1),("project",str project),("version",str version),("target",str target),("prefix",str prefix),
          ("archive_sha256",str checksum),("manifest_sha256",str(hash manifestFile)),("recipe_sha256",str(recipe())),
          ("cc",str cc),("cxx",str cxx),("rc",str rc),("cflags",str cflags),("ldflags",str ldflags),("runner",str runner),
          ("host",str host),("ar",str ar),("ranlib",str ranlib),("compiler",str compiler),("tools",Json.Object tools),("headless",Json.Bool headless),
          ("build_environment",environmentIdentity environment)]
        val metadata=prefix ^ "/rune-ffi-dependency.json"
        fun fresh ()=exists metadata andalso
          let val previous=readJson metadata
              val hashes=object(field "outputs" previous)
              val links=object(field "links" previous)
          in field "config" previous=config andalso not(null hashes) andalso
             sorted(List.map #1 hashes)=sorted(List.map(fn file=>String.extract(file,size prefix+1,NONE))(outputFiles prefix)) andalso
             List.all(fn(name,digest)=>safeName name andalso not(isLink(prefix ^ "/" ^ name)) andalso
               exists(prefix ^ "/" ^ name) andalso hash(prefix ^ "/" ^ name)=text digest)hashes andalso
             List.all(fn(name,target)=>safeName name andalso isLink(prefix ^ "/" ^ name) andalso
               OS.FileSys.readLink(prefix ^ "/" ^ name)=text target)links
          end handle _=>false
    in if O.flag options "--download-only" then (say("verified pinned " ^ project ^ " archive " ^ archive ^ "\n");0)
       else if fresh() then (say("verified existing " ^ project ^ " prefix " ^ prefix ^ "\n");0)
       else if O.flag options "--verify-only" then raise Failed "dependency prefix is missing, stale or modified"
       else
        let val source=source archive directory top run
            val build=directory ^ "/build" val ()=mkdirs build
            val stage=directory ^ "/stage" val staged=stage ^ prefix
            val environment=setEnv("CC",cc)(setEnv("CXX",cxx)(setEnv("RC",rc)environment))
            fun work label argv=executeIn build environment label argv
            val ()=if project="libffi" then
              (ignore(work "configure" ([source ^ "/configure","--prefix=" ^ prefix,"--disable-shared","--enable-static","--with-pic","--disable-docs","--disable-multi-os-directory"] @
                 (case #host selected of NONE=>[] | SOME host=>["--host=" ^ host])));
               ignore(work "build" ["make","-j" ^ Int.toString jobs]);
               ignore(work "install" ["make","install","DESTDIR=" ^ stage]))
              else
              (ignore(work "configure" (["cmake","-S",source,"-B",build,"-DCMAKE_BUILD_TYPE=Release","-DCMAKE_INSTALL_PREFIX=" ^ prefix,
                 "-DSDL_SHARED=ON","-DSDL_STATIC=OFF","-DSDL_TESTS=OFF","-DSDL_TEST_LIBRARY=OFF","-DSDL_EXAMPLES=OFF","-DSDL_AUDIO=OFF","-DSDL_GPU=OFF",
                 "-DSDL_X11_XSCRNSAVER=OFF",
                 "-DCMAKE_C_COMPILER=" ^ cc,"-DCMAKE_CXX_COMPILER=" ^ cxx] @
                 (if headless then ["-DSDL_UNIX_CONSOLE_BUILD=ON","-DSDL_X11=OFF","-DSDL_WAYLAND=OFF","-DSDL_KMSDRM=OFF","-DSDL_OPENGL=OFF","-DSDL_OPENGLES=OFF","-DSDL_VULKAN=OFF",
                    "-DSDL_DUMMYVIDEO=ON","-DSDL_OFFSCREEN=ON","-DSDL_CAMERA=OFF","-DSDL_JOYSTICK=OFF","-DSDL_HAPTIC=OFF","-DSDL_SENSOR=OFF",
                    "-DSDL_TRAY=OFF","-DSDL_DIALOG=OFF","-DSDL_DBUS=OFF","-DSDL_IBUS=OFF","-DSDL_LIBUDEV=OFF","-DSDL_LIBURING=OFF","-DSDL_HIDAPI=OFF"] else []) @
                 (if windows then ["-DCMAKE_SYSTEM_NAME=Windows","-DCMAKE_RC_COMPILER=" ^ rc] else [])));
               ignore(work "build" ["cmake","--build",build,"--parallel",Int.toString jobs]);
               ignore(executeIn build (setEnv("DESTDIR",stage)environment) "install" ["cmake","--install",build]))
            val ()=need(exists(staged ^ (if project="libffi" then "/lib/libffi.a" else if windows then "/bin/SDL3.dll" else "/lib/libSDL3.so")),"expected dependency output is missing")
            val license=staged ^ "/share/licenses/" ^ project val ()=mkdirs license
            val licenseFile=if project="sdl" then "LICENSE.txt" else "LICENSE"
            val ()=copy(source ^ "/" ^ licenseFile)(license ^ "/" ^ licenseFile)
            val probe=directory ^ "/probe.c" val executable=directory ^ (if windows then "/probe.exe" else "/probe")
            val probeCode=if project="libffi" then
              read(fromRoot "tools/builder/ffi-probe.c")
              else "#define SDL_MAIN_HANDLED 1\n#include <SDL3/SDL.h>\n#include <SDL3/SDL_main.h>\nint main(void){SDL_SetMainReady();if(!SDL_Init(SDL_INIT_EVENTS))return 2;SDL_Surface *surface=SDL_CreateSurface(4,4,SDL_PIXELFORMAT_ARGB8888);if(!surface)return 3;SDL_Renderer *renderer=SDL_CreateSoftwareRenderer(surface);if(!renderer)return 4;if(!SDL_SetRenderDrawColor(renderer,1,2,3,255)||!SDL_RenderClear(renderer)||!SDL_RenderPresent(renderer))return 5;SDL_DestroyRenderer(renderer);SDL_DestroySurface(surface);SDL_Quit();return 0;}\n"
            val ()=write(probe,probeCode)
            val _=run "compile-probe" (words cc @ words cflags @ ["-std=c99","-Wall","-Wextra","-Werror","-I" ^ staged ^ "/include",probe,"-o",executable] @
              (if project="libffi" then ["-DRUNE_FFI_EXPECT_POINTER=" ^ Int.toString(#pointerBytes selected),
                 "-DRUNE_FFI_EXPECT_BIG_ENDIAN=" ^ (case #byteOrder selected of "big"=>"1" | "little"=>"0" | _=>"-1")] else []) @ words ldflags @
              (if project="libffi" then [staged ^ "/lib/libffi.a"] else ["-L" ^ staged ^ "/lib","-lSDL3"] @
                (if windows then [] else ["-Wl,-rpath," ^ staged ^ "/lib"])))
            val validation=if windows andalso runner="" then "cross-compiled; execution outstanding" else
              (ignore(run "run-probe"(words runner @ [executable]));if runner="" then "native call/render probe passed" else "explicit target runner call probe passed")
            val output=Json.Object(List.map(fn file=>(String.extract(file,size staged+1,NONE),str(hash file)))(outputFiles staged))
            val links=Json.Object(List.map(fn file=>(String.extract(file,size staged+1,NONE),str(OS.FileSys.readLink file)))(List.filter isLink(tree staged)))
            val directories=strings(List.map(fn file=>String.extract(file,size staged+1,NONE))(List.filter(fn file=>not(isLink file) andalso isDir file)(prefixEntries staged)))
            val record=Json.Object[("config",config),("compiler",str compiler),("archive",str archive),("validation",str validation),
              ("upstream_tests",str "not run; Rune ABI/behavior suites are separate"),("commands",Json.Array(!commands)),("outputs",output),("links",links),("directories",directories),("build_directory",str directory)]
            val ()=json(staged ^ "/rune-ffi-dependency.json")record
            val ()=mkdirs(OS.Path.dir prefix)
            val ()=publish{staged=staged,prefix=prefix,project=project,target=target}
        in say("provisioned pinned " ^ project ^ " in " ^ prefix ^ " (" ^ validation ^ ")\n");0 end end
    | main _=raise Usage "build-ffi libffi|sdl [--target native|windows32|windows64|linux32|aarch64|ppc64] [--offline] [--verify-only]"
end

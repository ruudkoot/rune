(* Distribution scenarios around the production packager and installer.
   Their independent fixture bytes and archive assertions are SML. *)
structure DistChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun directory () = run ^ "/distribution"
  fun put dir path text = (mkdirs (OS.Path.dir (dir ^ "/" ^ path)); write (dir ^ "/" ^ path, text))
  val linuxArchitectures = ["x86_64", "i686", "aarch64", "ppc64"]
  val windowsArchitectures = ["x86_64", "i686"]
  fun setup () =
    let val dir = directory ()
        val () = InstallChecks.openTree dir
        val () = rmTree dir
        val () = mkdirs dir
        val () = List.app (fn (path, text) => put dir path text)
          [("lib/basis/MANIFEST", "# a comment\nlist.sml | demand | yes | List | \n"),
           ("lib/basis/list.sml", "structure List = struct end\n"), ("lib/basis/README.md", "# Basis\n"),
           ("lib/basis/library.build", "files list.sml end\n"),
           ("lib/json/MANIFEST", "json.sml | demand | yes | Json | \npkg/extra.sml | demand | yes | | \n"),
           ("lib/json/json.sml", "structure Json = struct end\n"), ("lib/json/pkg/extra.sml", "structure Extra = struct end\n"),
           ("lib/json/README.md", "# Json\n"), ("lib/json/library.build", "files json.sml end\n"),
           ("lib/stray.sml", "not a library\n"), ("lib/cache/made", "cached\n"),
           ("rune.rbc", "compiler\n"), ("rune-repl.img", "repl\n"),
           ("nomanifest/lib/gone/library.build", "files end\n"), ("script-vm", "#!/bin/sh\necho no\n")]
        val () = List.app (fn arch => put dir ("vm-" ^ arch) ("vm-" ^ arch ^ "\n")) linuxArchitectures
        val () = List.app (fn arch => put dir ("exe-" ^ arch) ("exe-" ^ arch ^ "\n")) windowsArchitectures
        fun interpreter "x86_64" = "/lib64/ld-linux-x86-64.so.2"
          | interpreter "i686" = "/lib/ld-linux.so.2"
          | interpreter "aarch64" = "/lib/ld-linux-aarch64.so.1"
          | interpreter "ppc64" = "/lib64/ld64.so.1"
          | interpreter _ = raise Failed "unknown fixture architecture"
        val () = List.app (fn arch => BinaryFixtures.write (dir ^ "/good-" ^ arch)
                      (BinaryFixtures.elf arch (interpreter arch) ["libc.so.6"])) linuxArchitectures
        val () = BinaryFixtures.write (dir ^ "/good-win64") (BinaryFixtures.pe 34404)
        val () = BinaryFixtures.write (dir ^ "/good-win32") (BinaryFixtures.pe 332)
        val () = BinaryFixtures.write (dir ^ "/bad-arm-pe") (BinaryFixtures.pe 43620)
        val () = BinaryFixtures.write (dir ^ "/bad-gmp") (BinaryFixtures.elf "x86_64" (interpreter "x86_64") ["libgmp.so.10"])
        val () = BinaryFixtures.write (dir ^ "/bad-arm-loader")
                (BinaryFixtures.elf "aarch64" "/usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1" ["libc.so.6"])
        val () = BinaryFixtures.write (dir ^ "/bad-ppc-loader")
                (BinaryFixtures.elf "ppc64" "/usr/powerpc64-linux-gnu/lib/ld64.so.1" ["libc.so.6"])
    in () end
  fun packWith extra label fixture version library linux windows =
    let val dir = directory ()
        val flags = List.concat (List.map (fn (arch, file) => ["--linux", arch ^ "=" ^ file]) linux)
                    @ List.concat (List.map (fn (arch, file) => ["--windows", arch ^ "=" ^ file]) windows)
    in InstallChecks.execute dir label root ""
       ([fromRoot "bin/rune-build", "make-dist", "--version", version, "--out", dir ^ (if fixture then "/archives" else "/checked-" ^ label), "--lib", library,
          "--license", fromRoot "LICENSE", "--compiler", dir ^ "/rune.rbc", "--repl", dir ^ "/rune-repl.img"]
          @ (if fixture then ["--fixture"] else []) @ flags @ extra) end
  fun pack label fixture version library linux windows=packWith [] label fixture version library linux windows
  fun maps good =
    let val dir = directory ()
    in (List.map (fn arch => (arch, dir ^ (if good then "/good-" else "/vm-") ^ arch)) linuxArchitectures,
        List.map (fn arch => (arch, dir ^ (if good then if arch = "x86_64" then "/good-win64" else "/good-win32" else "/exe-" ^ arch))) windowsArchitectures) end
  val libraryMembers = ["LICENSE", "VERSION", "lib/rune/basis/MANIFEST", "lib/rune/basis/README.md", "lib/rune/basis/list.sml",
       "lib/rune/json/MANIFEST", "lib/rune/json/README.md", "lib/rune/json/json.sml", "lib/rune/json/pkg/extra.sml",
       "lib/rune/rune-repl.img", "lib/rune/rune.rbc"]
  fun ffiArchives ()=
    let val dir=directory() val assets=dir ^ "/ffi-assets"
        val ()=put dir "ffi-assets/sdl/core.ffi" "original sidecar\n"
        val ()=put dir "ffi-assets/sdl/upstream/original.h" "original header\n"
        val library=dir ^ "/ffi-library"
        val ()=List.app(fn(path,text)=>put library path text)
          [("basis/library.build","files list.sml end\n"),("basis/MANIFEST","list.sml | demand | yes | List | \n"),
           ("basis/list.sml","structure List = struct end\n")]
        val generated=List.concat(List.map(fn target=>
          let val prefix="ffi/sdl/generated/" ^ target ^ "/"
          in List.map(fn(name,text)=>(prefix ^ name,text))
            [("current.build","use sets/identity/native.build\n"),("api/api/public_sig.sml","signature GENERATED = sig end\n"),
             ("sets/identity/library.build","files raw.sml end\n"),("sets/identity/MANIFEST","raw.sml | demand | yes | Generated | \n"),
             ("sets/identity/raw.sml","structure Generated = struct end\n"),("sets/identity/native.build","raw.sml\n"),
             ("sets/identity/shims.c","/* generated typed C shim */\n"),("sets/identity/ffi-manifest.json","{\"declarations\":[]}\n"),
             ("sets/identity/dependencies.json","{\"headers\":[]}\n")]
          end)["native","windows32","windows64"])
        val ()=List.app(fn(path,text)=>put library path text)generated
        val(linux,windows)=maps false
        val ()=Scenarios.success(packWith["--ffi",dir ^ "/rune.rbc","--ffi-assets",assets]
          "ffi-pack" true "ffi1" library linux windows)
        val tarfile=dir ^ "/archives/rune-ffi1-linux.tar.gz"
        val tar=ArchiveCheck.tar(ArchiveCheck.decode dir "ffi.tar"["gzip","-dc",tarfile])
        fun member name=case List.find(fn(m:ArchiveCheck.member)=> #name m="rune-ffi1-linux/" ^ name)tar of
          SOME m=> #data m | NONE=>raise Failed("missing FFI archive member " ^ name)
        val ()=need(member "lib/rune/runeffi.rbc"="compiler\n" andalso
          member "lib/rune/ffi-assets/sdl/core.ffi"="original sidecar\n" andalso
          member "lib/rune/ffi-assets/sdl/upstream/original.h"="original header\n","FFI archive bytes differ")
        val ()=List.app(fn(path,text)=>need(member("lib/rune/" ^ path)=text,"generated SDL source missing or changed: " ^ path))generated
        val zip=dir ^ "/archives/rune-ffi1-windows.zip"
        val zipped=ArchiveCheck.zip(ArchiveCheck.binary zip)
        val ()=need(List.exists(fn(m:ArchiveCheck.zipped)=> #name m="rune-ffi1-windows/wrappers/runeffi.cmd")zipped,"missing Windows runeffi launcher")
        val ()=List.app(fn(path,_)=>need(List.exists(fn(m:ArchiveCheck.zipped)=>
          #name m="rune-ffi1-windows/lib/rune/" ^ path)zipped,"generated SDL source missing from Windows archive: " ^ path))generated
        val out=dir ^ "/ffi-extracted" val ()=mkdirs out
        val ()=Scenarios.success(InstallChecks.execute dir "ffi-extract" root ""["tar","-xzf",tarfile,"-C",out])
        val prefix=dir ^ "/FFI relocated prefix" val script=out ^ "/rune-ffi1-linux/install.sh"
        val ()=Scenarios.success(InstallChecks.execute dir "ffi-install" root ""["sh",script,"--prefix",prefix,"--arch","x86_64"])
        val wrapper=read(prefix ^ "/bin/runeffi")
        val ()=need(String.isSubstring "../lib/rune/runeffi.rbc" wrapper andalso not(String.isSubstring root wrapper),"runeffi launcher is not relocatable")
        val ()=need(read(prefix ^ "/lib/rune/ffi-assets/sdl/upstream/original.h")="original header\n","installer omitted original header")
        val ()=List.app(fn(path,text)=>need(read(prefix ^ "/lib/rune/" ^ path)=text,"installed generated SDL source differs: " ^ path))generated
        val ()=write(prefix ^ "/bin/unrelated","keep\n")
        val ()=Scenarios.success(InstallChecks.execute dir "ffi-uninstall" root ""["sh",script,"--prefix",prefix,"--uninstall"])
        val ()=need(not(exists(prefix ^ "/bin/runeffi")) andalso not(exists(prefix ^ "/lib/rune/ffi-assets")) andalso
          read(prefix ^ "/bin/unrelated")="keep\n","FFI uninstall retained owned files or removed unrelated files")
    in say "PASS distribution/ffi-generator-assets-install-uninstall\n" end
  fun archives () =
    let val dir = directory ()
        val (linux, windows) = maps false
        val () = Scenarios.success (pack "fixture-pack" true "test1" (dir ^ "/lib") linux windows)
        val tarfile = dir ^ "/archives/rune-test1-linux.tar.gz"
        val zipfile = dir ^ "/archives/rune-test1-windows.zip"
        val () = need (exists tarfile andalso exists zipfile, "distribution archive names differ")
        val raw = ArchiveCheck.decode dir "uncompressed.tar" ["gzip", "-dc", tarfile]
        val tar = ArchiveCheck.tar raw
        val top = "rune-test1-linux/"
        val expected = sort (List.map (fn name => top ^ name)
                 ("install.sh" :: libraryMembers @ List.map (fn arch => "runtime/" ^ arch ^ "/runevm") linuxArchitectures))
        val () = ArchiveCheck.memberNames expected (List.map (fn m : ArchiveCheck.member => #name m) tar)
        fun rejects name f = need (((f (); false) handle ArchiveCheck.Invalid _ => true), "archive checker accepted planted " ^ name)
        val first = 512 + ((size (#data (hd tar)) + 511) div 512) * 512
        val missing = ArchiveCheck.tar (String.extract (raw, first, NONE))
        val () = rejects "missing member" (fn () => ArchiveCheck.memberNames expected (List.map (fn m : ArchiveCheck.member => #name m) missing))
        val duplicated = ArchiveCheck.tar (String.substring (raw, 0, first) ^ raw)
        val () = rejects "duplicate member" (fn () => ArchiveCheck.memberNames expected (List.map (fn m : ArchiveCheck.member => #name m) duplicated))
        val corrupt = "X" ^ String.extract (raw, 1, NONE)
        val () = rejects "tar checksum" (fn () => ignore (ArchiveCheck.tar corrupt))
        val () = List.app (fn m : ArchiveCheck.member =>
          let val name = String.extract (#name m, size top, NONE)
              val executable = name = "install.sh" orelse String.isPrefix "runtime/" name
          in need (#mode m = (if executable then 493 else 420) andalso #uid m = 0 andalso #gid m = 0 andalso #mtime m = 0,
                   "noncanonical tar metadata: " ^ name);
             if String.isSuffix ".sh" name orelse String.isSuffix ".sml" name orelse name = "VERSION"
             then need (not (String.isSubstring "\r" (#data m)), "CR in Unix archive text: " ^ name) else () end) tar
        val entries = ArchiveCheck.zip (ArchiveCheck.binary zipfile)
        val top = "rune-test1-windows/"
        val expected = sort (List.map (fn name => top ^ name)
           (libraryMembers @ ["install.bat", "uninstall.bat", "register.ps1", "share/rune.ico", "wrappers/rune.cmd", "wrappers/rune-repl.cmd"]
            @ List.map (fn arch => "runtime/" ^ arch ^ "/runevm.exe") windowsArchitectures))
        val () = ArchiveCheck.memberNames expected (List.map (fn m : ArchiveCheck.zipped => #name m) entries)
        fun crlf text =
          let fun loop i = i = size text orelse
                  ((String.sub (text, i) <> #"\n" orelse (i > 0 andalso String.sub (text, i - 1) = #"\r")) andalso loop (i + 1))
          in String.isSubstring "\r\n" text andalso loop 0 end
        val () = List.app (fn (i, m : ArchiveCheck.zipped) =>
          let val name = String.extract (#name m, size top, NONE)
              val data = ArchiveCheck.decode dir ("zip-member-" ^ Int.toString i) ["unzip", "-p", zipfile, #name m]
              val () = need (IntInf.fromInt (size data) = #size m, "zip member length differs")
          in if String.isSuffix ".bat" name orelse String.isSuffix ".cmd" name then need (crlf data, "batch file is not CRLF: " ^ name)
             else if String.isPrefix "runtime/" name then need (String.isPrefix "exe-" data, "wrong Windows runtime bytes")
             else if name = "share/rune.ico" then need (String.isPrefix "\000\000\001\000" data, "invalid Windows icon") else () end)
                       (ListPair.zip (List.tabulate (length entries, fn i => i), entries))
    in say "PASS distribution/archive-metadata\n" end
  fun rejectedMetadata () =
    let val dir = directory ()
        val (linux, windows) = maps false
        val missing = pack "missing-manifest" true "test1" (dir ^ "/nomanifest/lib") linux windows
        val () = need (#status missing <> 0 andalso String.isSubstring "MANIFEST" (#errors missing), "packaged a library without a manifest")
        val version = pack "bad-version" true "../x" (dir ^ "/lib") linux windows
    in need (#status version <> 0, "packaged an unsafe version") end
  fun binaryHeaders () =
    let val dir = directory ()
        val (linux, windows) = maps true
        val () = Scenarios.success (pack "valid-binaries" false "test1" (dir ^ "/lib") linux windows)
        fun replace key value rows = List.map (fn (name, original) => (name, if key = name then value else original)) rows
        fun rejects (name, system, arch, file, message) =
          let val result = pack ("binary-" ^ name) false "test1" (dir ^ "/lib")
                    (if system = "linux" then replace arch (dir ^ "/" ^ file) linux else linux)
                    (if system = "windows" then replace arch (dir ^ "/" ^ file) windows else windows)
          in need (#status result <> 0 andalso String.isSubstring message (#errors result), "accepted or misdiagnosed binary fixture " ^ name) end
    in List.app rejects
       [("gmp", "linux", "x86_64", "bad-gmp", "libgmp"),
        ("arm-loader", "linux", "aarch64", "bad-arm-loader", "interpreter"),
        ("ppc-loader", "linux", "ppc64", "bad-ppc-loader", "interpreter"),
        ("script", "linux", "x86_64", "script-vm", "script"),
        ("wrong-class", "linux", "i686", "good-x86_64", "not a i686"),
        ("arm-pe", "windows", "x86_64", "bad-arm-pe", "PE machine"),
        ("script-pe", "windows", "i686", "script-vm", "script")];
       say "PASS distribution/binary-headers\n" end
  fun installer () =
    let val dir = directory ()
        val linux = dir ^ "/archives/rune-test1-linux.tar.gz"
        val tree = dir ^ "/tree"
        val () = mkdirs tree
        val () = Scenarios.success (InstallChecks.execute dir "extract" root ""
                                   ["tar", "-xzf", linux, "-C", tree])
        val stage = tree ^ "/rune-test1-linux"
        val script = stage ^ "/install.sh"
        val prefix = dir ^ "/installed"
        fun invoke label environment args =
          let val output = dir ^ "/" ^ label ^ ".out"
              val errors = dir ^ "/" ^ label ^ ".err"
              val status = Children.exec {addressSpace = NONE, cpuTime = SOME 120,
                                          fileSize = SOME (64 * 1024 * 1024), core = SOME 0} environment
                  {cmd = script :: args, dir = SOME root, stdin = "", stdout = output, stderr = errors, timeout = 120}
          in {status = status, output = read output, errors = read errors} : Scenarios.result end
        val (machine, bits) =
          let val machine = #2 (valOf (List.find (fn (name, _) => name = "machine") (Posix.ProcEnv.uname ())))
              val result = InstallChecks.execute dir "user-bits" root "" ["getconf", "LONG_BIT"]
              val () = Scenarios.success result
          in (machine, Hosts.trim (#output result)) end
        val arch = case machine of "x86_64" => if bits = "32" then "i686" else "x86_64"
           | "amd64" => if bits = "32" then "i686" else "x86_64" | "i386" => "i686" | "i686" => "i686"
           | "aarch64" => "aarch64" | "arm64" => "aarch64" | name => name
        val user = invoke "dry-run-user" (setEnv ("RUNE_DIST_EUID", "1000")) ["--dry-run"]
        val () = Scenarios.output user ("prefix=" ^ env ("HOME", "") ^ "/.local\narch=" ^ arch ^ "\n")
        val superuser = invoke "dry-run-root" (setEnv ("RUNE_DIST_EUID", "0")) ["--dry-run"]
        val () = Scenarios.output superuser ("prefix=/usr/local\narch=" ^ arch ^ "\n")
        val unsupported = invoke "ppc64le" (fn e => e) ["--dry-run", "--arch", "ppc64le"]
        val () = need (#status unsupported <> 0 andalso String.isSubstring "ppc64le" (#errors unsupported), "accepted ppc64le runtime")
        val arm = invoke "armv7" (fn e => e) ["--dry-run", "--arch", "armv7l"]
        val () = need (#status arm <> 0, "accepted unsupported armv7 runtime")
        val installed = invoke "install" (fn e => e) ["--prefix", prefix, "--arch", "aarch64"]
        val () = Scenarios.success installed
        val () = need (same (stage ^ "/runtime/aarch64/runevm", prefix ^ "/bin/runevm"), "installed the wrong architecture")
        val () = List.app (fn path => need (same (dir ^ "/lib/" ^ path, prefix ^ "/lib/rune/" ^ path), "installed library differs: " ^ path))
                       ["basis/list.sml", "json/pkg/extra.sml"]
        val () = need (not (exists (prefix ^ "/lib/rune/basis/library.build")) andalso not (exists (prefix ^ "/lib/rune/cache")),
                       "installed build metadata or unrelated cache")
        val wrapper = read (prefix ^ "/bin/rune")
        val () = need (not (String.isSubstring root wrapper) andalso not (String.isSubstring dir wrapper), "installed wrapper depends on archive/source tree")
        val () = need (String.isSubstring ("note: " ^ prefix ^ "/bin is not on your PATH") (#output installed), "installer omitted the PATH note")
        val expectedRune = "#!/bin/sh\nd=$(dirname \"$0\")\n[ \"$1\" = -i ] && shift && exec \"$d/rune-repl\" \"$@\"\n"
                         ^ "exec \"$d/runevm\" --heap-size 67108864 \"$d/../lib/rune/rune.rbc\" --lib \"$d/../lib/rune\" \"$@\"\n"
        val expectedRepl = "#!/bin/sh\nd=$(dirname \"$0\")\nexec \"$d/runevm\" --heap-size 67108864 --restore \"$d/../lib/rune/rune-repl.img\" -- \"$@\"\n"
        val () = need (wrapper = expectedRune andalso read (prefix ^ "/bin/rune-repl") = expectedRepl, "distribution wrapper bytes differ")
        val () = Scenarios.success (invoke "reinstall" (fn e => e) ["--prefix", prefix, "--arch", "ppc64"])
        val () = need (same (stage ^ "/runtime/ppc64/runevm", prefix ^ "/bin/runevm"), "reinstall did not replace the runtime")
        val () = Scenarios.success (invoke "uninstall" (fn e => e) ["--prefix", prefix, "--uninstall"])
        val () = need (not (exists prefix), "distribution uninstall left its prefix")
        val again = invoke "uninstall-again" (fn e => e) ["--prefix", prefix, "--uninstall"]
        val () = Scenarios.success again
    in need (String.isSubstring "nothing installed" (#output again), "repeated uninstall was not idempotent");
       say "PASS distribution/installer\n" end
  fun windows () =
    let val dir = directory ()
        val choice = {status=0,output=WindowsDir.directory () ^ "\n",errors=""} : Scenarios.result
        val () = Scenarios.success choice
        val windowsRoot = Hosts.trim (#output choice)
        val () = need (windowsRoot <> "" andalso isDir windowsRoot, "Windows staging directory is unavailable")
        val stage = windowsRoot ^ "/dist-test-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
        val () = need (not (exists stage), "Windows staging path already exists")
        val () = mkdirs stage
        val zip = dir ^ "/archives/rune-test1-windows.zip"
        (* Member validation precedes extraction, including path safety. *)
        val entries = ArchiveCheck.zip (ArchiveCheck.binary zip)
        val () = need (List.all (fn m : ArchiveCheck.zipped =>
                  String.isPrefix "rune-test1-windows/" (#name m)
                  andalso not (String.isSubstring "/../" (#name m))) entries, "unsafe Windows archive member")
        val extracted = InstallChecks.execute dir "windows-extract" root "" ["unzip", "-q", zip, "-d", stage]
        val () = Scenarios.success extracted
        val installed = InstallChecks.execute dir "windows-install" (stage ^ "/rune-test1-windows") ""
            ["cmd.exe", "/c", "install.bat --prefix ..\\prefix --arch x86_64 --no-register"]
        val () = Scenarios.success installed
        val () = need (same (dir ^ "/exe-x86_64", stage ^ "/prefix/bin/runevm.exe"), "Windows installer chose wrong runtime bytes")
        val () = need (exists (stage ^ "/prefix/share/rune.ico"), "Windows installer omitted the icon")
        val uninstalled = InstallChecks.execute dir "windows-uninstall" (stage ^ "/prefix") "" ["cmd.exe", "/c", "uninstall.bat"]
        val () = Scenarios.success uninstalled
        val () = need (not (exists (stage ^ "/prefix")), "Windows uninstall left its prefix")
        val () = rmTree stage
    in say "PASS distribution/windows-installer\n" end
end

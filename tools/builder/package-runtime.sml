structure BuildPackageRuntime =
struct
  open BuildCommon
  structure O=BuildOptions
  val librarySources=["lib/unicode/utf8_sig.sml","lib/unicode/utf8.sml","lib/json/json_sig.sml","lib/json/json.sml","lib/digest/digest_sig.sml","lib/digest/sha256.sml","lib/digest/hex_sig.sml","lib/digest/hex.sml"]
  fun main args =
    let val options=O.parse [("--vm",O.Value),("--build-info",O.Value),("--out",O.Value)] [] args
        val record=readJson (O.get options "--build-info" (fromRoot "build/gmp/native-build.json"))
        val vm=BuildRuntimeInputs.executablePath (O.get options "--vm" (fromRoot "bin/runevm"))
        val ()=need (hash vm=text (field "vm_sha256" record),"VM differs from its build record; rebuild before installing")
        val hashes=object (field "source_hashes" record)
        val ()=List.app (fn (name,digest) => need (hash (fromRoot name)=text digest,"runtime source differs from its build record: " ^ name)) hashes
        val config=field "configuration" record val enabled=boolean (field "enabled" config)
        val probe=privateDirectory (fromRoot "tests/out/build-observations") "package-runtime"
        val version= #output (execute (OS.FileSys.getDir ()) (probe ^ "/version") 60.0 [resolved vm,"--version"] (Posix.ProcEnv.environ ()))
        val ()=need (String.isSubstring "GMP headers " version=enabled,"VM and dependency configuration disagree")
        val ()=if not enabled then () else need (String.isSubstring ("GMP headers " ^ text (field "header_version" config) ^ ", library " ^ text (field "library_version" config) ^ ", " ^ text (field "limb_bits" config) ^ "-bit limbs, supported\n") version,"GMP version changed; reconfigure and rebuild before installing")
        val prefix=text (field "prefix" config) val prefix=if prefix="" then "" else resolved (fromRoot prefix)
        val ()=if enabled andalso prefix<>"" then List.app (fn (kind,name) => need (hash (prefix ^ "/" ^ name)=text (field (kind ^ "_sha256") config),"changed GMP " ^ kind)) [("header","include/gmp.h"),("library","lib/libgmp.a")] else ()
        val dependency=member "dependency" config
        val archive=if enabled andalso dependency<>Json.Null then SOME (fromRoot ("build/deps/downloads/gmp-" ^ text (field "version" (field "config" dependency)) ^ ".tar.xz")) else NONE
        val ()=case archive of NONE => () | SOME archive =>
             (need (hash archive=text (field "sha256" (field "config" dependency)),"missing or modified pinned source archive");need (BuildGMP.recipe ()=text (field "recipe_sha256" (field "config" dependency)),"GMP recipe differs from its build record"))
        val foreign=member "foreign" record
        val ffiPrefix=if foreign=Json.Null orelse member "provider" foreign<>str "prefix" then "" else text(field "prefix" foreign)
        val ()=if ffiPrefix="" then () else List.app(fn(key,path)=>need(hash(ffiPrefix ^ "/" ^ path)=text(field key foreign),"changed libffi " ^ path))
          [("header_sha256","include/ffi.h"),("target_header_sha256","include/ffitarget.h"),("library_sha256","lib/libffi.a")]
        val ffiDependency=if ffiPrefix="" then Json.Null else member "dependency" foreign
        val ffiArchive=if ffiDependency=Json.Null then NONE else SOME(text(field "archive" ffiDependency))
        val ()=case ffiArchive of NONE=>() | SOME path=>need(hash path=text(field "archive_sha256" (field "config" ffiDependency)),"missing or modified pinned libffi source archive")
        val out=resolved (O.require options "--out") val ()=need (out<>root andalso out<>"/","runtime material output must be a dedicated directory")
        val temporary=privateDirectory (OS.Path.dir out) ".rebuild"
        fun prepare () =
          let val ()=List.app (fn (name,_) => copy (fromRoot name) (temporary ^ "/" ^ name)) hashes
              val ()=List.app (fn name => if exists (fromRoot name) then copy (fromRoot name) (temporary ^ "/" ^ name) else ()) ["LICENSE","COPYING"]
              val ()=List.app (fn name => copy (fromRoot name) (temporary ^ "/" ^ name)) librarySources
              val ()=copyTree (fromRoot "tools/builder") (temporary ^ "/tools/builder")
              val ()=if enabled andalso prefix<>"" then
                   (List.app (fn name => if exists (prefix ^ "/" ^ name) then copy (prefix ^ "/" ^ name) (temporary ^ "/gmp/" ^ name) else ()) ["include/gmp.h","lib/libgmp.a","rune-gmp.json"];
                    if isDir (prefix ^ "/share/licenses/gmp") then copyTree (prefix ^ "/share/licenses/gmp") (temporary ^ "/gmp/notices") else ()) else ()
              val ()=case archive of NONE => () | SOME archive => copy archive (temporary ^ "/build/deps/downloads/" ^ OS.Path.file archive)
              val ()=if ffiPrefix="" then () else
                (List.app(fn path=>copy(ffiPrefix ^ "/" ^ path)(temporary ^ "/libffi/" ^ path))["include/ffi.h","include/ffitarget.h","lib/libffi.a"];
                 if exists(ffiPrefix ^ "/rune-ffi-dependency.json") then copy(ffiPrefix ^ "/rune-ffi-dependency.json")(temporary ^ "/libffi/rune-ffi-dependency.json") else ();
                 if isDir(ffiPrefix ^ "/share/licenses/libffi") then copyTree(ffiPrefix ^ "/share/licenses/libffi")(temporary ^ "/libffi/notices") else ())
              val ()=case ffiArchive of NONE=>() | SOME path=>copy path(temporary ^ "/build/deps/downloads/" ^ OS.Path.file path)
              val ()=if not(isDir(fromRoot "ffi/libffi")) then () else copyTree(fromRoot "ffi/libffi")(temporary ^ "/ffi/libffi")
              val ()=json (temporary ^ "/build-info.json") (set "version" (str version) record)
              val bytecode=fromRoot "bin/rune-build.rbc"
              val ()=if not (exists bytecode) then () else
                 (copy bytecode (temporary ^ "/rebuild.rbc");
                  copy vm (temporary ^ "/" ^ (if String.isSuffix ".exe" (String.map Char.toLower vm) then "runevm.exe" else "runevm"));
                  Posix.FileSys.chmod (temporary ^ "/" ^ (if String.isSuffix ".exe" (String.map Char.toLower vm) then "runevm.exe" else "runevm"),Posix.FileSys.ST.mode (Posix.FileSys.stat vm));
                  atomic (temporary ^ "/rebuild") "#!/bin/sh\nd=$(CDPATH= cd \"$(dirname \"$0\")\" && pwd)\nRUNE_BUILD_ROOT=$d; export RUNE_BUILD_ROOT\nexec \"$d/runevm\" \"$d/rebuild.rbc\" relink \"$@\"\n";
                  Posix.FileSys.chmod (temporary ^ "/rebuild",Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr,Posix.FileSys.S.irgrp,Posix.FileSys.S.ixgrp,Posix.FileSys.S.iroth,Posix.FileSys.S.ixoth]);
                  atomic (temporary ^ "/rebuild.cmd") "@echo off\r\nset RUNE_BUILD_ROOT=%~dp0\r\n\"%~dp0runevm.exe\" \"%~dp0rebuild.rbc\" relink %*\r\n")
              val ()=atomic (temporary ^ "/README") ("Runtime relinking material\n\nCopy this directory to a writable location. When rebuild.rbc and its VM are\npresent, run ./rebuild [OUTPUT] (rebuild.cmd on Windows). Otherwise compile\nthe native Standard ML tool with MLton using tools/builder/native.mlb, then\nrun RUNE_BUILD_ROOT=PWD ./rune-build relink [OUTPUT].\nThe default output is runevm-relinked. This is a source rebuild, not a promise\nof byte-identical machine code. Original build and binary hashes are retained\nin build-info.json. A compiler, cross sysroot and runner named there remain\nexternal requirements. The native bootstrap path needs the pinned MLton host;\nit needs no Rune VM or target GMP configuration.\n\nPinned GMP includes header, static library, provenance, notices and verified\nsource archive. tools/builder contains the Standard ML provisioning recipe.\nA changed library requires regenerated provisioning metadata or an explicitly\nchecked local prefix; stale header/library hashes are rejected. A system GMP\ninstallation has no supplied source/build provenance; its development package\nis an external relinking requirement. No pinned-source claim is made for it.\n")
          in if exists out then remove out else ();OS.FileSys.rename {old=temporary,new=out} end
    in (prepare () handle e => (remove temporary;remove probe;raise e));remove probe;say ("retained runtime build and dependency material in " ^ out ^ "\n");0 end
end

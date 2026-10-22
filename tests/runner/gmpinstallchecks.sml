(* A relocated installation, its native compiler and its packaged relinker
   are subjects under test; every installation prefix remains private. *)
structure GMPInstallChecks =
struct
  open IntInfChecks
  fun one (c : context) mode () =
    let val ()=need (mode="gmp" orelse mode="sml","installation mode must be gmp or sml")
        val ()=mkdirs (#directory c)
        val records=ref [] : Json.value list ref
        fun run name directory expected args =
          let val result=GMPChecks.process c name directory 180 [] args
              val ()=records:= !records @ [Json.Object [("argv",Json.Array (List.map Json.String args)),("cwd",Json.String directory),("exit",Json.Number (Int.toString (#status result)))]]
              val ()=write (path c "commands.json",Json.encode (Json.Array (!records)) ^ "\n")
          in need (#status result=expected,"installed GMP command failed: " ^ name ^ ": " ^ #errors result);result end
        val stage=path c "stage"
        val installed=path c "relocated tree"
        val ()=need (not (exists installed),"use a fresh output directory for installation checks")
        val _=run "install" (#directory c) 0 ["sh",fromRoot "scripts/install.sh","--prefix","/opt/rune","--destdir",stage]
        val ()=OS.FileSys.rename {old=stage ^ "/opt/rune",new=installed}
        val info=Json.decode (read (installed ^ "/lib/rune/rebuild/build-info.json"))
        val ()=need (field "enabled" (field "configuration" info)=Json.Bool (mode="gmp"),"installed backend build record differs")
        val rebuild=installed ^ "/lib/rune/rebuild"
        val ()=need (exists (rebuild ^ "/runtime/intinf.c"),"runtime source missing from relink package")
        val ()=need (exists (rebuild ^ "/build/deps/downloads/gmp-6.3.0.tar.xz")=(mode="gmp"),"packaged pinned source archive policy differs")
        val data=fixture "platform"
        val expected=string (field "factorial_75" data)
        val source=path c "arithmetic.sml"
        val ()=write (source,string (field "install-arithmetic" (field "fragments" data)))
        val program=path c "arithmetic.rbc"
        val bin=installed ^ "/bin"
        val _=run "compile" (#directory c) 0 [bin ^ "/rune","-o",program,source]
        val ()=List.app (fn backend => output (run ("arithmetic-" ^ backend) (#directory c) 0 [bin ^ "/runevm","--intinf=" ^ backend,program]) expected)
                         (if mode="gmp" then ["gmp","sml"] else ["auto","sml"])
        val ()=if mode<>"sml" then () else
          let val result=run "unavailable-gmp" (#directory c) 2 [bin ^ "/runevm","--intinf=gmp",program]
          in need (String.isSubstring "requested GMP backend is unavailable" (#errors result),"disabled installation accepted GMP") end
        val ()=if not (exists (bin ^ "/runeopt")) then () else
          let val stack=path c "arithmetic-stack.rbc"
              val native=path c "arithmetic-native"
              val _=run "compile-stack" (#directory c) 0 [bin ^ "/rune","--target=stack","-o",stack,source]
              val _=run "native-compile" (#directory c) 0 [bin ^ "/runeopt",stack,"-o",native]
          in output (run "native-run" (#directory c) 0 [native]) expected end
        val relinked=path c "runevm-relinked"
        val relinker=case OS.Process.getEnv "GMP_RELINKER" of
              SOME command => CommandWords.split command | NONE => [rebuild ^ "/rebuild"]
        fun relink name target expected=run name (#directory c) expected (relinker @ [target])
        val _=relink "relink" relinked 0
        val ()=output (run "relinked-run" (#directory c) 0 [relinked,"--intinf=" ^ mode,program]) expected
        val ()=if mode<>"gmp" then () else
          let val header=rebuild ^ "/gmp/include/gmp.h"
              val original=CachePlant.binary header
              fun check ()=
                let val ()=CachePlant.writeBinary header (original ^ "\n/* altered installation probe */\n")
                    val result=relink "reject-altered-header" (path c "rejected-relink") 1
                in need (String.isSubstring "differs from its provisioning record" (#errors result)
                         andalso not (exists (path c "rejected-relink")),"relocation trusted altered pinned headers") end
          in (check () before CachePlant.writeBinary header original) handle e => (CachePlant.writeBinary header original;raise e) end
        val version=run "version" (#directory c) 0 [bin ^ "/runevm","--version"]
        val marker=bin ^ "/unrelated-marker"
        val ()=write (marker,"keep\n")
        val _=run "uninstall" (#directory c) 0 ["sh",fromRoot "scripts/install.sh","--prefix",installed,"--uninstall"]
        val ()=need (read marker="keep\n" andalso not (exists (bin ^ "/rune")) andalso not (exists (installed ^ "/lib/rune")),
                      "uninstall removed unrelated data or retained owned files")
        val report=Json.Object [("mode",Json.String mode),("result",Json.String "pass"),("commands",Json.Array (!records)),
                     ("version",Json.String (#output version)),("build_info",info),("relinked_sha256",Json.String (GMPChecks.hash relinked))]
    in write (path c "report.json",Json.encode report ^ "\n");say ("PASS " ^ mode ^ " staged install, relocation, native output, relinking and uninstall\n") end
end

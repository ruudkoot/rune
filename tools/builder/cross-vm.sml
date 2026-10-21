structure BuildCrossVM =
struct
  open BuildCommon
  structure O=BuildOptions
  fun checkWindows cc vm prefix =
    let val objdump=successful (execute root (prefix ^ "-name") 60.0 (words cc @ ["-print-prog-name=objdump"]) (Posix.ProcEnv.environ ()))
        val imports=successful (execute root (prefix ^ "-imports") 60.0 [objdump,"-p",vm] (Posix.ProcEnv.environ ()))
        val dlls=List.mapPartial (fn line => case String.tokens Char.isSpace line of
              "DLL"::"Name:"::name::_ => SOME name | _ => NONE) (lines imports)
    in need (not (List.exists (String.isPrefix "lib" o String.map Char.toLower) dlls),vm ^ ": non-system DLL imports: " ^ String.concatWith ", " dlls) end
  fun imports args =
    let val options=O.parse [("--cc",O.Value),("--vm",O.Value)] [] args
        val vm=O.require options "--vm"
        val directory=privateDirectory (fromRoot "tests/out/build-observations") "windows-imports"
    in (checkWindows (O.require options "--cc") vm (directory ^ "/objdump")
         handle e => (remove directory;remove vm;raise e));remove directory;0 end
  fun recipeFiles ()=sorted (List.filter (fn file => List.exists (fn ext => String.isSuffix ext file) [".sml",".sig"]) (tree (fromRoot "tools/builder")))
  fun main args =
    let val ()=OS.FileSys.chDir root
        val options=O.parse [("--mode",O.Value),("--prefix",O.Value),("--cc",O.Value),("--cflags",O.Value),("--ldlibs",O.Value),("--runner",O.Value),("--config",O.Value),("--out",O.Value),("--windows",O.Flag),("--sources",O.Many true),("--headers",O.Many false),("--objects",O.Many false)] [] args
        val mode=O.require options "--mode" val prefix=O.get options "--prefix" "" val cc=O.require options "--cc" val cflags=O.get options "--cflags" "" val runner=O.get options "--runner" ""
        val config=O.require options "--config" val target=O.require options "--out" val ldlibs=O.get options "--ldlibs" "-lm"
        val sources=O.values options "--sources" val headers=O.values options "--headers" val objects=O.values options "--objects"
        val _=BuildGMPConfig.main ["--mode",mode,"--prefix",prefix,"--cc",cc,"--cflags",cflags,"--runner",runner,"--out",config]
        val dependency=readJson (config ^ "/config.json")
        val inputs=BuildRuntimeInputs.collect root (words cc) (words cflags) (List.map text (array (field "cppflags" dependency))) (config ^ "/config.h") sources headers (config ^ "/dependency-inputs") @ recipeFiles () @ objects
        val optionRecord=Json.Object [("mode",str mode),("prefix",str prefix),("cc",str cc),("cflags",str cflags),("ldlibs",str ldlibs),("runner",str runner),("config",str config),("out",str target),
                ("windows",Json.Bool (O.flag options "--windows")),("sources",strings sources),("headers",strings headers),("objects",strings objects)]
        val record=Json.Object [("options",optionRecord),("inputs",Json.Object (List.map (fn file => (file,str (hash file))) inputs)),("configuration_sha256",str (hash (config ^ "/config.json")))]
        val stamp=config ^ "/linked.json"
        val previous=if exists stamp andalso exists target then SOME (readJson stamp) else NONE
        val fresh=case previous of NONE => false | SOME previous => field "inputs" previous=record andalso text (field "vm_sha256" previous)=hash target
    in if fresh then (say (target ^ ": verified unchanged cross build\n");0) else
       let val directory=privateDirectory (OS.Path.dir target) ".cross-link" val temporary=directory ^ "/" ^ OS.Path.file target
           val command=words cc @ words cflags @ ["-Iruntime"] @ List.map text (array (field "cppflags" dependency)) @ ["-include",config ^ "/config.h","-o",temporary] @ sources @ objects @ List.map text (array (field "ldlibs" dependency)) @ words ldlibs
           fun link ()=
             let val ()=say (BuildCommon.command command ^ "\n") val result=execute root (config ^ "/link") 1800.0 command (Posix.ProcEnv.environ ())
                 val ()=(say (#output result);warn (#errors result);need (#status result=0,"cross VM link failed"))
                 val ()=if not (O.flag options "--windows") then () else checkWindows cc temporary (config ^ "/objdump")
             in OS.FileSys.rename {old=temporary,new=target};json stamp (Json.Object [("inputs",record),("command",strings command),("vm_sha256",str (hash target))]) end
       in (link () handle e => (remove directory;raise e));remove directory;0 end end
end

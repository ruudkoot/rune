structure BuildRelink =
struct
  open BuildCommon
  fun main args =
    let val target=case args of [] => "runevm-relinked" | [target] => target | _ => raise Usage "relink [OUTPUT]"
        val record=readJson (root ^ "/build-info.json") val enabled=boolean (field "enabled" (field "configuration" record))
        val prefix=if enabled andalso exists (root ^ "/gmp/include/gmp.h") then "gmp" else ""
        val ()=OS.FileSys.chDir root
        val _=BuildGMPConfig.main ["--mode",if enabled then "yes" else "no","--prefix",prefix,"--cc",command (List.map text (array (field "cc" record))),"--cflags",command (List.map text (array (field "cflags" record))),"--out","build/config"]
        val config=readJson "build/config/config.json"
        val args=List.map text (array (field "cc" record)) @ List.map text (array (field "cflags" record)) @ ["-Iruntime"] @ List.map text (array (field "cppflags" config)) @ ["-include","build/config/config.h","-o",target] @
             List.map text (array (field "sources" record)) @ List.map text (array (field "ldlibs" config)) @ List.map text (array (field "ldlibs" record))
        val result=execute root (root ^ "/build/relink") 1800.0 args (Posix.ProcEnv.environ ())
    in say (#output result);warn (#errors result);need (#status result=0,"runtime relink failed");0 end
end

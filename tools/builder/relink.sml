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
        val foreign=member "foreign" record
        val ffiPrefix=if foreign=Json.Null orelse member "provider" foreign<>str "prefix" then NONE else SOME(text(field "flag_prefix" foreign))
        val ()=case ffiPrefix of NONE=>() | SOME _=>List.app(fn(key,path)=>need(hash(root ^ "/libffi/" ^ path)=text(field key foreign),"libffi relinking input differs from its build record: " ^ path))
          [("header_sha256","include/ffi.h"),("target_header_sha256","include/ffitarget.h"),("library_sha256","lib/libffi.a")]
        fun relocate flag=case ffiPrefix of NONE=>flag | SOME prefix=>
          if flag="-I" ^ prefix ^ "/include" then "-I" ^ root ^ "/libffi/include"
          else if flag=prefix ^ "/lib/libffi.a" then root ^ "/libffi/lib/libffi.a" else flag
        val args=List.map text (array (field "cc" record)) @ List.map (relocate o text) (array (field "cflags" record)) @ ["-Iruntime"] @ List.map text (array (field "cppflags" config)) @ ["-include","build/config/config.h","-o",target] @
             List.map text (array (field "sources" record)) @ List.map text (array (field "ldlibs" config)) @ List.map (relocate o text) (array (field "ldlibs" record))
        val result=execute root (root ^ "/build/relink") 1800.0 args (Posix.ProcEnv.environ ())
    in say (#output result);warn (#errors result);need (#status result=0,"runtime relink failed");0 end
end

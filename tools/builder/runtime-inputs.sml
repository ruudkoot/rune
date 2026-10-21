structure BuildRuntimeInputs =
struct
  open BuildCommon
  fun executablePath name=if exists name orelse String.isSuffix ".exe" (String.map Char.toLower name) then name else if exists (name ^ ".exe") then name ^ ".exe" else name
  fun collect directory cc flags cppflags config sources headers prefix =
    let val result=execute directory prefix 60.0 (cc @ flags @ ["-Iruntime"] @ cppflags @ ["-include",config,"-MM"] @ sources) (Posix.ProcEnv.environ ())
        val dependencies=successful result
        val dependencies=let fun replace source =case Substring.position "\\\n" (Substring.full source) of (a,b) => if Substring.isEmpty b then source else Substring.string a ^ " " ^ replace (Substring.string (Substring.triml 2 b)) in replace dependencies end
        val runtime=OS.Path.mkCanonical (directory ^ "/runtime")
        fun own word =
          if String.isSuffix ":" word then NONE else
            let val path=OS.Path.mkCanonical (OS.Path.mkAbsolute {path=word,relativeTo=directory})
            in if path=runtime orelse String.isPrefix (runtime ^ "/") path then SOME (String.extract (path,size directory+1,NONE)) else NONE end
    in sorted (unique (sources @ headers @ List.mapPartial own (words dependencies))) end
end

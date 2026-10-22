(* Implements: C_FILES *)
structure CFiles : C_FILES =
struct
  fun read path =
    let val file = OS.FileSys.realPath path
        val input = BinIO.openIn file
        val text = (Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input)
          handle e => (BinIO.closeIn input; raise e)
    in {file = file, text = text} end
  fun resolver roots =
    let val roots = List.map OS.FileSys.realPath roots
        fun exists path = OS.FileSys.access (path, []) handle OS.SysErr _ => false
        fun within (root, file) = String.isPrefix (root ^ "/") file
        fun following file [] = []
          | following file (root :: rest) = if within (root, file) then rest else following file rest
    in fn {from, name, system, next} =>
      let val directories = if next then following from roots
            else (if system then [] else [OS.Path.dir from]) @ roots
          val paths = List.map (fn root => OS.Path.concat (root, name)) directories
      in case List.find exists paths of NONE => NONE | SOME path => SOME (read path) end
    end
end

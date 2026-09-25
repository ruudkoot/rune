(* runeisa, the generator of the instruction sets: the command line. It
   writes the files IsaGen makes from the descriptions of src/isa, or with
   --check says which of them are not what the descriptions give. *)
structure IsaMain =
struct
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  val usage =
    "usage: runeisa [--root DIR] [--check]\n\
    \  --root DIR  the root of the tree the files are written into (default .)\n\
    \  --check     write nothing: name each file that is not what src/isa gives,\n\
    \              and fail if there is one\n"

  fun readFile (path : string) : string option =
    let val ins = TextIO.openIn path
    in SOME (TextIO.inputAll ins) before TextIO.closeIn ins end
    handle IO.Io _ => NONE

  fun writeFile (path : string, text : string) : unit =
    let val out = TextIO.openOut path
    in TextIO.output (out, text); TextIO.closeOut out end

  fun main (_ : string, args : string list) : OS.Process.status =
    let
      fun parse (root, check, []) = SOME (root, check)
        | parse (_, check, "--root" :: dir :: rest) = parse (dir, check, rest)
        | parse (root, _, "--check" :: rest) = parse (root, true, rest)
        | parse _ = NONE
    in
      case parse (".", false, args) of
        NONE => (TextIO.output (TextIO.stdErr, usage); OS.Process.failure)
      | SOME (root, check) =>
          let
            val files = IsaGen.files (StackIsa.instructions, PrimIsa.primitives)
                        @ RegGen.files (RegIsa.instructions, PrimIsa.primitives)
            fun at path = root ^ "/" ^ path
            val stale = List.filter (fn {path, text} => readFile (at path) <> SOME text) files
          in
            if check then
              (List.app (fn {path, ...} => eprintln ("runeisa: " ^ path ^ " is not what src/isa gives; run make isa")) stale;
               if List.null stale then OS.Process.success else OS.Process.failure)
            else
              (List.app (fn {path, text} => writeFile (at path, text)) stale;
               OS.Process.success)
          end
    end
    handle Isa.Bad msg => (eprintln ("runeisa: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("runeisa: cannot write " ^ name); OS.Process.failure)
end

structure Main =
struct
  val version = "Rune 0.1.0 (bytecode v2)\n"
  val usage = "Usage: rune [-o OUTPUT.rbc] [--] INPUT.sml\n       rune --check [--] INPUT.sml\n       rune --disassemble [--] INPUT.rbc\n       rune --help | --version\n"
  exception Usage of string
  fun main (_,args) =
    let
      val inputName = ref "rune"
      fun read path =
        let val stream = TextIO.openIn path
        in (TextIO.inputN (stream,Source.maxSource+1) before TextIO.closeIn stream)
           handle ex => (TextIO.closeIn stream handle _ => (); raise ex) end
      fun publish output source program =
        let
          val {dir,file} = OS.Path.splitDirFile output
          (* Create beside the destination so rename remains on one filesystem. *)
          val reservation = OS.FileSys.tmpName ()
          val nonce = OS.Path.file reservation
          val temporary = OS.Path.joinDirFile {dir=dir,file="." ^ file ^ "." ^ nonce}
          fun release () = OS.FileSys.remove reservation handle _ => ()
          fun remove () = (OS.FileSys.remove temporary handle _ => (); release ())
        in (Bytecode.write temporary source program;
            OS.FileSys.rename {old=temporary,new=output}; release ())
           handle ex => (remove (); raise ex) end
      fun run () = case args of
          ["--help"] => print usage
        | ["--version"] => print version
        | _ =>
          let
            fun options [] output mode input = (output,mode,input)
              | options ("--"::rest) output mode NONE =
                  (case rest of [file] => (output,mode,SOME file) | _ => raise Usage "expected one input file after --")
              | options ("-o"::file::rest) NONE mode input = options rest (SOME file) mode input
              | options ("--check"::rest) output "compile" input = options rest output "check" input
              | options ("--disassemble"::rest) output "compile" input = options rest output "disassemble" input
              | options (arg::rest) output mode NONE =
                  if String.isPrefix "-" arg then raise Usage ("unknown or repeated option: " ^ arg)
                  else options rest output mode (SOME arg)
              | options _ _ _ _ = raise Usage "expected exactly one input file"
            val (output,mode,input) = options args NONE "compile" NONE
            val file = case input of SOME s => s | NONE => raise Usage "missing input file"
            val () = inputName := file
            val () = if mode <> "compile" andalso Option.isSome output then raise Usage "-o requires compilation" else ()
          in if mode = "disassemble" then Bytecode.disassemble file
             else let val program = Compile.program (Infer.program (Parser.parse (Lexer.scan (read file))))
                  in if mode = "check" then ()
                     else let val destination = case output of SOME s => s
                                | NONE => #base (OS.Path.splitBaseExt file) ^ ".rbc"
                          in if OS.Path.mkAbsolute {path=file,relativeTo=OS.FileSys.getDir ()} =
                                OS.Path.mkAbsolute {path=destination,relativeTo=OS.FileSys.getDir ()}
                             then raise Usage "output must differ from input"
                             else publish destination (OS.Path.file file) program end
                  end
          end
      fun report s = (TextIO.output (TextIO.stdErr,s ^ "\n"); OS.Process.failure)
    in (run (); OS.Process.success)
       handle Source.Error ({line,column},category,message) =>
         report (!inputName ^ ":" ^ Int.toString line ^ ":" ^ Int.toString column ^ ": " ^ category ^ ": " ^ message)
       | Usage message => report ("rune: " ^ message ^ "\n" ^ usage)
       | IO.Io {name,function,cause} => report ("rune: I/O: " ^ function ^ " " ^ name ^ ": " ^ General.exnMessage cause)
       | OS.SysErr (message,_) => report ("rune: I/O: " ^ message)
       | ex => report ("rune: internal error: " ^ General.exnMessage ex)
    end
end

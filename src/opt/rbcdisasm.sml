(* runeopt --disasm: a program as runevm --disasm prints it (disassemble in
   vm/loader.c), line for line. A real constant is the one exception: the VM
   prints the number with C's %g, and this prints the text the file carries,
   since the tool never turns a real into a number (the portability rules of
   docs/building.md); tests/opt compares the two through awk's %g. A string
   ends at its first NUL, as C's %.*s ends it. *)
structure RbcDisasm =
struct
  fun constText (c : Rbc.const) : string =
    case c of
      Rbc.CInt i => Rbc.minus (IntInf.toString i)
    | Rbc.CWord w => "0wx" ^ String.map Char.toUpper (IntInf.fmt StringCvt.HEX w)
    | Rbc.CReal t => t
    | Rbc.CString s => "\"" ^ Substring.string (#1 (Substring.splitl (fn c => c <> #"\000") (Substring.full s))) ^ "\""
    | Rbc.CChar c => "#" ^ Int.toString c

  fun print (out : TextIO.outstream, p : Rbc.program) : unit =
    let
      val code = #code p
      val codeLen = String.size code
      val funcs = #funcs p
      val nfuncs = Vector.length funcs
      fun put s = TextIO.output (out, s)
      val () = Vector.appi (fn (i, c) => put ("const " ^ Int.toString i ^ " = " ^ constText c ^ "\n")) (#consts p)
      val () = put ("globals " ^ Int.toString (#nglobals p) ^ "\n")
      fun heads (pc, fi) =
        if fi < nfuncs andalso pc = #offset (Vector.sub (funcs, fi)) then
          let val {name, nlocals, ...} = Vector.sub (funcs, fi)
          in
            put ("function " ^ Int.toString fi ^ " " ^ name ^ " (locals " ^ Int.toString nlocals ^ ")\n");
            heads (pc, fi + 1)
          end
        else fi
      fun go (pc, fi) =
        if pc >= codeLen then ()
        else
          let
            val fi = heads (pc, fi)
            val opc = Rbc.byte (code, pc)
            val nargs = Vector.sub (Opcodes.nargs, opc)
            fun operands k = if k >= nargs then "" else " " ^ Rbc.i32Text (code, pc + 1 + 4 * k) ^ operands (k + 1)
            val position =
              case Rbc.lineAt (#lines p, pc) of
                SOME {file, line, col, ...} =>
                  "\t; " ^ Vector.sub (#files p, file) ^ ":" ^ Int.toString line ^ ":" ^ Int.toString col
              | NONE => ""
          in
            put ("  " ^ StringCvt.padLeft #" " 6 (Int.toString pc) ^ "  " ^ Vector.sub (Opcodes.names, opc)
                 ^ operands 0 ^ position ^ "\n");
            go (pc + 1 + 4 * nargs, fi)
          end
    in
      go (0, 0)
    end
end

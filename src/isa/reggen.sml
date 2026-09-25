(* What runeisa writes from the description of the register bytecode
   (src/isa/regs.sml): the tables and the cases of vm/new's loop, and the
   opcodes of the compiler's register target. As with the stack bytecode,
   every file is committed. *)
structure RegGen =
struct
  open Isa RegIsa
  type file = IsaGen.file

  val lines = IsaGen.lines
  val numbered = IsaGen.numbered
  val commaList = IsaGen.commaList
  val generated = IsaGen.generated

  (* The kinds of a register operand, as the VM numbers them: those of the
     stack bytecode, then a register. A list is described apart. *)
  val kinds = List.map K Isa.kinds @ [Register]
  fun kindName k = case k of K k => Isa.kindName k | Register => "REGISTER" | _ => "LIST"
  fun kindNumber k = #1 (valOf (List.find (fn (_, k') => k' = k) (numbered kinds)))

  (* ---- the fingerprint, of everything that says what a bytecode of it
     means, as the stack bytecode's is ---- *)
  fun canonical (instrs : rinstruction list, prims : primitive list) : string =
    let
      fun kind k =
        case k of
          Registers i => "regs" ^ Int.toString i
        | PrimArgs i => "args" ^ Int.toString i
        | _ => kindName k
      fun flowName f =
        case f of Next => "next" | Branch => "branch" | Jump => "jump" | Call => "call"
                | TailCall => "tailcall" | Return => "return" | Raise => "raise" | Halt => "halt"
      fun handlersName h = case h of Keeps => "keeps" | Installs => "installs" | Removes => "removes"
      fun instr (i : rinstruction) =
        String.concatWith " "
          ([#name i] @ List.map (kind o #2) (#operands i)
           @ [flowName (#flow i), handlersName (#handlers i), if #raises i then "raises" else "-"])
      fun prim (p : primitive) = #name p ^ " " ^ Int.toString (#arity p)
    in
      String.concatWith "\n" (["registers"] @ List.map instr instrs @ ["--"] @ List.map prim prims)
    end

  fun fingerprint (instrs, prims) : int =
    CharVector.foldl (fn (c, h) => (h * 31 + Char.ord c) mod 16777213) 7 (canonical (instrs, prims))

  (* ---- the tables of vm/new ---- *)

  fun regopsH (instrs : rinstruction list, fp : int) : file =
    let
      val is = numbered instrs
      fun listOf (i : rinstruction) =
        case list i of
          SOME (_, Registers k) => (Int.toString k, "0")
        | SOME (_, PrimArgs k) => (Int.toString k, "1")
        | _ => ("-1", "0")
    in
      {path = "vm/new/regops.h",
       text =
         lines
           (["/* " ^ generated ^ " */",
             "#ifndef RUNE_REGOPS_H",
             "#define RUNE_REGOPS_H",
             "",
             "/* The fingerprint of the register instruction set, which its .rbc",
             "   and its images carry. */",
             "#define REG_ISA_FINGERPRINT 0x" ^ IsaGen.hex8 fp ^ "u",
             "#define REG_ISA_FINGERPRINT_HEX \"" ^ IsaGen.hex8 fp ^ "\"",
             "",
             "enum RegOpcode {"]
            @ List.map (fn (n, i : rinstruction) => "  ROP_" ^ #name i ^ " = " ^ Int.toString n ^ ",  /* " ^ #doc i ^ " */") is
            @ ["  ROP__COUNT",
               "};",
               "",
               "static const char *const rop_names[] = {"]
            @ List.map (fn (_, i : rinstruction) => "  \"" ^ #name i ^ "\",") is
            @ ["};",
               "",
               "/* how many operands come before the list, if there is one */",
               "static const unsigned char rop_nfixed[] = {"]
            @ List.map (fn (_, i : rinstruction) => "  " ^ Int.toString (List.length (fixed i)) ^ ",") is
            @ ["};",
               "",
               "/* the operand that says how long the list is (-1: no list), and",
               "   whether it names a primitive, whose arity it is, or is a count */",
               "static const signed char rop_list_at[] = {"]
            @ List.map (fn (_, i) => "  " ^ #1 (listOf i) ^ ",") is
            @ ["};",
               "static const unsigned char rop_list_prim[] = {"]
            @ List.map (fn (_, i) => "  " ^ #2 (listOf i) ^ ",") is
            @ ["};",
               "",
               "/* What each operand is (src/isa/regs.sml), which says what the",
               "   loader accepts for it: the kinds of the stack bytecode and a",
               "   register. */",
               "enum RegOperandKind {"]
            @ List.map (fn (k, kind) => "  RK_" ^ kindName kind ^ " = " ^ Int.toString k ^ ",") (numbered kinds)
            @ ["};",
               "",
               "/* The kind of each operand before the list, by position; 0 past the last. */",
               "static const unsigned char rop_kinds[][4] = {"]
            @ List.map (fn (_, i : rinstruction) =>
                          let
                            val ks = List.map (fn (_, k) => Int.toString (kindNumber k)) (fixed i)
                            val ks = ks @ List.tabulate (4 - List.length ks, fn _ => "0")
                          in
                            "  {" ^ commaList ks ^ "},  /* " ^ #name i ^ " */"
                          end) is
            @ ["};",
               "",
               "#endif"])}
    end

  fun regCases (instrs : rinstruction list) : file =
    {path = "vm/new/reg_cases.h",
     text =
       lines
         (["/* " ^ generated,
           "   The cases of vm/new's loop, each the body of its instruction in",
           "   src/isa/regs.sml. */"]
          @ List.concat
              (List.map (fn (i : rinstruction) =>
                           ["case ROP_" ^ #name i ^ ": {"] @ IsaGen.indent 4 (#body i) @ ["    break;", "}"])
                        instrs))}

  (* ---- the .def file the scripts and the check of the documentation read,
     one line per instruction ---- *)
  fun regsDef (instrs : rinstruction list, fp : int) : file =
    {path = "vm/new/regs.def",
     text =
       lines
         (["# The register instruction set of vm/new. " ^ generated,
           "# The description is src/isa/regs.sml, in the language of src/isa/isa.sml.",
           "# fingerprint " ^ IsaGen.hex8 fp,
           "# rbc header " ^ IsaGen.headerEscapes (StackIsa.rbcVersion, fp),
           "# Format:  NAME  OPERANDS  DESCRIPTION",
           "# OPERANDS is '-' or a comma separated list of operand names, a list of",
           "# registers last; each operand, and each register of a list, is encoded as a",
           "# little-endian signed 32-bit integer following the opcode byte.",
           "# An opcode's number is its place in this file, from 0."]
          @ List.map (fn (i : rinstruction) =>
                        IsaGen.pad (#name i, 14)
                        ^ IsaGen.pad (case #operands i of
                                        [] => "-"
                                      | ops => String.concatWith "," (List.map (fn (n, Registers _) => n ^ "..." | (n, PrimArgs _) => n ^ "..." | (n, _) => n) ops), 16)
                        ^ #doc i)
                     instrs)}

  (* ---- the opcodes of the compiler's register target ---- *)

  fun regcodesSml (instrs : rinstruction list, fp : int) : file =
    let val is = numbered instrs
    in
      {path = "src/backend/regcodes.sml",
       text =
         lines
           (["(* " ^ generated ^ " *)",
             "structure RegCodes =",
             "struct",
             "  (* the fingerprint of the register instruction set, which its .rbc",
             "     carries; the layout's version is the stack bytecode's *)",
             "  val fingerprint = " ^ Int.toString fp,
             "  val fingerprintHex = \"" ^ IsaGen.hex8 fp ^ "\""]
            @ List.map (fn (n, i : rinstruction) => "  val " ^ #name i ^ " = " ^ Int.toString n) is
            @ ["  val count = " ^ Int.toString (List.length instrs),
               "  val names = Vector.fromList [" ^ commaList (List.map (fn i : rinstruction => "\"" ^ #name i ^ "\"") instrs) ^ "]",
               "end"])}
    end

  fun files (instrs : rinstruction list, prims : primitive list) : file list =
    let
      val () = RegIsa.check instrs
      val fp = fingerprint (instrs, prims)
    in
      [regsDef (instrs, fp), regopsH (instrs, fp), regCases instrs, regcodesSml (instrs, fp)]
    end
end

structure Bytecode =
struct
  val magic = "RUNEBC\r\n"
  val maxFile = 16777216
  fun write path source ({strings,functions} : Compile.program) =
    let
      val estimated = 28 + String.size source +
        List.foldl (fn (s,n) => n+4+String.size s) 0 strings +
        List.foldl (fn ({code,...} : Compile.function,n) => n+12+13*List.length code) 0 functions
      val () = if estimated > maxFile then Source.fail Source.start "limit" "bytecode exceeds 16 MiB" else ()
      val stream = BinIO.openOut path
      fun byte n = BinIO.output1 (stream, Word8.fromInt n)
      fun u32 n =
        let fun loop 0 _ = ()
              | loop k v = (byte (IntInf.toInt (IntInf.mod (v,IntInf.fromInt 256))); loop (k-1) (IntInf.div (v,IntInf.fromInt 256)))
        in loop 4 (IntInf.mod (n,Source.modulus)) end
      fun count n = u32 (IntInf.fromInt n)
      fun text s = (count (String.size s); BinIO.output (stream, Byte.stringToBytes s))
      fun instruction ({code,operand,pos={line,column}} : Compile.instruction) =
        (byte code; u32 (!operand); count line; count column)
      fun function ({locals,environment,code} : Compile.function) =
        (count locals; count environment; count (List.length code); List.app instruction code)
      fun output () =
        (BinIO.output (stream, Byte.stringToBytes magic); count 3; count 0;
         count (List.length functions); count (List.length strings); text source;
         List.app text strings; List.app function functions; BinIO.closeOut stream)
    in output () handle ex => (BinIO.closeOut stream handle _ => (); raise ex) end

  fun disassemble path =
    let
      fun bad msg = Source.fail Source.start "bytecode" msg
      val stream = BinIO.openIn path
      val bytes = let val result = BinIO.inputN (stream,maxFile+1)
          in BinIO.closeIn stream; result end
        handle ex => (BinIO.closeIn stream handle _ => (); raise ex)
      val size = Word8Vector.length bytes
      val () = if size > maxFile then bad "bytecode exceeds 16 MiB" else ()
      val index = ref 0
      fun byte () = if !index >= size then bad "truncated bytecode"
        else let val n = Word8.toInt (Word8Vector.sub (bytes,!index)) in index := !index+1; n end
      fun u32 () =
        let fun loop 0 _ n = n
              | loop k scale n = let val b = byte ()
                                 in loop (k-1) (IntInf.* (scale,IntInf.fromInt 256)) (IntInf.+ (n,IntInf.* (IntInf.fromInt b,scale))) end
        in loop 4 (IntInf.fromInt 1) (IntInf.fromInt 0) end
      fun bounded limit what =
        let val n = u32 () in if IntInf.> (n,IntInf.fromInt limit) then bad (what ^ " exceeds limit") else IntInf.toInt n end
      fun text () =
        let val n = bounded Source.maxString "string" val start = !index
        in if n > size-start then bad "truncated string" else ();
           index := start+n;
           Byte.bytesToString (Word8VectorSlice.vector (Word8VectorSlice.slice (bytes,start,SOME n))) end
      val header = String.implode (List.tabulate (8, fn _ => Char.chr (byte ())))
      val () = if header <> magic then bad "invalid magic" else ()
      val () = if not (IntInf.eq (u32 (),IntInf.fromInt 3)) then bad "unsupported bytecode version" else ()
      val () = if not (IntInf.eq (u32 (),IntInf.fromInt 0)) then bad "entry function must be zero" else ()
      val functionCount = bounded Source.maxCount "functions"
      val () = if functionCount = 0 then bad "no entry function" else ()
      val constants = bounded Source.maxCount "constants"
      val source = text ()
      val () = if CharVector.exists (fn c => c = #"\000") source then bad "NUL in source filename" else ()
      val pool = List.tabulate (constants, fn _ => text ())
      val total = ref 0
      fun function fid =
        let val locals = bounded Source.maxCount "locals"
            val environment = bounded Source.maxCount "environment"
            val count = bounded Source.maxCount "instructions"
            val () = total := !total+count
            val () = if count = 0 orelse !total > Source.maxCount then bad "invalid instruction count" else ()
            val () = if fid = 0 andalso environment <> 0 then bad "entry function has captures" else ()
            val () = if fid <> 0 andalso locals = 0 then bad "function has no argument slot" else ()
            fun instruction i =
              let val opnum = byte () val operand = u32 () val line = u32 () val column = u32 ()
                  val () = if opnum >= Vector.length Opcode.names then bad "unknown opcode" else ()
                  val kind = Vector.sub (Opcode.operands,opnum)
                  fun below limit = if IntInf.>= (operand,IntInf.fromInt limit) then bad ("invalid " ^ kind ^ " operand") else ()
                  val () = case kind of
                      "none" => if not (IntInf.eq (operand,IntInf.fromInt 0)) then bad "nonzero unused operand" else ()
                    | "failure" => below 2
                    | "constructor" => (below (2*Source.maxCount);
                        if opnum = Opcode.PAYLOAD andalso IntInf.eq (IntInf.mod (operand,IntInf.fromInt 2),IntInf.fromInt 0)
                        then bad "payload requires unary constructor" else ())
                    | "bool" => below 2 | "builtin" => below 4
                    | "constant" => below constants | "local" => below locals
                    | "environment" => below environment | "index" => below Source.maxCount
                    | "arity" => if IntInf.< (operand,IntInf.fromInt 2) orelse IntInf.> (operand,IntInf.fromInt Source.maxCount) then bad "invalid tuple arity" else ()
                    | "function" => (below functionCount; if IntInf.eq (operand,IntInf.fromInt 0) then bad "cannot close entry function" else ())
                    | "target" => (below count; if IntInf.<= (operand,IntInf.fromInt i) then bad "branch must go forward" else ())
                    | _ => ()
                  val () = if (opnum = Opcode.HALT andalso fid <> 0) orelse
                    (fid = 0 andalso (opnum = Opcode.RETURN orelse opnum = Opcode.TAILCALL orelse opnum = Opcode.SELF))
                    then bad "instruction is invalid in this function" else ()
                  val () = if IntInf.eq (line,IntInf.fromInt 0) orelse IntInf.eq (column,IntInf.fromInt 0) then bad "invalid source position" else ()
                  val value = if kind = "int" andalso IntInf.> (operand,Source.maxInt) then IntInf.- (operand,Source.modulus) else operand
              in Int.toString i ^ " " ^ Vector.sub (Opcode.names,opnum) ^ " " ^
                 IntInf.toString value ^ " @" ^ IntInf.toString line ^ ":" ^ IntInf.toString column ^ "\n" end
            val code = List.tabulate (count,instruction)
        in "function " ^ Int.toString fid ^ "; locals=" ^ Int.toString locals ^
           "; environment=" ^ Int.toString environment ^ "\n" ^ String.concat code end
      val functions = List.tabulate (functionCount,function)
      val () = if !index <> size then bad "trailing bytecode data" else ()
      fun output s = TextIO.output (TextIO.stdOut,s)
      val () = output ("Rune bytecode v3; source=" ^ String.toString source ^ "\n")
      val () = List.app (fn (i,s) => output ("string " ^ Int.toString i ^ " \"" ^ String.toString s ^ "\"\n"))
        (ListPair.zip (List.tabulate (constants, fn i => i),pool))
    in List.app output functions end
end

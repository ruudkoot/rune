structure Bytecode =
struct
  val magic = "RUNEBC\r\n"
  val maxFile = 16777216
  fun write path source ({locals,strings,code} : Compile.program) =
    let
      val estimated = 28 + String.size source +
        List.foldl (fn (s,n) => n+4+String.size s) 0 strings + 13*List.length code
      val () = if estimated > maxFile then Source.fail Source.start "limit" "bytecode exceeds 16 MiB" else ()
      val stream = BinIO.openOut path
      fun byte n = BinIO.output1 (stream, Word8.fromInt n)
      fun u32 n =
        let fun loop 0 _ = ()
              | loop k v = (byte (IntInf.toInt (IntInf.mod (v,256))); loop (k-1) (IntInf.div (v,256)))
        in loop 4 (IntInf.mod (n,Source.modulus)) end
      fun count n = u32 (IntInf.fromInt n)
      fun text s = (count (String.size s); BinIO.output (stream, Byte.stringToBytes s))
      fun instruction ({code,operand,pos={line,column}} : Compile.instruction) =
        (byte code; u32 (!operand); count line; count column)
      fun output () =
        (BinIO.output (stream, Byte.stringToBytes magic); count 1; count locals;
         count (List.length strings); count (List.length code); text source;
         List.app text strings; List.app instruction code; BinIO.closeOut stream)
    in output () handle ex => (BinIO.closeOut stream handle _ => (); raise ex) end

  fun disassemble path =
    let
      fun bad msg = Source.fail Source.start "bytecode" msg
      val stream = BinIO.openIn path
      val bytes = (BinIO.inputN (stream,maxFile+1) before BinIO.closeIn stream)
        handle ex => (BinIO.closeIn stream handle _ => (); raise ex)
      val size = Word8Vector.length bytes
      val () = if size > maxFile then bad "bytecode exceeds 16 MiB" else ()
      val index = ref 0
      fun byte () = if !index >= size then bad "truncated bytecode"
        else let val n = Word8.toInt (Word8Vector.sub (bytes,!index)) in index := !index+1; n end
      fun u32 () =
        let fun loop 0 _ n = n
              | loop k scale n = let val b = byte ()
                                 in loop (k-1) (scale*256) (n+IntInf.fromInt b*scale) end
        in loop 4 1 0 end
      fun bounded limit what =
        let val n = u32 () in if n > IntInf.fromInt limit then bad (what ^ " exceeds limit") else IntInf.toInt n end
      fun text () =
        let val n = bounded Source.maxString "string"
            val start = !index
        in if n > size-start then bad "truncated string" else ();
           index := start+n;
           Byte.bytesToString (Word8VectorSlice.vector (Word8VectorSlice.slice (bytes,start,SOME n))) end
      val header = String.implode (List.tabulate (8, fn _ => Char.chr (byte ())))
      val () = if header <> magic then bad "invalid magic" else ()
      val () = if u32 () <> 1 then bad "unsupported bytecode version" else ()
      val locals = bounded Source.maxCount "locals"
      val constants = bounded Source.maxCount "constants"
      val count = bounded Source.maxCount "instructions"
      val () = if count = 0 then bad "empty code" else ()
      val source = text ()
      val () = if CharVector.exists (fn c => c = #"\000") source then bad "NUL in source filename" else ()
      val pool = List.tabulate (constants, fn _ => text ())
      fun instruction i =
        let val opnum = byte ()
            val operand = u32 ()
            val line = u32 ()
            val column = u32 ()
            val () = if opnum >= Vector.length Opcode.names then bad "unknown opcode" else ()
            val kind = Vector.sub (Opcode.operands,opnum)
            fun below limit = if operand >= IntInf.fromInt limit then bad ("invalid " ^ kind ^ " operand") else ()
            val () = case kind of
                "none" => if operand <> 0 then bad "nonzero unused operand" else ()
              | "bool" => below 2 | "builtin" => below 4
              | "constant" => below constants | "local" => below locals
              | "target" => (below count; if operand <= IntInf.fromInt i then bad "branch must go forward" else ())
              | _ => ()
            val () = if line = 0 orelse column = 0 then bad "invalid source position" else ()
            val value = if kind = "int" andalso operand > Source.maxInt then operand-Source.modulus else operand
        in Int.toString i ^ " " ^ Vector.sub (Opcode.names,opnum) ^ " " ^
           IntInf.toString value ^ " @" ^ IntInf.toString line ^ ":" ^ IntInf.toString column ^ "\n" end
      val instructions = List.tabulate (count,instruction)
      val () = if !index <> size then bad "trailing bytecode data" else ()
      val () = print ("Rune bytecode v1; source=" ^ String.toString source ^ "; locals=" ^ Int.toString locals ^ "\n")
      val () = List.app (fn (i,s) => print ("string " ^ Int.toString i ^ " \"" ^ String.toString s ^ "\"\n"))
        (ListPair.zip (List.tabulate (constants, fn i => i),pool))
    in List.app print instructions end
end

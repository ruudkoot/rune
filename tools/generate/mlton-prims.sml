(* Families of MLton primitives, instantiated from their observed types. *)
structure GenerateMLtonPrims =
struct
  open MeasureCommon
  structure T=GenerateText
  fun make (settings:GenerateRewrites.settings) rows =
    let val extra=ref [] : (string*string) list ref val used=ref [] : string list ref val emitted=ref [] : string list ref val output=ref [] : string list ref
        fun set name value=extra:=(name,value)::List.filter (fn (old,_) => old<>name) (!extra)
        fun use name=(if List.exists (fn old => old=name) (!used) then () else used:= !used @ [name];"O_" ^ name)
        fun inst kind width =
          let val n=integer (trim width) val name=kind ^ Int.toString n
          in if kind="C" then (need (List.exists (fn i => i=n) [8,16,32],"char" ^ width);use name)
             else if List.exists (fn i => i=n) [8,16,32,64] then (set name ("XC2Fixed." ^ name);use name)
             else
               (if List.exists (fn (old,_) => old=name) (!extra) then () else
                  let val rune=if n<8 then "8" else if n<16 then "16" else if n<32 then "32" else ""
                      val value=if kind="I" then "XC2FixedInt (type int = Int" ^ rune ^ ".int val width = " ^ Int.toString n ^ " val toInt64 = " ^ (if rune="" then "Int64.fromInt" else "Int64.fromInt o Int" ^ rune ^ ".toInt") ^ " val fromInt64 = " ^ (if rune="" then "Int64.toInt" else "Int" ^ rune ^ ".fromInt o Int64.toInt") ^ ")"
                         else "XC2FixedWord (type word = Word" ^ rune ^ ".word val width = " ^ Int.toString n ^ " val toLarge = Word" ^ rune ^ ".toLarge val fromLarge = Word" ^ rune ^ ".fromLarge)"
                  in set name value end;use name) end
        fun res ty width other =
          let val ty=T.substitute "^\\(|\\)$" (fn _ => "") (trim ty)
              fun typed kind prefix=let val bare=T.prefix "Primitive." ty val width=hd (fields #"." (T.prefix prefix bare)) in inst kind width end
          in case ty of "int" => inst "I" width | "word" => inst "W" width | "char" => inst "C" width | "big" => inst other width | "real" => "R" ^ width | "SeqIndex.int" => inst "I" "64"
            | _ => if T.matches "^(Primitive\\.)?Int[0-9]+\\.(int|t)$" ty then typed "I" "Int"
                else if T.matches "^(Primitive\\.)?Word[0-9]+\\.(word|t)$" ty then typed "W" "Word"
                else if T.matches "^Real[0-9]+\\.(real|t)$" ty then "R" ^ hd (fields #"." (T.prefix "Real" ty))
                else if T.matches "^C_[A-Za-z0-9_]+\\.t$" ty then
                   let val kind=GenerateRewrites.lookup (hd (fields #"." ty)) (#ctypes settings)
                   in if String.isPrefix "Int" kind then inst "I" (T.prefix "Int" kind) else if String.isPrefix "Word" kind then inst "W" (T.prefix "Word" kind) else raise Failed ("the type " ^ ty) end
                else raise Failed ("the type " ^ ty) end
        fun kindOf ty=case trim ty of "int" => "I" | "word" => "W" | "char" => "C" | _ => ""
        fun emit id expression=if List.exists (fn old => old=id) (!emitted) then () else (emitted:=id:: !emitted;output:= !output @ ["  val " ^ id ^ " = " ^ expression ^ "\n"])
        fun row line =case tabs line of ["prim",name,ty] =>
          let val id=name ^ (if List.exists (fn key => key="prim\t" ^ name) (#ambiguous settings) then "__" ^ GenerateRewrites.mangle false ty else "")
              val (args,result)=case T.splitAt "->" ty of SOME pair => pair | NONE => ("",ty)
              val args=fields #"*" args fun arg i=List.nth (args,i)
              val prefix=hd (fields #"_" name) val operation=String.concatWith "_" (tl (fields #"_" name))
              fun width prefix=T.prefix prefix (hd (fields #"_" name))
              val signed=size prefix>4 andalso String.sub (prefix,4) = #"S"
              val suffix=if signed then "S" else "U"
              fun tail key= #2 (valOf (T.splitAt key name))
              fun storage ty width=res ty width ""
              fun family pattern=T.matches pattern name
          in if family "^Word[0-9]+_(add|sub|neg|mul|andb|orb|xorb|notb|lshift|rol|ror)$" then emit id (storage (arg 0) (width "Word") ^ "." ^ operation)
             else if family "^Word[SU][0-9]+_(lt|mul|quot|rem|rshift)$" then emit id (storage (arg 0) (String.extract (prefix,5,NONE)) ^ "." ^ operation ^ (if operation="mul" then "" else suffix))
             else if family "^WordS[0-9]+_(add|sub|mul|neg)CheckP$" then emit id (storage (arg 0) (width "WordS") ^ "." ^ operation)
             else if family "^Word[SU][0-9]+_extdToWord[0-9]+$" then
               let val a=String.extract (prefix,5,NONE) val b=tail "extdToWord" val x=res (arg 0) a (kindOf result) val y=res result b (kindOf (arg 0))
               in emit id (if x=y then "fn x => x" else "fn x => " ^ y ^ ".fromBits (" ^ x ^ "." ^ (if signed then "sbits" else "bits") ^ " x)") end
             else if family "^Word[SU][0-9]+_rndToReal[0-9]+$" then emit id (storage (arg 0) (String.extract (prefix,5,NONE)) ^ ".toReal" ^ tail "rndToReal" ^ suffix)
             else if family "^Real[0-9]+_rndToWord[SU][0-9]+$" then emit id (storage result (String.extract (tail "rndToWord",1,NONE)) ^ ".fromReal" ^ width "Real")
             else if family "^Real[0-9]+_rndToReal[0-9]+$" then emit id ("XC2Real" ^ width "Real" ^ ".rndToReal" ^ tail "rndToReal")
             else if family "^Real[0-9]+_castToWord[0-9]+$" then emit id ("XC2Real" ^ width "Real" ^ ".castToWord" ^ width "Real")
             else if family "^Word[0-9]+_castToReal[0-9]+$" then emit id ("XC2Real" ^ width "Word" ^ ".castFromWord" ^ width "Word")
             else if family "^Real[0-9]+_" then emit id ("XC2Real" ^ width "Real" ^ "." ^ operation)
             else if family "^CPointer_(get|set)Word[0-9]+$" then
               let val n=tail "Word" val bytes=Int.toString (integer n div 8)
               in if String.isSubstring "get" name then emit id ("fn (p, i) => " ^ storage result n ^ ".fromBits (XC2Mem.get (p, " ^ bytes ^ " * XC2Index.index i, " ^ bytes ^ "))")
                  else emit id ("fn (p, i, x) => XC2Mem.set (p, " ^ bytes ^ " * XC2Index.index i, " ^ bytes ^ ", " ^ storage (arg 2) n ^ ".bits x)") end
             else if family "^CPointer_(get|set)Real[0-9]+$" then
               let val n=tail "Real" val bytes=Int.toString (integer n div 8)
               in if String.isSubstring "get" name then emit id ("fn (p, i) => XC2Real" ^ n ^ ".castFromWord" ^ n ^ " (" ^ inst "W" n ^ ".fromBits (XC2Mem.get (p, " ^ bytes ^ " * XC2Index.index i, " ^ bytes ^ ")))")
                  else emit id ("fn (p, i, x) => XC2Mem.set (p, " ^ bytes ^ " * XC2Index.index i, " ^ bytes ^ ", " ^ inst "W" n ^ ".bits (XC2Real" ^ n ^ ".castToWord" ^ n ^ " x))") end
             else if family "^Word8(Array|Vector)_(sub|update)Word[0-9]+$" then
               let val n=tail "Word" (* the final Word, after the operation *)
                   val n=List.last (String.tokens (not o Char.isDigit) operation)
                   val bytes=integer n div 8 val b=Int.toString bytes val update=String.isSubstring "update" name
                   val w=storage (if update then arg 2 else result) n val get=if String.isSubstring "Array" name then "XC2.Array.sub" else "Vector.sub"
               in if update then emit id ("fn (a, i, x) => let val v = " ^ w ^ ".bits x fun loop k = if k >= " ^ b ^ " then () else (XC2.Array.update (a, " ^ b ^ " * XC2Index.index i + k, Word8.fromLarge (Word64.>> (v, Word.fromInt (8 * k)))); loop (k + 1)) in loop 0 end")
                  else emit id ("fn (a, i) => let fun loop (k, v) = if k < 0 then v else loop (k - 1, Word64.orb (Word64.<< (v, 0w8), Word8.toLarge (" ^ get ^ " (a, " ^ b ^ " * XC2Index.index i + k)))) in " ^ w ^ ".fromBits (loop (" ^ Int.toString (bytes-1) ^ ", 0w0)) end") end
             else () end | _ => ()
        val ()=List.app row rows
        fun declaration name="structure O_" ^ name ^ " = XC2FixedOps (" ^ (if String.isPrefix "C" name then "XC2Fixed." ^ name else GenerateRewrites.lookup name (!extra)) ^ ")\n"
    in "(* Generated by tests/basis/xc2/mlton/gen.sh -- do not edit. *)\n" ^ String.concat (List.map declaration (!used)) ^ "structure XC2PrimGen =\nstruct\n" ^ String.concat (!output) ^ "end\n" end
end

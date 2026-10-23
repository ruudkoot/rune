(* Compare portable byte conversion against independently compiled native C. *)
structure Real32Oracle =
struct
  fun number text=case IntInf.fromString text of SOME n=>n | NONE=>raise Fail "oracle number"
  fun bytes width n=ForeignBytes.integer{width=width,signed=false,littleEndian=false,value=n}
  fun bits b=ForeignBytes.value{signed=false,littleEndian=false,bytes=b}
  fun check line=
    case String.tokens(fn c=>c= #"|" orelse Char.isSpace c)line of
      ["narrow",input,expected]=>
        let val value=ForeignBytes.real64Value{littleEndian=false,bytes=bytes 8(number input)}
            val actual=bits(ForeignBytes.real32{littleEndian=false,value=value})
        in if actual=number expected then () else raise Fail("binary32 narrowing differs: " ^ line ^ " actual " ^ IntInf.toString actual) end
    | ["widen",input,expected]=>
        let val value=ForeignBytes.real32Value{littleEndian=false,bytes=bytes 4(number input)}
            val actual=bits(ForeignBytes.real64{littleEndian=false,value=value})
        in if actual=number expected then () else raise Fail("binary32 widening differs: " ^ line) end
    | _=>raise Fail "oracle line"
  fun main [file]=
    let val input=TextIO.openIn file
        fun loop count=case TextIO.inputLine input of NONE=>count | SOME line=>(check line;loop(count+1))
        val count=loop 0 val ()=TextIO.closeIn input
    in if count<1000 then raise Fail "oracle lost cases" else print("PASS binary32 native oracle: " ^ Int.toString count ^ " conversions\n") end
    | main _=raise Fail "expected native oracle output"
end
val ()=Real32Oracle.main(CommandLine.arguments())

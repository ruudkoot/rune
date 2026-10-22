(* Packed ABI boundaries use frozen Python byte/masking answers and an
   independent assembler. Invalid magnitudes never use Rune's pack writer. *)
structure IntInfStorage =
struct
  open IntInfChecks
  fun bytes value = case Hex.toBytes (string value) of SOME bytes => bytes | NONE => raise Failed "invalid storage fixture hex"
  fun one (c : context) () =
    let val data=fixture "storage"
        val cases=array (field "cases" data)
        fun one (n,row)=
          let val body=string (field "body" row)
              val data=case field "data" row of Json.Null => NONE | value => SOME (bytes value)
              val header=case data of NONE => "" | SOME data => "const mag string \"" ^ String.implode (List.tabulate (size data,fn _ => #"a")) ^ "\"\n"
              val listing=path c (Int.toString n ^ ".rasm")
              val rbc=path c (Int.toString n ^ ".rbc")
              val ()=mkdirs (#directory c)
              val ()=write (listing,header ^ "function main 1\n" ^ body ^ "\nHALT\n")
              val program=BytecodeFixture.assemble {opdefs=fromRoot "runtime/stack/opcodes.def",primdefs=fromRoot "runtime/prims.def",listing=listing}
              val program=case data of NONE => program | SOME data =>
                  (need (size program>=21+size data andalso String.isPrefix "RUNE" program
                         andalso String.substring (program,12,5)="\001\000\000\000\003", "unexpected independent fixture header");
                   need (String.substring (program,17,4)=BytecodeFixture.u32 (size data),"fixture magnitude length differs");
                   String.substring (program,0,21) ^ data ^ String.extract (program,21+size data,NONE))
              val ()=CachePlant.writeBinary rbc program
              val result=execute c ("storage-" ^ Int.toString n) 15 [] [#vm c,rbc]
          in case field "message" row of Json.Null => output result (bytes (field "expected" row))
             | value => rejected result (string value) end
        val ()=List.app one (ListPair.zip (List.tabulate (length cases,fn i => i+1),cases))
    in say ("PASS " ^ Int.toString (length cases) ^ " packed-storage boundary checks\n") end
end

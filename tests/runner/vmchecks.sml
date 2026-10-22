(* Loader/option refusals shared by local, sanitizer, emulated and Windows
   ways. All binary lengths are manufactured independently of the compiler. *)
structure VMChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok,why)=if ok then () else raise Failed why
  val zero=BytecodeFixture.u32 0
  val one=BytecodeFixture.u32 1
  val huge=BytecodeFixture.le 4 4294967295
  fun bytes values=String.implode (List.map Char.chr values)
  fun cases defs =
    let val header=BytecodeFixture.header defs
        val definitions=BytecodeFixture.definitions defs
        val self=case List.find (fn (fields,_) => hd fields="SELF")
                 (ListPair.zip (definitions,List.tabulate (length definitions,fn i => i))) of
               SOME value => value | NONE => raise Failed "instruction definitions have no SELF"
        val operands=List.nth (#1 self,1)
        val n=if operands="-" then 0 else length (String.fields (fn ch => ch = #",") operands)
        val code=str (Char.chr (#2 self)) ^ String.concat (List.tabulate (n,fn _ => zero))
        val prog=header ^ zero ^ zero ^ one ^ zero ^ one ^ BytecodeFixture.text "f" ^ one ^ bytes [0]
        val file=one ^ BytecodeFixture.text "a"
        fun binary name message data=(name,message,[name ^ ".rbc"],SOME (name ^ ".rbc",data))
        fun option name args=(name,"usage:",args @ ["empty.rbc"],NONE)
        fun frame data=one ^ one ^ "g" ^ one ^ BytecodeFixture.u32 5 ^ data
        val line=file ^ one ^ BytecodeFixture.u32 5 ^ bytes [0,0,2,2,2]
    in [binary "empty" "not a Rune bytecode file" "",
        binary "version" "unsupported bytecode version" ("RUNE" ^ BytecodeFixture.u32 255)]
       @ List.map (fn version => binary ("version" ^ Int.toString version) "unsupported bytecode version" ("RUNE" ^ BytecodeFixture.u32 version)) [1,2,3,4]
       @ [binary "isa" "bytecode of another instruction set" (String.substring (header,0,8) ^ huge),
          binary "string" "bad string constant" (header ^ one ^ bytes [3,240,255,255,255]),
          binary "real" "bad real constant" (header ^ one ^ bytes [2] ^ huge),
          binary "name" "bad function name" (header ^ zero ^ zero ^ one ^ zero ^ one ^ huge),
          binary "code" "truncated code" (header ^ zero ^ zero ^ one ^ zero ^ one ^ zero ^ huge),
          option "heap-size" ["--heap-size","18446744073709551616"],
          option "heap-size-text" ["--heap-size","64M"],option "gc-stress" ["--gc-stress","18446744073709551616"],
          option "heap-fill-zero" ["--heap-fill","0"],option "heap-fill-over" ["--heap-fill","101"],
          binary "debug-files" "bad file table" (prog ^ huge),
          binary "debug-filename" "bad file name" (prog ^ one ^ huge),
          binary "debug-lines" "bad line table" (prog ^ file ^ one ^ zero),
          binary "debug-line-pc" "line table out of range" (prog ^ file ^ one ^ BytecodeFixture.u32 5 ^ bytes [9,0,2,2,0]),
          binary "debug-line-file" "line table out of range" (prog ^ file ^ one ^ BytecodeFixture.u32 5 ^ bytes [0,2,2,2,0]),
          binary "debug-line-zero" "line table out of range" (prog ^ file ^ one ^ BytecodeFixture.u32 5 ^ bytes [0,0,0,2,0]),
          binary "debug-line-tail" "bad line table" (prog ^ file ^ one ^ BytecodeFixture.u32 6 ^ bytes [0,0,2,2,0,0]),
          binary "debug-line-inlined" "line table out of range" (prog ^ line ^ zero ^ zero ^ zero),
          binary "debug-inlined-parent" "bad table of inlined functions" (prog ^ line ^ frame (bytes [0,0,1,1,2])),
          binary "debug-inlined-file" "bad table of inlined functions" (prog ^ line ^ frame (bytes [0,1,1,1,0])),
          binary "debug-inlined-name" "bad table of inlined functions" (prog ^ line ^ frame (bytes [1,0,1,1,0])),
          binary "named-function" ("fatal error at pc " ^ Int.toString (size code) ^ " in queens")
             (header ^ zero ^ zero ^ one ^ zero ^ one ^ BytecodeFixture.text "queens" ^ BytecodeFixture.u32 (size code) ^ code
                ^ String.concat (List.tabulate (7,fn _ => zero))),
          ("resume","no image to resume from",["--resume","0"],NONE),
          ("resume-token","no image to resume from",["--resume","x"],NONE)]
    end
  fun run {vm,defs,directory,logs} =
    let val ()=(mkdirs directory;mkdirs logs)
        val cases=cases defs
        val ()=List.app (fn (_,_,_,file) => case file of SOME (name,data) => write (directory ^ "/" ^ name,data) | NONE => ()) cases
        fun check (name,message,args,_) =
          let val status=Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (1024*1024),core=SOME 0}
               (unsetEnv ["FORCE_COLOR","CLICOLOR_FORCE"])
                {cmd=fromRoot vm :: args,dir=SOME directory,stdin="",stdout=logs ^ "/" ^ name ^ ".stdout",stderr=logs ^ "/" ^ name ^ ".stderr",timeout=60}
          in need (status=2 andalso String.isSubstring message (read (logs ^ "/" ^ name ^ ".stderr")),
                   name ^ ": expected exit2 and " ^ message ^ "; got " ^ Int.toString status ^ ": " ^ firstLine (logs ^ "/" ^ name ^ ".stderr")) end
    in List.app check cases;say ("PASS VM refusals: " ^ Int.toString (length cases) ^ " cases\n") end
end

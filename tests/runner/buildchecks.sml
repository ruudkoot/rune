(* Final Make recipe audit: C fixtures remain independent subjects, while
   SML schedules them, bounds execution and checks every verdict. *)
structure BuildChecks =
struct
  open Sh
  fun tagged tags tree=List.foldl (fn (tag,tree) => Test.tag tag tree) tree tags
  fun job name args after=Test.it name
    {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
     env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 1800,cap=0,cpus=1,memory=1000,
     pools=[],exclusive=false,after=after,judge=failLines} : Run.command Test.tree
  fun executable name program args=Test.it name
    {program=fromRoot program,args=program::args,env=NONE,dir=SOME ".",stdin=NONE,
     timeout=Time.fromSeconds 300,cap=0,cpus=1,memory=500,pools=[],exclusive=false,after=[],judge=failLines} : Run.command Test.tree
  val portableFiles=["runtime/register/jit/emit.c","runtime/register/jit/masm.c","runtime/register/jit/masm.h",
       "runtime/register/jit/compile.c","runtime/register/jit/compile.h","runtime/register/jit/dump.c","runtime/register/jit.c"]
  fun encoderFree text =
    let fun word c=Char.isAlphaNum c orelse c = #"_"
        fun starts prefix i=i<=size text-size prefix andalso String.substring (text,i,size prefix)=prefix
        fun loop i=if i=size text then true else
          if (i=0 orelse not (word (String.sub (text,i-1)))) andalso
             List.exists (fn prefix => starts prefix i) ["x64_","a64_","X64","A64"]
          then false else loop (i+1)
    in loop 0 end
  fun asmCheck ()=List.app (fn file => if exists file andalso encoderFree (read file) then () else
      say ("FAIL JIT encoder independence: " ^ file ^ " names an encoder or is missing\n")) portableFiles
  fun asmFaults ()=List.app (fn (text,expected) => if encoderFree text=expected then () else
      say ("FAIL JIT encoder guard vector: " ^ String.toString text ^ "\n"))
      [("asm_emit",true),("prefix_x64_safe",true),("x64_bad",false),(" a64_bad",false),
       ("X64",false),("A64Assembler",false),("aX64",true),("/* X64 */",false)]
  fun directory ()=let val out=run ^ "/register-jit" in mkdirs out;out end
  fun execute label args seconds =
    let val out=directory ()
    in Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (16*1024*1024),core=SOME 0} (fn e => e)
        {cmd=args,dir=SOME root,stdin="",stdout=out ^ "/" ^ label ^ ".out",stderr=out ^ "/" ^ label ^ ".err",timeout=seconds} end
  fun compile ()=if execute "compile" [fromRoot "bin/rune",fromRoot "tests/lang/rt.deeprec_stack.sml","-o",directory () ^ "/deeprec.rbc"] 600=0
       then () else say "FAIL JIT deep recursion: compilation failed\n"
  val modes=[("all",["--jit=all"]),("tiered",["--jit=baseline","--jit-calls=1","--jit-work=1","--jit-stress=3"]),
             ("callret",["--jit=all","--jit-returns=call"])]
  fun deep name =
    let val flags=case List.find (fn (label,_) => label=name) modes of SOME (_,flags) => flags | NONE => raise Fail "unknown JIT recursion mode"
        (* POSIX sh provides only the OS stack-limit operation; arguments,
           cases, deadlines and exact output checks are owned by SML. *)
        val status=execute name (["/bin/sh","-c","ulimit -s 1024 && exec \"$@\"","jit-stack",fromRoot "bin/runevm"] @ flags @ [directory () ^ "/deeprec.rbc"]) 300
    in if status=0 andalso same (directory () ^ "/" ^ name ^ ".out","tests/lang/rt.deeprec_stack.expected") then ()
       else say ("FAIL JIT deep recursion: " ^ name ^ " differs or exits unsuccessfully\n") end
  fun command ["build-asm-check"]=SOME asmCheck
    | command ["build-asm-faults"]=SOME asmFaults
    | command ["build-jit-compile"]=SOME compile
    | command ["build-jit-deep",name]=SOME (fn () => deep name)
    | command _=NONE
  val vm=Test.it "vm-refusals"
    {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-windows vm --vm \"${RUNEVM:-bin/runevm-stack}\" --out \"$RUNE_TEST_RUN/low-level/vm\""],
     env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 900,cap=0,cpus=1,memory=500,pools=[],exclusive=false,after=[],judge=failLines} : Run.command Test.tree
  val tree=Test.describe "low-level"
    [tagged ["check","test","test-low-level","covers:tests/compiler/*","covers:tests/runtime/*"]
       (Test.describe "basic" [vm,executable "heap" "build/heap_test" []]),
     tagged ["check","layout","test-heap","test-heap-hooks","covers:tests/runtime/*"]
       (Test.describe "heap-hooks" (List.map (fn (name,binary) => executable name binary [])
          [("default","build/heap_test"),("gc-bits","build/heap_test-gcbits"),("cards","build/heap_test-cards")])),
     tagged ["check","test-register-jit","test-register-jit-steps","covers:tests/register/*"]
       (Test.describe "jit"
         [job "encoder-independence" ["build-asm-check"] [],
          tagged ["quick"] (job "encoder-faults" ["build-asm-faults"] []),
          executable "executable-memory" "bin/runevm" ["--jit-check"],
          executable "x64" "build/register/x64_test" [],executable "a64" "build/register/a64_test" [],
          executable "masm" "build/register/masm_test" [],
          job "compile-deeprec" ["build-jit-compile"] [],
          Test.describe "deeprec" (List.map (fn (name,_) => job name ["build-jit-deep",name] ["low-level/jit/compile-deeprec"]) modes)])]
end

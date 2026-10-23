(* Includes explicit source acquisition reads, preprocessing, policy/layout
   analysis, emission, dependency hashing and immutable-set packaging. The
   publication/OS process startup costs are deliberately separate. *)
val options=RuneffiMain.parse["generate","--config","tests/ffi/generator/scalars.ffi",
  "--target","ffi/targets/linux-x86_64.json","--layout","gen_record"]
val iterations=10
val timer=Timer.startCPUTimer()
val started=Runtime.clock()
fun loop 0 checksum=checksum
  | loop count checksum=let val result=RuneffiMain.package(RuneffiMain.inputs options)
      val size=List.foldl(fn({text,...}:ForeignGenerate.artifact,total)=>String.size text+total)0(#files result)
    in if checksum=0 orelse checksum=size then loop(count-1)size else raise Fail "nondeterministic generation size" end
val checksum=loop iterations 0
val elapsed=Time.toReal(Time.-(Runtime.clock(),started))
val {usr,sys}=Timer.checkCPUTimer timer
val cpu=Time.toReal(Time.+(usr,sys))
val ()=print(Json.encode(Json.Object[("implementation",Json.String "rune"),("phase",Json.String "generation"),
  ("iterations",Json.int iterations),("cpuSeconds",Json.Number(Real.toString cpu)),
  ("wallSeconds",Json.Number(Real.toString elapsed)),("checksum",Json.int checksum)]) ^ "\n")

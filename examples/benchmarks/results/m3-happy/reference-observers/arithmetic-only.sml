(* Read both operands at runtime; all mathematical results fit signed 31 bits. *)
fun report name f=(print(name^": "^Int.toString(f())^"\n")
  handle e=>print(name^": "^General.exnName e^"\n"))
fun subtract digit=1073741823-digit
fun combined(base,digit)=(1073741823-digit)div base
fun separate(base,digit)=let val n=1073741823-digit in n div base end
val base=valOf(Int.fromString(TextIO.inputAll TextIO.stdIn))
val digit=valOf(Int.fromString"1")
val _=report"subtract"(fn()=>subtract digit)
val _=report"combined"(fn()=>combined(base,digit))
val _=report"separate"(fn()=>separate(base,digit))
val _=report"constant"(fn()=>(1073741823-1)div 10)
val _=print"SUMMARY 0 checks, 0 failed\n"

structure K=BenchAnnaLiteralProbeFn(BenchNeed)
fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
val literal:Word64.word=0wx40000000
val parsed=valOf(Word64.fromString"0wx40000000")
val _=print("PROBE literal="^Word64.toString literal^" parsed="^Word64.toString parsed^"\n")
val _=print("PROBE private limit="^Word64.toString(BenchNeed.force K.typeSupplyDoubleLimit)^"\n")
val _=(let
 val(_,atomic)=K.parseCore(K.input(read"tests/benchmarks/data/nofib-anna/inputs/anna.faststdin"))
 val(types,expression)=BenchNeed.force atomic
 val builtins=K.map(fn entry=>let val(name,_)=BenchNeed.force entry in name end)K.baseAnnotations
 val(program,_)=BenchLazy.force(K.lambdaLift builtins expression true)
 val(words,result)=K.checkTypes K.baseTypes(K.singleton(K.int 1),K.singleton(K.int 0))(K.pair types program)
 val actual=K.string words
 val expected=read"tests/benchmarks/data/nofib-anna/types-smoke.reference"
 val correct=actual=expected
 val _=print("PROBE type report "^Int.toString(size actual)^" bytes match="^Bool.toString correct^"\n")
 val _=case BenchLazy.force result of K.Ok _=>print"PROBE result Ok\n"|_=>print"PROBE result Failed\n"
 in OS.Process.exit(if correct then OS.Process.success else OS.Process.failure)end
 handle e=>(print("PROBE EXCEPTION "^General.exnName e^": "^General.exnMessage e^"\n");OS.Process.exit OS.Process.failure))

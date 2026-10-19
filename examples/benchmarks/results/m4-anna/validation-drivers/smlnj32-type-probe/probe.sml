structure K=BenchNofibAnnaFn(BenchNeed)
fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
val _=(let
 val _=print"PROBE parse\n"
 val(_,atomic)=K.parseCore(K.input(read"tests/benchmarks/data/nofib-anna/inputs/anna.faststdin"))
 val(types,expression)=BenchNeed.force atomic
 val builtins=K.map(fn entry=>let val(name,_)=BenchNeed.force entry in name end)K.baseAnnotations
 val _=print"PROBE lambda lift\n"
 val(program,_)=BenchLazy.force(K.lambdaLift builtins expression true)
 val _=print"PROBE checkTypes call\n"
 val(words,result)=K.checkTypes K.baseTypes(K.singleton(K.int 1),K.singleton(K.int 0))(K.pair types program)
 val _=print"PROBE force type report\n"
 val text=K.string words
 val _=print("PROBE report bytes "^Int.toString(size text)^"\n")
 val _=case BenchLazy.force result of K.Ok _=>print"PROBE result Ok\n"|_=>print"PROBE result Failed\n"
 in OS.Process.exit OS.Process.success end
 handle e=>(print("PROBE EXCEPTION "^General.exnName e^": "^General.exnMessage e^"\n");OS.Process.exit OS.Process.failure))

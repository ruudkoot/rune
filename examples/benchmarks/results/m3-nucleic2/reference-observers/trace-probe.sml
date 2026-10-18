structure K=BenchNucleic2Fn(structure D=BenchNeed val shared=false)
val _=(print("MAXIMUM "^Real.toString(K.compute"1")^"\n")
 handle e=>print("EXCEPTION "^General.exnName e^" "^General.exnMessage e^"\n"))
val _=print"SUMMARY 0 checks, 0 failed\n"
